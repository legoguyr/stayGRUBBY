import SwiftUI
import SwiftData

// MARK: - Smart Collections field

/// Optional "Add to Collection" for a Dish (Rank a Dish, Add a Recipe, Edit Cook, Dish page). Search
/// existing collections, create one inline, pick several, remove any. Value-only: the owning editor
/// saves. Shown only while the `dish_collections` gate is on.
struct DishCollectionsField: View {
    @Binding var labels: [String]
    @Query private var dishes: [Dish]
    @State private var entry = ""
    @FocusState private var focused: Bool

    private var existing: [String] { DishCollectionSummary.labels(in: dishes) }
    private var selectedKeys: Set<String> { Set(labels.map(DishCollectionPolicy.key)) }
    private var suggestions: [String] {
        let query = DishCollectionPolicy.key(entry)
        return existing.filter { !selectedKeys.contains(DishCollectionPolicy.key($0)) && (query.isEmpty || DishCollectionPolicy.key($0).contains(query)) }.prefix(6).map { $0 }
    }
    private var newLabel: String? {
        guard let label = DishCollectionPolicy.normalized([entry]).first,
              !existing.contains(where: { DishCollectionPolicy.key($0) == DishCollectionPolicy.key(label) }),
              !selectedKeys.contains(DishCollectionPolicy.key(label)) else { return nil }
        return label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            Label("\(DishVariationCopy.plural) · optional", systemImage: DishVariationCopy.symbol).font(SGTheme.TypeRole.secondary.weight(.semibold))
            if !labels.isEmpty {
                ForEach(labels, id: \.self) { label in
                    HStack(spacing: SGTheme.Space.small) {
                        TagChip(title: label, emphasis: true)
                        Spacer(minLength: 0)
                        Button { labels.removeAll { $0 == label } } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                            .buttonStyle(.plain).frame(width: SGTheme.Size.minimumTap, height: SGTheme.Size.minimumTap)
                            .accessibilityLabel("\(DishVariationCopy.removeFrom): \(label)").accessibilityIdentifier("collection-remove-\(label)")
                    }
                }
            }
            if labels.count < DishCollectionPolicy.maximumPerDish {
                TextField("Add to a variation, like Risotto", text: $entry)
                    .focused($focused).submitLabel(.done).onSubmit { if let newLabel { add(newLabel) } }
                    .autocorrectionDisabled().accessibilityIdentifier("collection-entry").sgField()
                if focused || !entry.isEmpty {
                    ForEach(suggestions, id: \.self) { label in
                        Button { add(label) } label: { Label(label, systemImage: "plus.circle").frame(maxWidth: .infinity, minHeight: SGTheme.Size.minimumTap, alignment: .leading).contentShape(Rectangle()) }
                            .buttonStyle(.plain).accessibilityIdentifier("collection-suggestion-\(label)")
                    }
                    if let newLabel {
                        Button { add(newLabel) } label: { Label("Create “\(newLabel)”", systemImage: "plus").frame(maxWidth: .infinity, minHeight: SGTheme.Size.minimumTap, alignment: .leading).contentShape(Rectangle()) }
                            .buttonStyle(.plain).foregroundStyle(SGTheme.ColorToken.accent).accessibilityIdentifier("collection-create")
                    }
                }
            }
            Text(DishVariationCopy.explanation)
                .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
        }
    }
    private func add(_ label: String) { labels = DishCollectionPolicy.normalized(labels + [label]); entry = "" }
}

/// Edits one Dish's collections; saves only when they changed.
struct DishCollectionsEditor: View {
    let dish: Dish
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var labels: [String]
    @State private var error: String?
    init(dish: Dish) { self.dish = dish; _labels = State(initialValue: dish.collections) }
    var body: some View {
        NavigationStack {
            ScrollView { DishCollectionsField(labels: $labels).padding(SGTheme.Space.medium) }
                .background(SGTheme.ColorToken.background)
                .navigationTitle(DishVariationCopy.plural).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            do { try DishCollectionStore.set(labels, on: dish, context: context); dismiss() }
                            catch { self.error = "Couldn’t save. Try again." }
                        }.accessibilityIdentifier("collections-save")
                    }
                }
                .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }
    }
}

/// Dish page: the Dish Variations this Dish is in, as "Explore Risotto" links, plus one quiet edit action.
/// A folder is organization only; the page's own cook history stays below.
struct DishFolderCallout: View {
    let dish: Dish
    var edit: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            ForEach(dish.collections, id: \.self) { label in
                NavigationLink { DishCollectionView(label: label) } label: {
                    HStack(spacing: SGTheme.Space.small) {
                        Image(systemName: DishVariationCopy.symbol).foregroundStyle(SGTheme.ColorToken.accent).accessibilityHidden(true)
                        Text("Explore \(label)").font(SGTheme.TypeRole.headline).foregroundStyle(SGTheme.ColorToken.primaryText)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }.frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("dish-explore-\(label)")
            }
            Button(action: edit) {
                Label(dish.collections.isEmpty ? DishVariationCopy.addTo : DishVariationCopy.editMany, systemImage: dish.collections.isEmpty ? DishVariationCopy.addSymbol : DishVariationCopy.symbol)
                    .font(SGTheme.TypeRole.secondary.weight(.medium)).frame(minHeight: SGTheme.Size.minimumTap, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(SGTheme.ColorToken.accent)
                .accessibilityLabel(dish.collections.isEmpty ? DishVariationCopy.addTo : "\(DishVariationCopy.editMany): \(dish.collections.joined(separator: ", "))")
                .accessibilityIdentifier("dish-collections")
        }
    }
}

// MARK: - Separate cooks into their own Dishes

/// The explicit repair for cooks logged under one Dish that are really different Dishes (owner's risottos,
/// November 18, 2026). Lists every cook of the Dish; the owner turns on the ones that are separate Dishes and
/// names them. Nothing is inferred: no cook moves, no Recipe moves and no folder is set unless chosen here.
/// Each moved cook keeps its rank, score, photos, notes and Recipe-used record (`DishIdentityStore.move`).
/// The Dish's Recipe, description and earlier posts stay with this Dish.
struct SeparateCooksSheet: View {
    struct Row: Identifiable { let cook: CookingAttempt; var separate = false; var name: String; var id: UUID { cook.id } }
    let dish: Dish
    /// The cook made from this Dish's Recipe, if known (shown so the Recipe visibly stays with it).
    var recipeCookID: UUID? = nil
    var recipeTitle: String? = nil
    var onSaved: (_ movedCookIDs: Set<UUID>) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.featureFlags) private var flags
    @State private var dishName: String
    @State private var rows: [Row]
    @State private var groups = false
    @State private var folder: String
    @State private var error: String?

    init(dish: Dish, recipeCookID: UUID? = nil, recipeTitle: String? = nil, onSaved: @escaping (Set<UUID>) -> Void = { _ in }) {
        self.dish = dish; self.recipeCookID = recipeCookID; self.recipeTitle = recipeTitle; self.onSaved = onSaved
        _dishName = State(initialValue: dish.name)
        let ordered = dish.attempts.sorted { ($0.sequenceNumber, $0.createdAt) < ($1.sequenceNumber, $1.createdAt) }
        _rows = State(initialValue: ordered.map { Row(cook: $0, name: Self.suggestedName(for: $0, dishName: dish.name)) })
        _folder = State(initialValue: Self.lastWord(dish.name))
    }
    /// "Mushroom" in "Mahi Mahi Risotto" → "Mushroom Risotto". Only a starting point; always editable.
    static func suggestedName(for cook: CookingAttempt, dishName: String) -> String {
        guard let title = CookName.normalized(cook.versionTitle) else { return "" }
        let last = lastWord(dishName)
        return last.isEmpty || title.localizedCaseInsensitiveContains(last) ? title : "\(title) \(last)"
    }
    static func lastWord(_ name: String) -> String { name.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? "" }

    private var separating: [Row] { rows.filter(\.separate) }
    private var valid: Bool {
        !dishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && separating.count < rows.count
            && separating.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SGTheme.Space.large) {
                    Text("These cooks are all saved as **\(dish.name)**. Turn on any cook that is really a different Dish. Its rank, score, photos and notes move with it.")
                        .fixedSize(horizontal: false, vertical: true)
                    SGFormSection(title: "This Dish keeps") {
                        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                            TextField("Dish name", text: $dishName).font(SGTheme.TypeRole.title).accessibilityIdentifier("separate-dish-name").sgField()
                            if let recipeTitle {
                                Label("Recipe: \(recipeTitle)", systemImage: "book.closed").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                            }
                        }
                    }
                    SGFormSection(title: "Cooks") {
                        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
                            ForEach($rows) { $row in cookRow($row) }
                        }
                    }
                    if flags.isOn(.dishCollections) {
                        SGFormSection(title: "\(DishVariationCopy.singular) · optional") {
                            VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                                Toggle("Put these Dishes in one variation", isOn: $groups).accessibilityIdentifier("separate-folder-toggle")
                                if groups { TextField("Variation name", text: $folder).accessibilityIdentifier("separate-folder-name").sgField() }
                            }
                        }
                    }
                }.padding(SGTheme.Space.medium).frame(maxWidth: SGTheme.Size.contentMaximum).frame(maxWidth: .infinity)
            }
            .background(SGTheme.ColorToken.background)
            .navigationTitle("Separate Cooks").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!valid).accessibilityIdentifier("separate-save") }
            }
            .alert("Couldn't separate", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }
    }

    @ViewBuilder private func cookRow(_ row: Binding<Row>) -> some View {
        let cook = row.wrappedValue.cook
        let lastStaying = !row.wrappedValue.separate && rows.filter { !$0.separate }.count == 1
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            HStack(spacing: SGTheme.Space.small) {
                DishPhoto(media: cook.primaryImage, thumbnail: true, name: cook.displayName).sgPhotoFrame(.compactThumbnail)
                VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                    Text(cook.versionTitle.flatMap(CookName.normalized) ?? CookName.fallback(sequence: cook.sequenceNumber)).font(SGTheme.TypeRole.headline)
                    Text([cook.cookedAt?.formatted(date: .abbreviated, time: .omitted), cook.id == recipeCookID ? "Made from the Recipe" : nil].compactMap { $0 }.joined(separator: " · "))
                        .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Toggle("Separate Dish", isOn: row.separate).labelsHidden().disabled(lastStaying)
                    .accessibilityLabel("Make \(cook.displayName) a separate Dish").accessibilityIdentifier("separate-toggle-\(cook.versionTitle ?? String(cook.sequenceNumber))")
            }
            if row.wrappedValue.separate {
                TextField("New Dish name", text: row.name).accessibilityIdentifier("separate-name-\(cook.versionTitle ?? String(cook.sequenceNumber))").sgField()
                if cook.id == recipeCookID, let recipeTitle {
                    Text("“\(recipeTitle)” stays with \(dishName). Link it to the new Dish later if it belongs there.")
                        .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func save() {
        let label = groups ? DishCollectionPolicy.normalized([folder]) : []
        var moved = Set<UUID>()
        do {
            try DishIdentityStore.rename(dish, to: dishName, context: context)
            for row in separating {
                try DishIdentityStore.move(row.cook, toNewDishNamed: row.name, collections: label, context: context)
                moved.insert(row.cook.id)
            }
            if !label.isEmpty { try DishCollectionStore.set(dish.collections + label, on: dish, context: context) }
            onSaved(moved); dismiss()
        } catch {
            // Each move is its own synced edit: anything already moved stays moved and is reported.
            self.error = moved.isEmpty ? "Nothing changed. Try again." : "Some cooks were separated; the rest are unchanged. Try again for those."
            if !moved.isEmpty { onSaved(moved) }
        }
    }
}

// MARK: - Dish Variations (Grub Rank tab and My Kitchen)

/// Dish Variation cards in a two-column grid: food photo, name, "3 Dishes · 7 cooks", led by Create Variation.
/// Opens `DishCollectionView`.
struct FolderGrid: View {
    let summaries: [DishCollectionSummary]
    @State private var creating = false
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            if summaries.isEmpty {
                SGContentState(title: "No Dish Variations yet", symbol: DishVariationCopy.symbol,
                               message: "Group related Dishes, like all your risottos. Each Dish keeps its own cooks, Recipe and ranking.") {
                    Button(DishVariationCopy.create, systemImage: "plus") { creating = true }
                        .buttonStyle(SGButtonStyle(prominent: true)).accessibilityIdentifier("variation-create")
                }
                .accessibilityElement(children: .contain).accessibilityIdentifier("folders-empty")
            } else {
                Button { creating = true } label: {
                    Label(DishVariationCopy.create, systemImage: "plus").font(SGTheme.TypeRole.headline)
                        .frame(maxWidth: .infinity, minHeight: SGTheme.Size.minimumTap)
                }
                .buttonStyle(SGButtonStyle(prominent: false)).accessibilityIdentifier("variation-create")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: SGTheme.Space.small, alignment: .top), GridItem(.flexible(), spacing: SGTheme.Space.small, alignment: .top)],
                          alignment: .leading, spacing: SGTheme.Space.medium) {
                    ForEach(summaries) { summary in
                        NavigationLink { DishCollectionView(label: summary.label) } label: { FolderCard(summary: summary) }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(summary.label), \(summary.dishCountText), \(summary.cookCountText)")
                            .accessibilityHint("Opens the variation").accessibilityIdentifier("folder-\(summary.label)")
                    }
                }
            }
        }
        .sheet(isPresented: $creating) { VariationEditorSheet(label: nil) }
    }
}

/// Create Variation / Edit Variation: a name and the Dishes in it, chosen from every Dish (search for many).
/// Saves one synced edit through `DishCollectionStore.setMembers`; Dishes only gain or lose the label.
struct VariationEditorSheet: View {
    /// The variation being edited; nil creates one.
    let label: String?
    var onSaved: (String) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Dish.name) private var dishes: [Dish]
    @State private var name: String
    @State private var selected: Set<UUID>?
    @State private var search = ""
    @State private var error: String?

    init(label: String?, preselected: Set<UUID> = [], onSaved: @escaping (String) -> Void = { _ in }) {
        self.label = label; self.onSaved = onSaved
        _name = State(initialValue: label ?? "")
        _selected = State(initialValue: label == nil ? preselected : nil)
    }
    private var members: Set<UUID> {
        selected ?? Set(dishes.filter { dish in dish.collections.contains { DishCollectionPolicy.key($0) == DishCollectionPolicy.key(label ?? "") } }.map(\.id))
    }
    private var cleanName: String? { DishCollectionPolicy.normalized([name]).first }
    /// Another variation already uses this name: saving would merge them, so ask for a different name.
    private var nameTaken: Bool {
        guard let cleanName else { return false }
        let key = DishCollectionPolicy.key(cleanName)
        return key != label.map(DishCollectionPolicy.key) && DishCollectionSummary.labels(in: dishes).contains { DishCollectionPolicy.key($0) == key }
    }
    private var shown: [Dish] {
        let query = TagNormalization.key(search)
        return dishes.filter { query.isEmpty || TagNormalization.key($0.name).contains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Variation name, like Risotto", text: $name)
                        .autocorrectionDisabled().accessibilityIdentifier("variation-name")
                    if nameTaken { Text("“\(cleanName ?? "")” already exists. Choose another name.").font(SGTheme.TypeRole.secondary).foregroundStyle(SGTheme.ColorToken.accent) }
                } footer: { Text(DishVariationCopy.explanation) }
                Section {
                    if dishes.count > 8 { TextField("Search Dishes", text: $search).accessibilityIdentifier("variation-search") }
                    ForEach(shown) { dish in
                        let on = members.contains(dish.id)
                        Button { toggle(dish.id) } label: {
                            HStack(spacing: SGTheme.Space.small) {
                                DishPhoto(media: dish.attempts.compactMap(\.primaryImage).first, thumbnail: true, name: dish.name).sgPhotoFrame(.compactThumbnail)
                                VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                                    Text(dish.name).font(SGTheme.TypeRole.headline).foregroundStyle(SGTheme.ColorToken.primaryText)
                                    Text(dish.attempts.count == 1 ? "1 cook" : "\(dish.attempts.count) cooks").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.title3)
                                    .foregroundStyle(on ? SGTheme.ColorToken.accent : .secondary)
                            }.frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(dish.name).accessibilityAddTraits(on ? .isSelected : [])
                        .accessibilityIdentifier("variation-dish-\(dish.name)")
                    }
                } header: { Text(members.count == 1 ? "1 Dish selected" : "\(members.count) Dishes selected") }
            }
            .scrollContentBackground(.hidden).background(SGTheme.ColorToken.background)
            .navigationTitle(label == nil ? DishVariationCopy.create : DishVariationCopy.edit).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(cleanName == nil || nameTaken || members.isEmpty).accessibilityIdentifier("variation-save")
                }
            }
            .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }
    }
    private func toggle(_ id: UUID) {
        var next = members
        if next.contains(id) { next.remove(id) } else { next.insert(id) }
        selected = next
    }
    private func save() {
        guard let cleanName else { return }
        do {
            try DishCollectionStore.setMembers(of: label, name: cleanName, members: members, dishes: dishes, context: context)
            onSaved(cleanName); dismiss()
        } catch { self.error = "Nothing changed. Try again." }
    }
}

struct FolderCard: View {
    let summary: DishCollectionSummary
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            DishPhoto(media: summary.members.lazy.compactMap { $0.best?.attempt.primaryImage ?? $0.dish.attempts.compactMap(\.primaryImage).first }.first,
                      thumbnail: true, name: summary.label)
                .frame(maxWidth: .infinity).aspectRatio(4/3, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.card))
            Label(summary.label, systemImage: DishVariationCopy.symbol).font(SGTheme.TypeRole.headline).foregroundStyle(SGTheme.ColorToken.primaryText).lineLimit(2)
            Text("\(summary.dishCountText) · \(summary.cookCountText)").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
        }
    }
}

// MARK: - My Kitchen folders

/// My Kitchen: collections as compact cards (photo, name, "3 Dishes · 7 cooks"). A view over Dishes only.
struct KitchenCollectionsSection: View {
    let summaries: [DishCollectionSummary]
    let scores: ScoreUnlockState
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            SGSectionHeader(title: DishVariationCopy.plural)
            if summaries.isEmpty {
                Text("Group related Dishes, like all your risottos, from Grub Rank or any Dish’s page.")
                    .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary).accessibilityIdentifier("collections-empty")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: SGTheme.Space.small) {
                        ForEach(summaries) { summary in
                            NavigationLink { DishCollectionView(label: summary.label) } label: { card(summary) }
                                .buttonStyle(.plain)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(summary.label), \(summary.dishCountText), \(summary.cookCountText)")
                                .accessibilityHint("Opens the variation").accessibilityIdentifier("kitchen-collection-\(summary.label)")
                        }
                    }
                }
            }
        }
    }
    private func card(_ summary: DishCollectionSummary) -> some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            DishPhoto(media: summary.members.lazy.compactMap { $0.best?.attempt.primaryImage ?? $0.dish.attempts.compactMap(\.primaryImage).first }.first,
                      thumbnail: true, name: summary.label)
                .frame(width: 150, height: 112).clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.field))
            Text(summary.label).font(SGTheme.TypeRole.headline).foregroundStyle(SGTheme.ColorToken.primaryText).lineLimit(1)
            Text("\(summary.dishCountText) · \(summary.cookCountText)").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
        }.frame(width: 150, alignment: .leading)
    }
}

/// One collection: its Dishes compared by their best Grub Rank cook. A filtered presentation of
/// existing ranking results — no new comparisons, no new scores.
struct DishCollectionView: View {
    let label: String
    @Environment(\.modelContext) private var context
    @Query private var dishes: [Dish]
    @State private var editing = false
    @State private var removing = false
    @State private var search = ""
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    private var scores: ScoreUnlockState { ScoreUnlockPolicy.state(in: context) }
    private var summary: DishCollectionSummary? {
        DishCollectionSummary.all(dishes: dishes, entries: ScoreUnlockPolicy.entries(in: context), scores: scores)
            .first { $0.id == DishCollectionPolicy.key(label) }
    }
    private var members: [DishCollectionSummary.Member] {
        let query = TagNormalization.key(search)
        return (summary?.members ?? []).filter { query.isEmpty || TagNormalization.key($0.dish.name).contains(query) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SGTheme.Space.small) {
                if let summary {
                    Text("\(summary.dishCountText) · \(summary.cookCountText)").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                        .accessibilityIdentifier("collection-counts")
                    Text(scores.isUnlocked ? "Ranked by each Dish’s best cook in your Grub Rank." : "Ranked by each Dish’s best cook in your Grub Rank. Scores unlock as you rank more cooks.")
                        .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if summary.members.count > 8 { SGSearchField(placeholder: "Search this variation", text: $search, identifier: "collection-search") }
                    ForEach(Array(members.enumerated()), id: \.element.id) { index, member in row(member, position: index + 1) }
                } else {
                    SGContentState(title: "No Dishes yet", symbol: DishVariationCopy.symbol, message: "Add Dishes to “\(label)” with \(DishVariationCopy.edit).")
                }
            }
            .padding(SGTheme.Space.medium).frame(maxWidth: SGTheme.Size.contentMaximum).frame(maxWidth: .infinity)
        }
        .background(SGTheme.ColorToken.background)
        .navigationTitle(label).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(DishVariationCopy.edit, systemImage: "pencil") { editing = true }.accessibilityIdentifier("collection-edit")
                    Button(DishVariationCopy.delete, systemImage: "trash", role: .destructive) { removing = true }.accessibilityIdentifier("collection-delete")
                } label: { SGToolbarIcon(symbol: "ellipsis") }.sgUtilityTint().accessibilityLabel("Variation actions").accessibilityIdentifier("collection-actions")
            }
        }
        // Renaming here changes the label on its Dishes; this page then closes back to the list.
        .sheet(isPresented: $editing) {
            VariationEditorSheet(label: label) { saved in if DishCollectionPolicy.key(saved) != DishCollectionPolicy.key(label) { dismiss() } }
        }
        .alert("Delete “\(label)”?", isPresented: $removing) {
            Button(DishVariationCopy.delete, role: .destructive) { apply { try DishCollectionStore.remove(label, dishes: dishes, context: context); dismiss() } }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Only the variation goes. Every Dish, cook and Recipe in it stays.") }
        .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    @ViewBuilder private func row(_ member: DishCollectionSummary.Member, position: Int) -> some View {
        let content = HStack(spacing: SGTheme.Space.small) {
            Text(member.best == nil ? "–" : "\(position)").font(SGTheme.TypeRole.headline).monospacedDigit()
                .foregroundStyle(.secondary).frame(minWidth: 24)
            DishPhoto(media: member.best?.attempt.primaryImage ?? member.dish.attempts.compactMap(\.primaryImage).first, thumbnail: true, name: member.dish.name)
                .sgPhotoFrame(.compactThumbnail)
            VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                Text(member.dish.name).font(SGTheme.TypeRole.headline).foregroundStyle(SGTheme.ColorToken.primaryText).fixedSize(horizontal: false, vertical: true)
                Text(detail(member)).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let best = member.best {
                Text("#\(best.globalRank)").font(SGTheme.TypeRole.secondary).monospacedDigit().foregroundStyle(.secondary)
                SGScore(text: member.scoreText, role: .pill, identifier: "collection-score-\(member.dish.name)")
            }
            Image(systemName: "chevron.right").foregroundStyle(.secondary).accessibilityHidden(true)
        }.frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
        Group {
            if let best = member.best { NavigationLink(value: best.attempt.id) { content } }
            else { NavigationLink { DishView(dish: member.dish) } label: { content } }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility(member, position: position))
        .accessibilityHint("Opens the Dish").accessibilityIdentifier("collection-dish-\(member.dish.name)")
        .accessibilityAction(named: DishVariationCopy.removeFrom) { removeFromVariation(member.dish) }
        .contextMenu {
            Button(DishVariationCopy.removeFrom, systemImage: "minus.circle") { removeFromVariation(member.dish) }
                .accessibilityIdentifier("collection-dish-remove")
        }
    }
    /// Which cook produced the score, and how many cooks the Dish has.
    private func detail(_ member: DishCollectionSummary.Member) -> String {
        let cooks = member.cookCount == 1 ? "1 cook" : "\(member.cookCount) cooks"
        guard let best = member.best else { return member.cookCount == 0 ? "Not cooked yet" : cooks }
        let from = member.cookCount > 1 ? "Best: \(best.attempt.meaningfulVersionLabel ?? best.attempt.displayName)" : nil
        return [from, cooks].compactMap { $0 }.joined(separator: " · ")
    }
    private func accessibility(_ member: DishCollectionSummary.Member, position: Int) -> String {
        guard let best = member.best else { return "\(member.dish.name), \(detail(member))" }
        return "\(position), \(member.dish.name), Grub Rank \(best.globalRank), \(member.scoreText.map { "score \($0)" } ?? "score locked"), \(detail(member))"
    }
    /// Only this Dish loses the label; the Dish and everything in it stays.
    private func removeFromVariation(_ dish: Dish) {
        let key = DishCollectionPolicy.key(label)
        apply { try DishCollectionStore.set(dish.collections.filter { DishCollectionPolicy.key($0) != key }, on: dish, context: context) }
    }
    private func apply(_ work: () throws -> Void) { do { try work() } catch { self.error = "Nothing changed. Try again." } }
}
