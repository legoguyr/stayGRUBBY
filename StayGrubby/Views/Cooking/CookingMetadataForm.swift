import SwiftUI

/// Value-only state: dismissing the enclosing editor never writes to saved objects.
struct CookingMetadataForm: View {
    @Binding var draft: CookingDraft
    var existingDish = false
    var editing = false
    var sharingSelection: Binding<CookingSharingSelection>? = nil
    var cookedWith: Binding<Set<UUID>>? = nil
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var newTag = ""
    @State private var selection: CookingMetadataSelection?
    @State private var sourceEditor = false
    @State private var cuisinePicker = false
    @FocusState private var focusedField: EntryField?
    private enum EntryField: Hashable { case name, description, dishNotes, version, cookNotes, tag }

    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            CookingPhotoEditor(draft: $draft)
            VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
                if existingDish && !editing {
                    Text(draft.dishName).font(SGTheme.TypeRole.title)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("inherited-dish-name")
                } else {
                    TextField("Dish name", text: $draft.dishName).font(SGTheme.TypeRole.title)
                        .focused($focusedField, equals: .name).submitLabel(.done).onSubmit { focusedField = nil }
                        .accessibilityIdentifier("dish-name").sgField()
                }
                VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                    Text("Public Description").font(SGTheme.TypeRole.secondary.weight(.semibold))
                    TextField("A few words for your Sous Chefs", text: $draft.publicDescription, axis: .vertical)
                        .focused($focusedField, equals: .description).lineLimit(2...5).accessibilityIdentifier("cook-dish-description").sgField()
                }
                VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                    Label("Private Notes", systemImage: "lock").font(SGTheme.TypeRole.secondary.weight(.semibold))
                    TextField("For your kitchen only", text: $draft.privateNotes, axis: .vertical)
                        .focused($focusedField, equals: .dishNotes).lineLimit(2...5).accessibilityIdentifier("cook-dish-private-notes").sgField()
                }
                if existingDish || editing {
                    Text(editing ? "Name, description, Dish notes, Cuisine and Source apply to all versions." : "Description and Dish notes apply to all versions.").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                }
                if !draft.validDishText {
                    Text("Keep the description within 2,000 characters and private notes within 8,000.")
                        .font(.footnote).foregroundStyle(SGTheme.ColorToken.destructive)
                }
            }
            SGFormSection(title: "Details") {
                if textSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                        Text(CookingProductOptions.courseTitle); coursePicker
                    }.sgField()
                } else { HStack { Text(CookingProductOptions.courseTitle); Spacer(); coursePicker }.sgField() }
                if existingDish && !editing {
                    Label(draft.cuisine?.label ?? "No cuisine", systemImage: "globe")
                        .accessibilityIdentifier("inherited-dish-cuisine")
                    Label(draft.source?.summary ?? "No source", systemImage: "text.book.closed")
                } else {
                    selector("Cuisine", value: draft.cuisine?.label ?? "Optional", symbol: "globe") { cuisinePicker = true }
                        .accessibilityIdentifier("dish-cuisine")
                    selector("Source", value: draft.source?.summary ?? "Optional", symbol: "text.book.closed") { sourceEditor = true }
                        .accessibilityIdentifier("dish-source-type")
                }
            }
            if let cookedWith { CookedWithSelection(selected: cookedWith) }
            if let sharingSelection { CookingSharingChoice(selection: sharingSelection) }
            SGFormSection(title: "This cook / version") {
                TextField("Version title (optional)", text: $draft.versionTitle).accessibilityIdentifier("version-title")
                    .focused($focusedField, equals: .version).submitLabel(.done).onSubmit { focusedField = nil }.sgField()
                if editing {
                    Toggle("Cooked date known", isOn: Binding(get: { draft.cookedAt != nil }, set: { draft.cookedAt = $0 ? .now : nil }))
                }
                if draft.cookedAt != nil {
                    if textSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                            Text("Date cooked").font(SGTheme.TypeRole.body)
                            cookedDate.labelsHidden().accessibilityLabel("Date cooked")
                        }
                    } else { cookedDate }
                }
                selector("Dietary", value: draft.dietary.isEmpty ? "Optional" : "\(draft.dietary.count) selected", symbol: "leaf") { selection = .dietary }
                DisclosureGroup("Cook-specific ingredients") {
                    Text("Cook-specific changes; Recipe allergens stay separate.").font(.footnote).foregroundStyle(.secondary)
                    selector("Contains", value: draft.contains.isEmpty ? "Optional" : "\(draft.contains.count) selected", symbol: "checklist") { selection = .contains }
                        .accessibilityIdentifier("cook-contains")
                }
                if !draft.allergy.isEmpty {
                    VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                        Text("Legacy free-of labels: " + draft.allergy.map(\.label).sorted().joined(separator: ", "))
                            .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                        Text("Kept separately from Contains. These are user-entered claims.")
                            .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                        Button("Remove legacy free-of labels") { draft.allergy = [] }
                            .accessibilityIdentifier("clear-legacy-free-labels")
                    }
                }
            }
            SGFormSection(title: "More about this cook") {
                DisclosureGroup("Custom tags") {
                    ForEach(draft.customTags, id: \.self) { tag in
                        HStack {
                            Text(tag).font(SGTheme.TypeRole.body)
                            Spacer()
                            SGIconButton(title: "Remove tag \(tag)", symbol: "minus.circle") { draft.customTags.removeAll { $0 == tag } }
                        }
                    }
                    HStack {
                        TextField("Custom tag", text: $newTag).focused($focusedField, equals: .tag).onSubmit(addTag).submitLabel(.done).sgField()
                        Button("Add tag", action: addTag).disabled(TagNormalization.display(newTag).isEmpty)
                            .buttonStyle(SGButtonStyle())
                    }
                }.font(SGTheme.TypeRole.body)
                TextField("Personal Notes · private (optional)", text: $draft.notes, axis: .vertical)
                    .focused($focusedField, equals: .cookNotes).lineLimit(2...6).accessibilityIdentifier("cook-notes").sgField()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField != nil {
                    Spacer()
                    Button("Done") { focusedField = nil }.accessibilityIdentifier("cook-keyboard-done")
                }
            }
        }
        .sheet(isPresented: $cuisinePicker) { CuisinePicker(selection: $draft.cuisine) }
        .sheet(isPresented: $sourceEditor) { DishSourceEditor(source: $draft.source) }
        .sheet(item: $selection) { selection in
            switch selection {
            case .dietary:
                CookingFilterView(filters: Binding(
                    get: { CookingFilters(dietary: draft.dietary) },
                    set: { draft.dietary = $0.dietary }), group: .dietary)
            case .contains:
                ContainsSelector(selection: $draft.contains)
            }
        }
    }
    private var coursePicker: some View {
        Picker(CookingProductOptions.courseTitle, selection: $draft.category) {
            ForEach(CookingProductOptions.courses) { Text($0.label).tag($0) }
        }.pickerStyle(.menu).labelsHidden().tint(SGTheme.ColorToken.primaryText)
    }
    private var cookedDate: some View {
        DatePicker("Date cooked", selection: Binding(get: { draft.cookedAt ?? .now }, set: { draft.cookedAt = $0 }), displayedComponents: .date)
            .font(SGTheme.TypeRole.body).frame(minHeight: SGTheme.Size.minimumTap)
    }
    private func selector(_ title: String, value: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if textSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                        Label(title, systemImage: symbol)
                        HStack { Text(value).foregroundStyle(.secondary); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary) }
                    }
                } else {
                    HStack(spacing: SGTheme.Space.small) {
                        Image(systemName: symbol).foregroundStyle(.secondary)
                        Text(title)
                        Spacer()
                        Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                }
            }.font(SGTheme.TypeRole.body).frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
    private func addTag() { draft.customTags = TagNormalization.deduplicated(draft.customTags + [newTag]); newTag = "" }
}

struct SGFormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            SGEyebrow(text: title)
            content
        }.font(SGTheme.TypeRole.body).padding(.vertical, SGTheme.Space.medium)
            .overlay(alignment: .top) { Divider().accessibilityHidden(true) }
    }
}

struct CookingFormScroll: View {
    @Binding var draft: CookingDraft
    var existingDish = false
    var editing = false
    var sharingSelection: Binding<CookingSharingSelection>? = nil
    var cookedWith: Binding<Set<UUID>>? = nil
    var body: some View {
        ScrollView {
            CookingMetadataForm(draft: $draft, existingDish: existingDish, editing: editing, sharingSelection: sharingSelection, cookedWith: cookedWith)
                .frame(maxWidth: SGTheme.Size.contentMaximum)
                .padding(SGTheme.Space.medium).frame(maxWidth: .infinity)
        }.accessibilityIdentifier("cooking-form").scrollDismissesKeyboard(.interactively).background(SGTheme.ColorToken.background)
    }
}

private enum CookingMetadataSelection: String, Identifiable {
    case dietary, contains
    var id: String { rawValue }
}
