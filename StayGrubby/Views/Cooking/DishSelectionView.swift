import SwiftUI

struct DishSelectionView: View {
    let dishes: [Dish]
    let onSelect: (Dish) -> Void
    let onCancel: () -> Void
    var selectedCookID: UUID? = nil
    var disabled = false
    var onSelectCook: ((CookingAttempt) -> Void)? = nil
    @State private var search = ""

    var body: some View {
        NavigationStack {
            Group {
                if let onSelectCook {
                    CookVersionSelectionView(dishes: dishes, query: search, selectedID: selectedCookID, disabled: disabled, onSelect: onSelectCook)
                } else {
                    DishPickerList(dishes: dishes, query: search, selection: .single { dish in onSelect(dish) }, disabled: disabled)
                }
            }
            .safeAreaInset(edge: .top) {
                SGSearchField(placeholder: "Search dishes", text: $search, identifier: "parent-dish-search")
                    .padding(SGTheme.Space.medium).background(SGTheme.ColorToken.background)
            }
            .scrollDismissesKeyboard(.interactively).background(SGTheme.ColorToken.background)
            .navigationTitle(onSelectCook == nil ? "Choose a Dish" : "Link a Dish").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel).disabled(disabled) } }
        }
    }
}

/// The one Dish picker list (November 20, 2026; UI_ARCHITECTURE §13): the same rows, photos, search
/// results, empty state and spacing wherever a Dish is chosen. Single selection opens or links a Dish
/// (chevron); multiple selection toggles Dishes for a Dish Variation (check circles). Hosts own the
/// sheet, title, search field and Cancel/Save, so every picker also dismisses the same way.
struct DishPickerList<Header: View>: View {
    enum Selection {
        case single((Dish) -> Void)
        case multiple(Binding<Set<UUID>>)
    }
    let dishes: [Dish]
    var query: String = ""
    let selection: Selection
    var disabled = false
    @ViewBuilder var header: () -> Header
    private var matches: [Dish] { DishSelectionSearch.matches(dishes, query: query) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SGTheme.Space.small) {
                header()
                if matches.isEmpty {
                    ContentUnavailableView {
                        Label(dishes.isEmpty ? "No Dishes yet" : "No matching Dishes", systemImage: dishes.isEmpty ? "fork.knife" : "magnifyingglass")
                            .accessibilityIdentifier("parent-dish-empty")
                    } description: {
                        Text(dishes.isEmpty ? "Rank a Dish to choose it here." : "No Dishes match ‘\(TagNormalization.display(query))’.")
                    }
                }
                ForEach(matches) { dish in row(dish) }
            }.padding(SGTheme.Space.medium)
        }
    }

    @ViewBuilder private func row(_ dish: Dish) -> some View {
        switch selection {
        case .single(let choose):
            Button { choose(dish) } label: { DishPickerRow(dish: dish, accessory: .disclosure) }
                .buttonStyle(.plain).disabled(disabled).accessibilityIdentifier("choose-dish-\(dish.name)")
        case .multiple(let selected):
            let on = selected.wrappedValue.contains(dish.id)
            Button { if on { selected.wrappedValue.remove(dish.id) } else { selected.wrappedValue.insert(dish.id) } } label: {
                DishPickerRow(dish: dish, accessory: .check(on))
            }
            .buttonStyle(.plain).disabled(disabled)
            .accessibilityAddTraits(on ? .isSelected : []).accessibilityIdentifier("variation-dish-\(dish.name)")
        }
    }
}
extension DishPickerList where Header == EmptyView {
    init(dishes: [Dish], query: String = "", selection: Selection, disabled: Bool = false) {
        self.init(dishes: dishes, query: query, selection: selection, disabled: disabled) { EmptyView() }
    }
}

/// One Dish in a picker: its latest photo, name and cook count, then a chevron or a check circle.
struct DishPickerRow: View {
    enum Accessory { case disclosure, check(Bool) }
    let dish: Dish
    let accessory: Accessory
    var body: some View {
        HStack(spacing: SGTheme.Space.small) {
            DishPhoto(media: dish.attempts.sorted { $0.sequenceNumber > $1.sequenceNumber }.compactMap(\.primaryImage).first,
                      thumbnail: true, name: dish.name)
                .sgPhotoFrame(.compactThumbnail)
            VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                Text(dish.name).font(SGTheme.TypeRole.headline).foregroundStyle(SGTheme.ColorToken.primaryText).fixedSize(horizontal: false, vertical: true)
                Text(dish.attempts.isEmpty ? "Not cooked yet" : dish.attempts.count == 1 ? "1 cook" : "\(dish.attempts.count) cooks")
                    .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            switch accessory {
            case .disclosure: Image(systemName: "chevron.right").foregroundStyle(.secondary).accessibilityHidden(true)
            case .check(let on):
                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.title3)
                    .foregroundStyle(on ? SGTheme.ColorToken.accent : .secondary).accessibilityHidden(true)
            }
        }
        .frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
