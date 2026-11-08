import SwiftUI

struct DishSelectionView: View {
    let dishes: [Dish]
    let onSelect: (Dish) -> Void
    let onCancel: () -> Void
    var selectedCookID: UUID? = nil
    var disabled = false
    var onSelectCook: ((CookingAttempt) -> Void)? = nil
    @State private var search = ""
    private var matches: [Dish] { DishSelectionSearch.matches(dishes, query: search) }

    var body: some View {
        NavigationStack {
            Group {
                if let onSelectCook {
                    CookVersionSelectionView(dishes: dishes, query: search, selectedID: selectedCookID, disabled: disabled, onSelect: onSelectCook)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: SGTheme.Space.small) {
                            if matches.isEmpty {
                                ContentUnavailableView {
                                    Label("No matching dishes", systemImage: "magnifyingglass")
                                        .accessibilityIdentifier("parent-dish-empty")
                                } description: {
                                    Text("No dishes match ‘\(TagNormalization.display(search))’.")
                                }
                            }
                            ForEach(matches) { dish in
                                Button { onSelect(dish) } label: {
                                    HStack(spacing: SGTheme.Space.small) {
                                        DishPhoto(media: dish.attempts.sorted { $0.sequenceNumber > $1.sequenceNumber }.compactMap(\.primaryImage).first,
                                                  thumbnail: true, name: dish.name)
                                            .sgPhotoFrame(.compactThumbnail)
                                        VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                                            Text(dish.name).font(SGTheme.TypeRole.headline).fixedSize(horizontal: false, vertical: true)
                                            Text(dish.attempts.count == 1 ? "1 cook" : "\(dish.attempts.count) cooks").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                    }.frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
                                }.buttonStyle(.plain).disabled(disabled).accessibilityIdentifier("choose-dish-\(dish.name)")
                            }
                        }.padding(SGTheme.Space.medium)
                    }
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
