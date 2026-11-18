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
            Label("Collections · optional", systemImage: "square.stack").font(SGTheme.TypeRole.secondary.weight(.semibold))
            if !labels.isEmpty {
                ForEach(labels, id: \.self) { label in
                    HStack(spacing: SGTheme.Space.small) {
                        TagChip(title: label, emphasis: true)
                        Spacer(minLength: 0)
                        Button { labels.removeAll { $0 == label } } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                            .buttonStyle(.plain).frame(width: SGTheme.Size.minimumTap, height: SGTheme.Size.minimumTap)
                            .accessibilityLabel("Remove from \(label)").accessibilityIdentifier("collection-remove-\(label)")
                    }
                }
            }
            if labels.count < DishCollectionPolicy.maximumPerDish {
                TextField("Add to a collection, like Risotto", text: $entry)
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
            Text("Collections group related Dishes. Each Dish keeps its own cooks, Recipe and ranking.")
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
                .navigationTitle("Collections").navigationBarTitleDisplayMode(.inline)
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

/// The Dish's collections as quiet chips on its page; tapping opens the editor.
struct DishCollectionChips: View {
    let dish: Dish
    var edit: () -> Void
    var body: some View {
        Button(action: edit) {
            HStack(spacing: SGTheme.Space.xSmall) {
                Image(systemName: "square.stack").foregroundStyle(.secondary).accessibilityHidden(true)
                if dish.collections.isEmpty { Text("Add to Collection").foregroundStyle(SGTheme.ColorToken.accent) }
                else { Text(dish.collections.joined(separator: " · ")).foregroundStyle(SGTheme.ColorToken.primaryText).lineLimit(2) }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }.font(SGTheme.TypeRole.secondary.weight(.medium)).frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel(dish.collections.isEmpty ? "Add to Collection" : "Collections: \(dish.collections.joined(separator: ", "))")
            .accessibilityHint("Edits this Dish’s collections").accessibilityIdentifier("dish-collections")
    }
}

// MARK: - Move a cook to its own Dish

/// Explicit repair for a cook logged under the wrong Dish ("Mushroom" saved as a cook of "Risotto").
/// Creates a new Dish or joins an existing one; nothing is merged or copied automatically.
struct MoveCookSheet: View {
    let cook: CookingAttempt
    var onMoved: (Dish) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.featureFlags) private var flags
    @Query(sort: \Dish.name) private var dishes: [Dish]
    @State private var name: String
    @State private var labels: [String]
    @State private var choosing = false
    @State private var error: String?

    init(cook: CookingAttempt, onMoved: @escaping (Dish) -> Void = { _ in }) {
        self.cook = cook; self.onMoved = onMoved
        let dishName = cook.dish?.name ?? ""
        // "Mushroom" + "Risotto" → "Mushroom Risotto": a starting point the owner edits.
        let suggested = cook.versionTitle.flatMap(CookName.normalized).map { title in
            title.localizedCaseInsensitiveContains(dishName) ? title : "\(title) \(dishName)"
        } ?? ""
        _name = State(initialValue: suggested)
        // The old Dish name is a natural collection for the separated Dishes ("Risotto").
        _labels = State(initialValue: DishCollectionPolicy.normalized((cook.dish?.collections ?? []) + (dishName.isEmpty ? [] : [dishName])))
    }
    private var source: Dish? { cook.dish }
    private var others: [Dish] { dishes.filter { $0.id != source?.id && !$0.attempts.isEmpty } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SGTheme.Space.large) {
                    Text("Make **\(cook.displayName)** its own Dish when it’s a different dish, not another cook of **\(source?.name ?? "this Dish")**.")
                        .fixedSize(horizontal: false, vertical: true)
                    SGFormSection(title: "New Dish") {
                        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
                            TextField("Dish name (required)", text: $name).font(SGTheme.TypeRole.title)
                                .accessibilityIdentifier("move-cook-name").sgField()
                            if flags.isOn(.dishCollections) { DishCollectionsField(labels: $labels) }
                            Button { move(to: nil) } label: { Text("Make It a Separate Dish").frame(maxWidth: .infinity) }
                                .buttonStyle(SGButtonStyle(prominent: true))
                                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("move-cook-confirm")
                        }
                    }
                    if !others.isEmpty {
                        SGFormSection(title: "Or an existing Dish") {
                            Button { choosing = true } label: { Label("Move to a Dish You’ve Made…", systemImage: "arrow.right").frame(maxWidth: .infinity, minHeight: SGTheme.Size.minimumTap, alignment: .leading) }
                                .buttonStyle(SGButtonStyle(compact: true)).accessibilityIdentifier("move-cook-existing")
                        }
                    }
                    Text("Its ranking, score, photos and notes move with it. \(source?.name ?? "The Dish")’s Recipe, description and earlier posts stay where they are.")
                        .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }.padding(SGTheme.Space.medium).frame(maxWidth: SGTheme.Size.contentMaximum).frame(maxWidth: .infinity)
            }
            .background(SGTheme.ColorToken.background)
            .navigationTitle("Separate Dish").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .sheet(isPresented: $choosing) {
                DishSelectionView(dishes: others, onSelect: { dish in choosing = false; move(to: dish) }, onCancel: { choosing = false })
            }
            .alert("Couldn't move this cook", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }
    }
    private func move(to destination: Dish?) {
        do {
            let target = try DishIdentityStore.move(cook, toNewDishNamed: name, destination: destination,
                                                    collections: flags.isOn(.dishCollections) ? labels : [], context: context)
            onMoved(target); dismiss()
        } catch { self.error = "Nothing changed. Try again." }
    }
}

// MARK: - My Kitchen collections

/// My Kitchen: collections as compact cards (photo, name, "3 Dishes · 7 cooks"). A view over Dishes only.
struct KitchenCollectionsSection: View {
    let summaries: [DishCollectionSummary]
    let scores: ScoreUnlockState
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            SGSectionHeader(title: "Collections")
            if summaries.isEmpty {
                Text("Group related Dishes, like all your risottos, from any Dish’s page.")
                    .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary).accessibilityIdentifier("collections-empty")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: SGTheme.Space.small) {
                        ForEach(summaries) { summary in
                            NavigationLink { DishCollectionView(label: summary.label) } label: { card(summary) }
                                .buttonStyle(.plain)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(summary.label), \(summary.dishCountText), \(summary.cookCountText)")
                                .accessibilityHint("Opens the collection").accessibilityIdentifier("kitchen-collection-\(summary.label)")
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
    @State private var renaming = false
    @State private var newName = ""
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
                    if summary.members.count > 8 { SGSearchField(placeholder: "Search this collection", text: $search, identifier: "collection-search") }
                    ForEach(Array(members.enumerated()), id: \.element.id) { index, member in row(member, position: index + 1) }
                } else {
                    SGContentState(title: "Collection is empty", symbol: "square.stack", message: "Add Dishes to “\(label)” from their pages.")
                }
            }
            .padding(SGTheme.Space.medium).frame(maxWidth: SGTheme.Size.contentMaximum).frame(maxWidth: .infinity)
        }
        .background(SGTheme.ColorToken.background)
        .navigationTitle(label).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename Collection", systemImage: "pencil") { newName = label; renaming = true }.accessibilityIdentifier("collection-rename")
                    Button("Delete Collection", systemImage: "trash", role: .destructive) { removing = true }.accessibilityIdentifier("collection-delete")
                } label: { SGToolbarIcon(symbol: "ellipsis") }.accessibilityLabel("Collection actions").accessibilityIdentifier("collection-actions")
            }
        }
        .alert("Rename Collection", isPresented: $renaming) {
            TextField("Name", text: $newName)
            Button("Save") { apply { try DishCollectionStore.rename(label, to: newName, dishes: dishes, context: context); dismiss() } }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Delete “\(label)”?", isPresented: $removing) {
            Button("Delete Collection", role: .destructive) { apply { try DishCollectionStore.remove(label, dishes: dishes, context: context); dismiss() } }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Only the collection goes. Every Dish, cook and Recipe in it stays.") }
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
    private func apply(_ work: () throws -> Void) { do { try work() } catch { self.error = "Nothing changed. Try again." } }
}
