import SwiftUI
import SwiftData

/// The two lenses of one Dish (FOOD_ARCHITECTURE §3, Connected UI Phase 1, November 15, 2026).
enum DishTab: String, CaseIterable, Identifiable, Hashable {
    case ranking, recipe
    var id: String { rawValue }
    var title: String { switch self { case .ranking: "Dish & Ranking"; case .recipe: "Recipe" } }
}

/// The canonical Dish page: one header (photo, Dish name, score and rank) over **Dish & Ranking** and
/// **Recipe** tabs. Both tabs read state the page already holds, so switching is immediate and makes
/// no request; the Dish's Recipe is fetched once per page (and on explicit refresh/changes).
/// Works for a cooked Dish (opened from a cook) and a Recipe-only Dish (opened from Food Bible).
struct DishView: View {
    let dish: Dish?
    var cook: CookingAttempt? = nil
    @State private var tab: DishTab
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.cookingMediaRoot) private var mediaRoot
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @Environment(\.returnToRankings) private var returnToRankings
    @Environment(\.accountContentCache) private var cache
    @Environment(\.featureFlags) private var flags
    @State private var recipe = RecipeReaderModel()
    @State private var separating = false
    @State private var separated = false
    @State private var editingCollections = false
    @State private var sharingSocial = false
    @State private var editing = false
    @State private var editingDishText = false
    @State private var reranking = false
    @State private var addingVersion = false
    @State private var versionFinalized = false
    @State private var addingRecipe = false
    @State private var deleting = false
    @State private var error: String?

    init(dish: Dish?, cook: CookingAttempt? = nil, tab: DishTab = .ranking) {
        self.dish = dish ?? cook?.dish; self.cook = cook
        _tab = State(initialValue: tab)
    }
    /// The cook shown on Dish & Ranking: the one opened, else the Dish's best-ranked cook.
    private var shownCook: CookingAttempt? {
        if let cook { return cook }
        guard let attempts = dish?.attempts, !attempts.isEmpty else { return nil }
        func position(_ attempt: CookingAttempt) -> Int {
            guard let item = attempt.rankedItem, let ordered = item.list?.orderedItems else { return .max }
            return ordered.firstIndex { $0.id == item.id } ?? .max
        }
        return attempts.min { position($0) < position($1) }
    }
    private var dishName: String { dish?.name ?? cook?.displayName ?? "Dish" }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SGTheme.Space.medium) {
                header
                if flags.isOn(.dishCollections), let dish { DishCollectionChips(dish: dish) { editingCollections = true } }
                Picker("Dish view", selection: $tab) {
                    ForEach(DishTab.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("dish-tabs")
                switch tab {
                case .ranking: DishRankingTab(dish: dish, cook: shownCook, recipe: recipe, openRecipe: { tab = .recipe },
                                              addRecipe: { addingRecipe = true }, cookAgain: { addingVersion = true })
                case .recipe: recipeTab
                }
            }
            .frame(maxWidth: SGTheme.Size.contentMaximum)
            .padding(.horizontal, SGTheme.Space.medium).padding(.bottom, SGTheme.Space.xLarge)
            .frame(maxWidth: .infinity)
        }
        .background(SGTheme.ColorToken.background)
        .navigationTitle(tab == .ranking ? "Dish Details" : "Recipe").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if tab == .recipe { RecipeReaderToolbar(model: recipe) }
            else if let shownCook {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    DishShareAction(model: .make(for: shownCook), toolbar: true, currentModel: { .make(for: shownCook) })
                    DishActions(editCook: { editing = true }, rerank: { reranking = true },
                                shareWithSousChefs: request == nil ? nil : { sharingSocial = true },
                                editDishText: { editingDishText = true },
                                separateCook: (dish?.attempts.count ?? 0) > 1 ? { separating = true } : nil,
                                editCollections: flags.isOn(.dishCollections) && dish != nil ? { editingCollections = true } : nil,
                                delete: { deleting = true })
                }.sgIndependentToolbarBackground()
            }
        }
        .task(id: dish?.id) { await loadRecipe(onlyIfStale: true) }
        .refreshable { await loadRecipe() }
        .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await loadRecipe() } }
        .onChange(of: phase) { _, next in recipe.cancelPending(); if next == .active { Task { await loadRecipe(onlyIfStale: true) } } }
        .onChange(of: recipe.deleted) { _, deleted in
            // An uncooked Dish leaves with its Recipe; a cooked Dish stays and shows Link a Recipe.
            if deleted, (dish?.attempts.isEmpty ?? true) { dismiss() } else if deleted { recipe.deleted = false; tab = .ranking }
        }
        .onDisappear { recipe.cancelPending() }
        .recipeReaderPresentation(recipe, relatedDish: dish) { await loadRecipe() }
        .sheet(isPresented: $addingRecipe, onDismiss: { Task { await loadRecipe() } }) { if let dish { AddRecipeFlow(context: .dish(dish)) } }
        .sheet(isPresented: $sharingSocial) { if let shownCook { SocialPostComposer(attempt: shownCook, close: { sharingSocial = false }) } }
        .sheet(isPresented: $editingDishText) { if let dish { DishTextEditor(dish: dish) } }
        .sheet(isPresented: $editingCollections) { if let dish { DishCollectionsEditor(dish: dish) } }
        // The cook now belongs to another Dish, so this page (of the original Dish) closes.
        .sheet(isPresented: $separating, onDismiss: { if separated { dismiss() } }) {
            if let shownCook { MoveCookSheet(cook: shownCook) { _ in separated = true } }
        }
        .sheet(isPresented: $editing) { if let shownCook { EditCookingView(attempt: shownCook) } }
        .sheet(isPresented: $reranking) { if let shownCook { ReRankView(attempt: shownCook) } }
        .sheet(isPresented: $addingVersion, onDismiss: {
            if versionFinalized { versionFinalized = false; returnToRankings() }
        }) {
            if let list = shownCook?.rankedItem?.list, let dish {
                CookAgainFlow(list: list, dish: dish, knownRecipe: recipe.recipe, recipeKnown: recipe.loaded, onResultClose: { versionFinalized = true })
            }
        }
        .alert("Delete this Cook?", isPresented: $deleting) {
            Button("Delete Cook", role: .destructive) {
                guard let shownCook else { return }
                do { try CookingStore.delete(shownCook, keepsEmptyDish: recipe.recipe != nil, context: context, mediaDirectory: mediaRoot); dismiss() }
                catch { self.error = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This removes this cook and can’t be undone. Other cooks stay saved. \(recipe.recipe != nil ? "Its Recipe stays in your Food Bible." : "If this is the Dish’s last cook, the Dish is also removed.")") }
        .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
        .deferRemoteCookingUpdates()
    }

    /// One header photo for the whole page: switching tabs never changes it (MVP stabilization,
    /// November 16, 2026). Opened from a cook, that cook's photo leads; otherwise the Dish's photo is its
    /// Recipe's own photo, else the Dish's representative cook photo — the same rule as its Food Bible
    /// card. Every option is an existing stored asset shown by reference, never a copy.
    @ViewBuilder private var header: some View {
        if let media = cook?.primaryImage {
            SGHeroMedia(media: media, name: dishName)
        } else if let value = recipe.recipe {
            // Exactly the Food Bible card's photo: the Recipe's own photo, else its linked/representative cook's.
            RecipePhoto(id: value.content.photoID, dish: dish, name: dishName, cook: linkedCook(value), exactCookLink: value.linkedAttemptID != nil)
                .sgPhotoFrame(.hero).accessibilityIdentifier("recipe-hero")
        } else if let media = dish?.cookbookRepresentativeCook?.primaryImage ?? shownCook?.primaryImage {
            SGHeroMedia(media: media, name: dishName)
        } else {
            SGHeroMedia(media: nil, name: dishName)
        }
        if let shownCook { DishIdentityHeader(attempt: shownCook, showsCookCount: true) }
        else {
            VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                SGEyebrow(text: "Not cooked yet").accessibilityIdentifier("dish-not-cooked")
                Text(dishName).font(SGTheme.TypeRole.hero).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("dish-title")
            }
        }
    }

    @ViewBuilder private var recipeTab: some View {
        if let value = recipe.recipe {
            if recipe.failed {
                // Same offline contract as the standalone reader: the owner's last-opened Recipe stays readable.
                Text("Offline. Showing your previously opened Recipe. Changes need a connection to save.")
                    .font(.subheadline).accessibilityIdentifier("recipe-error")
            }
            RecipeReaderContent(model: recipe, recipe: value, relatedDish: dish, linkedCook: linkedCook(value), showsHeader: false)
        } else if recipe.failed {
            SGContentState(title: "Recipe unavailable", symbol: "wifi.exclamationmark", message: "Recipes need a connection. Your Dish and ranking are unchanged.") {
                Button("Retry") { Task { await loadRecipe() } }.buttonStyle(SGButtonStyle())
            }.accessibilityIdentifier("dish-recipe-error")
        } else if recipe.loaded {
            SGContentState(title: "No Recipe yet", symbol: "book.closed", message: "Add how you make \(dishName): write it, paste it or use one from your Food Bible.") {
                Button("Link a Recipe") { addingRecipe = true }.buttonStyle(SGButtonStyle(prominent: true)).accessibilityIdentifier("dish-link-recipe")
            }
        } else {
            SGLoadingState(label: "Opening the Recipe").frame(maxWidth: .infinity)
        }
    }

    private func linkedCook(_ value: Recipe) -> CookingAttempt? { value.linkedAttemptID.flatMap { id in dish?.attempts.first { $0.id == id } } }

    /// The Dish's Recipe: shown at once from the account cache when known, then refreshed in the
    /// background only when stale or after a change (`onlyIfStale` false: pull to refresh, edits, links).
    private func loadRecipe(onlyIfStale: Bool = false) async {
        guard let dish else { return }
        let cached = cache?.dishRecipe(dish.id)
        if !recipe.loaded, let cached, cached.hasValue { recipe.recipe = cached.value ?? nil; recipe.loaded = true }
        if onlyIfStale, cached?.isFresh() == true { return }
        await recipe.load(dishID: dish.id, request: request)
        if recipe.loaded, !recipe.failed { cache?.storeDishRecipe(recipe.recipe, for: dish.id) }
    }
}

/// Dish & Ranking: the cook's metadata, notes, Recipe summary, provenance, source and every cook.
private struct DishRankingTab: View {
    let dish: Dish?
    let cook: CookingAttempt?
    let recipe: RecipeReaderModel
    var openRecipe: () -> Void
    var addRecipe: () -> Void
    var cookAgain: () -> Void
    @Environment(\.socialRequest) private var request
    @Environment(\.modelContext) private var context
    @ScaledMetric(relativeTo: .caption) private var tagColumnWidth = SGTheme.Size.tagColumnWidth

    var body: some View {
        if let cook { metadata(cook) }
        if let dish {
            if let description = dish.publicDescription { Text(description).font(SGTheme.TypeRole.body).accessibilityIdentifier("dish-public-description") }
            if let notes = dish.privateNotes {
                VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                    SGSectionHeader(title: "Dish Notes · private")
                    Text(notes).accessibilityIdentifier("dish-private-notes")
                }
            }
        }
        VStack(alignment: .leading, spacing: SGTheme.Space.compact) {
            recipeSummary
            if let cook {
                DishUsedRecipe(dish: dish, cook: cook, current: recipe.recipe)
                CookingProvenanceView(itemID: cook.rankedItemID, includesRecipe: false)
            }
        }
        if let source = dish?.source {
            VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                SGSectionHeader(title: "Source")
                SourceSummary(source: source)
            }
        }
        if let notes = cook?.notes {
            VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                SGSectionHeader(title: "Personal Notes · private")
                Text(notes)
            }
        }
        if let dish, let cook {
            DishCooksSection(dish: dish, current: cook, cookAgain: cook.rankedItem?.list == nil ? nil : cookAgain)
        } else if let value = recipe.recipe {
            // A Recipe-only Dish: ranking starts with the first cook of its Recipe.
            SGContentState(title: "Not ranked yet", symbol: "fork.knife", message: "Cook it and rank it to bring \(dish?.name ?? value.content.title) into Grub Rank.") {
                Button { Task { await recipe.begin(context: context, request: request) } } label: { Label("Rank My Version", systemImage: "fork.knife") }
                    .buttonStyle(SGButtonStyle(prominent: true)).disabled(recipe.busy).accessibilityIdentifier("dish-rank-first")
            }
        }
    }

    /// One row: the Dish's Recipe (opens the Recipe tab) or Add Recipe. No extra request.
    @ViewBuilder private var recipeSummary: some View {
        if request != nil {
            if let value = recipe.recipe {
                // A compact preview of what the Recipe tab holds (title when it differs, time, yield,
                // ingredient count), not a second copy of the tab control.
                Button(action: openRecipe) {
                    HStack(spacing: SGTheme.Space.small) {
                        VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                            Label("View Recipe", systemImage: "book").font(SGTheme.TypeRole.headline).foregroundStyle(SGTheme.ColorToken.primaryText)
                            if let summary = DishRecipePreview.summary(value, dishName: dish?.name) {
                                Text(summary).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("dish-recipe-summary")
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityLabel(["View Recipe", DishRecipePreview.summary(value, dishName: dish?.name)].compactMap { $0 }.joined(separator: ", "))
                    .accessibilityIdentifier("dish-view-recipe")
            } else if recipe.loaded, dish != nil {
                Button(action: addRecipe) { Label("Add Recipe", systemImage: "plus").frame(minHeight: 44) }
                    .buttonStyle(RecipeInlineAction()).accessibilityIdentifier("dish-add-recipe")
            }
        }
    }

    private func metadata(_ cook: CookingAttempt) -> some View {
        let tags = cook.dietaryTags.map(\.label).sorted()
        return VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            Label(cook.category.label, systemImage: "fork.knife").font(.subheadline.weight(.semibold))
            Label(cook.cookedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Date unknown", systemImage: "calendar")
                .font(.subheadline).foregroundStyle(.secondary)
            if !tags.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: SGTheme.Space.xSmall) { ForEach(tags, id: \.self) { TagChip(title: $0) } }
                        .fixedSize(horizontal: true, vertical: false)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: tagColumnWidth), alignment: .leading)], alignment: .leading, spacing: SGTheme.Space.xSmall) {
                        ForEach(tags, id: \.self) { TagChip(title: $0) }
                    }
                }
            }
            if !cook.containedAllergens.isEmpty {
                Text("Contains: " + cook.containedAllergens.map(\.label).sorted().joined(separator: ", "))
                    .accessibilityIdentifier("detail-contains")
                Text(CookingProductOptions.allergenSafetyText)
                    .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            }
            if !cook.allergyTags.isEmpty {
                Text("Legacy free-of labels: " + cook.allergyTags.map(\.label).sorted().joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, SGTheme.Space.medium)
    }
}

/// One line describing the Dish's Recipe on Dish & Ranking.
enum DishRecipePreview {
    static func summary(_ recipe: Recipe, dishName: String?) -> String? {
        let content = recipe.content
        let ingredients = content.components.map { $0.reduce(0) { $0 + $1.ingredients.count } } ?? content.ingredients.count
        let minutes = content.elapsedMinutes ?? ((content.prepMinutes ?? 0) + (content.cookMinutes ?? 0))
        let parts: [String?] = [
            content.title.caseInsensitiveCompare(dishName ?? "") == .orderedSame ? nil : content.title,
            minutes > 0 ? "\(minutes) min" : nil,
            content.yield.flatMap { $0.isEmpty ? nil : $0 },
            ingredients > 0 ? (ingredients == 1 ? "1 ingredient" : "\(ingredients) ingredients") : nil,
        ]
        let text = parts.compactMap { $0 }.joined(separator: " · ")
        return text.isEmpty ? nil : text
    }
}

/// The exact Recipe revision this cook was made from, when it differs from the current Recipe.
private struct DishUsedRecipe: View {
    let dish: Dish?
    let cook: CookingAttempt
    let current: Recipe?
    @Environment(\.socialRequest) private var request
    @State private var used: RecipeCookSnapshot?
    var body: some View {
        Group {
            if let used, used.recipeID != current?.id || used.revision != current?.revision {
                NavigationLink { RecipeSnapshotView(cook: used) } label: {
                    Label("Recipe used for this cook · revision \(used.revision)", systemImage: "clock")
                }.frame(minHeight: 44).accessibilityIdentifier("cook-recipe-snapshot")
            }
        }.task(id: cook.id) {
            guard let request, let dish else { return }
            used = try? await DishRecipeService.usedRecipe(for: cook.id, dishID: dish.id, request: request)
        }
    }
}
