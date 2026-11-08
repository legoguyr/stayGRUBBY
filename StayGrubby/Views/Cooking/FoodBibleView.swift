import SwiftUI
import SwiftData
import Supabase

/// Independent authorized Recipes; optional cooking links never define Recipe identity.
struct FoodBibleView: View {
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @Environment(\.dynamicTypeSize) private var textSize
    @Query private var dishes: [Dish]
    @State private var entries: [CookbookEntry] = []
    @State private var query = ""
    @State private var filters = RecipeFilters()
    @State private var sort = RecipeBrowseSort.updated
    @State private var showingFilters = false
    @State private var loading = true
    @State private var failed = false
    @State private var generation = UUID()
    @State private var choosing = false
    @State private var selected: CookbookRoute?
    private var visible: [CookbookEntry] { filters.entries(entries, query: query, sort: sort) }
    private var dishLookup: [UUID: Dish] { Dictionary(uniqueKeysWithValues: dishes.map { ($0.id,$0) }) }
    var body: some View {
        let lookup = dishLookup
        ScrollView {
            VStack(alignment: .leading, spacing: SGTheme.Space.large) {
                if loading && entries.isEmpty { SGLoadingState(label: "Opening your cookbook") }
                if failed {
                    SGContentState(title: "Couldn’t refresh", symbol: "wifi.exclamationmark", message: "Your cookbook needs a connection to refresh.") {
                        Button("Retry") { Task { await load() } }.buttonStyle(SGButtonStyle())
                    }
                }
                if !loading && !failed && visible.isEmpty {
                    SGContentState(title: entries.isEmpty ? "No Recipes yet" : "No matching Recipes", symbol: "book.closed",
                                   message: entries.isEmpty ? "Add a Recipe to your Food Bible." : "Try another search or clear your filters.") {
                        Button(entries.isEmpty ? "Add Recipe" : "Clear search & filters") {
                            if entries.isEmpty { choosing = true } else { query = ""; filters = RecipeFilters() }
                        }.buttonStyle(SGButtonStyle(prominent: entries.isEmpty)).accessibilityIdentifier("bible-empty-add")
                    }
                }
                LazyVGrid(columns: textSize.isAccessibilitySize ? [GridItem(.flexible(minimum: 0), alignment: .top)] : [GridItem(.flexible(minimum: 0), alignment: .top), GridItem(.flexible(minimum: 0), alignment: .top)], alignment: .leading, spacing: SGTheme.Space.large) {
                    ForEach(visible) { entry in
                        Button { selected = .init(recipeID: entry.recipeID, dishID: entry.dishID) } label: {
                            CookbookCard(entry: entry, dish: entry.dishID.flatMap { lookup[$0] })
                        }.buttonStyle(.plain).accessibilityIdentifier("bible-entry-\(entry.recipeID)")
                    }
                }
                if !entries.isEmpty { Text(entries.count == 1 ? "1 Recipe" : "\(entries.count) Recipes").font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("bible-count") }
            }.padding(SGTheme.Space.margin).frame(maxWidth: SGTheme.Size.contentMaximum).frame(maxWidth: .infinity)
        }.accessibilityIdentifier("bible-scroll").background(SGTheme.ColorToken.background).scrollDismissesKeyboard(.interactively)
            .safeAreaPadding(.bottom, SGTheme.Space.medium)
            .safeAreaInset(edge: .top, spacing: 0) { searchHeader }
            .navigationTitle("Food Bible").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { SGPrimaryBrandTitle(page: "Food Bible") }; ToolbarItem(placement: .primaryAction) { Button("Add Recipe", systemImage: "plus") { choosing = true }.accessibilityIdentifier("bible-add") }.sgIndependentToolbarBackground() }
            .task { await load() }.refreshable { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
            .onChange(of: phase) { _, next in generation = UUID(); entries = []; if next == .active { Task { await load() } } }
            .sheet(isPresented: $showingFilters) { RecipeFiltersSheet(filters: $filters, entries: entries) }
            .sheet(isPresented: $choosing) { RecipeCreationChoice(entries: entries) }
            .navigationDestination(item: $selected) { route in RecipeDetailView(id: route.recipeID, dishID: route.dishID) }
    }
    /// Same two-row grammar as Grub Rank: search, then Filters + Sort (+ clear).
    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            SGSearchField(placeholder: "Dish, ingredient, cuisine…", text: $query, identifier: "bible-search",
                          clearIdentifier: "bible-search-clear", accessibilityLabel: "Search your cookbook")
            HStack(spacing: SGTheme.Space.xSmall) {
                SGFilterButton(count: RecipeFilterGroup.allCases.reduce(0) { $0 + filters.count($1) }, identifier: "bible-filters-open") {
                    showingFilters = true
                }
                SGBrowseSortMenu(options: RecipeBrowseSort.allCases, selection: $sort, title: { $0.rawValue },
                                 active: sort != .updated, identifier: "bible-sort", label: sort.rawValue)
                Spacer(minLength: 0)
                if filters.isActive { SGIconButton(title: "Clear Filters", symbol: "xmark") { filters = RecipeFilters() }.accessibilityIdentifier("bible-clear-filters") }
            }.accessibilityElement(children: .contain).accessibilityIdentifier("bible-filters")
        }.padding(.horizontal, SGTheme.Space.margin).padding(.top, SGTheme.Space.compact).padding(.bottom, SGTheme.Space.xSmall)
            .background(SGTheme.ColorToken.background)
    }
    private func load() async {
        guard let request else { failed = true; loading = false; return }
        let token = UUID(); generation = token; loading = true; failed = false
        defer { if generation == token { loading = false } }
        do { let next = try await CookbookIndex.load(request: request); guard !Task.isCancelled, generation == token else { return }; entries = next }
        catch is CancellationError {} catch { if generation == token { entries = []; failed = true } }
    }
}
struct CookbookRoute: Hashable { let recipeID: UUID; let dishID: UUID? }

struct CookbookPhoto: View {
    var dish: Dish?
    var name: String
    var compact = false
    var cook: CookingAttempt? = nil
    var body: some View {
        if let media = (cook ?? dish?.cookbookRepresentativeCook)?.primaryImage {
            DishPhoto(media: media, thumbnail: true, name: name)
        } else {
            SGPhotoPlaceholder().accessibilityLabel("No photo for \(name)")
        }
    }
}
struct CookbookCard: View {
    let entry: CookbookEntry
    var dish: Dish?
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.compact) {
            RecipePhoto(id: entry.photoID, dish: dish, name: entry.recipeTitle, cook: dish?.attempts.first { $0.id == entry.linkedAttemptID }, exactCookLink: entry.linkedAttemptID != nil).sgPhotoFrame(.cookbook).accessibilityHidden(true)
            Text(entry.recipeTitle).font(SGTheme.TypeRole.dish).foregroundStyle(SGTheme.ColorToken.primaryText).fixedSize(horizontal: false, vertical: true)
            let metadata = [entry.cuisine, entry.duration.map { "\($0) min" } ?? entry.course.flatMap { DishCategory(rawValue: $0)?.label }].compactMap { $0 }.joined(separator: " · ")
            if !metadata.isEmpty { Text(metadata).font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .ignore).accessibilityLabel([entry.recipeTitle, entry.cuisine, entry.duration.map { "\($0) minutes" }].compactMap { $0 }.joined(separator: ", ")).accessibilityHint("Opens the recipe")
    }
}
struct CookedDishPicker: View {
    var entries: [CookbookEntry] = []
    var mode: RecipeCreationMode = .manual
    var onComplete: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Dish.name) private var dishes: [Dish]
    @State private var selected: CookingAttempt?
    var body: some View {
        DishSelectionView(dishes: dishes.filter { !$0.attempts.isEmpty }, onSelect: { _ in }, onCancel: { dismiss() }, onSelectCook: { selected = $0 })
            .sheet(item: $selected) { cook in NavigationStack { if let dish = cook.dish { DishRecipeSection(dish: dish, attempt: cook).padding() } } }
    }
}
struct DishRecipeDestination: View {
    let dish: Dish
    var onDone: (() -> Void)? = nil
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: SGTheme.Space.large) {
            Text(dish.name).font(SGTheme.TypeRole.hero)
            DishRecipeSection(dish: dish)
        }.padding(SGTheme.Space.medium) }.background(SGTheme.ColorToken.background).navigationTitle("Recipe")
            .toolbar { if let onDone { ToolbarItem(placement: .cancellationAction) { Button("Done", action: onDone) } } }
    }
}

private struct CookRecipeResponse: Decodable {
    var recipe: Recipe?
    var legacyFamilyLink: Bool?
    var linkedRecipeID: UUID?
    var exactCookLink: Bool?
    var usedRecipe: RecipeCookSnapshot?
}
struct DishRecipeSection: View {
    let dish: Dish
    var attempt: CookingAttempt? = nil
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @State private var recipe: Recipe?
    @State private var loaded = false
    @Query private var syncBindings: [SyncStoreBinding]
    @State private var relationshipError: String?
    private var cookAvailable: Bool {
        guard let attempt else { return true }
        return CookPublicationReadiness.revision(for: attempt, binding: syncBindings.first, requireCurrent: false) != nil
    }
    @State private var creating = false
    @State private var selecting = false
    @State private var legacy = false
    @State private var linkedID: UUID?
    @State private var exactLink = false
    @State private var usedRecipe: RecipeCookSnapshot?
    @State private var generation = UUID()
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            if let usedRecipe {
                SGSectionHeader(title: "Recipe used")
                if let creator = usedRecipe.creatorName { Text("Created by \(creator)").font(.subheadline).accessibilityIdentifier("cook-recipe-creator") }
                NavigationLink { RecipeSnapshotView(cook: usedRecipe) } label: { Label(usedRecipe.snapshot.title, systemImage: "clock") }.accessibilityIdentifier("cook-recipe-snapshot")
                Text("Recipe revision \(usedRecipe.revision) when this cook began").font(.caption).foregroundStyle(.secondary)
            }
            SGSectionHeader(title: "Recipe")
            if let recipe {
                NavigationLink { RecipeDetailView(id: recipe.id) } label: { Label(recipe.content.title, systemImage: "book") }.accessibilityIdentifier("dish-view-recipe")
                if legacy { Text("Legacy link: no specific cook recorded.").font(.footnote).foregroundStyle(.secondary) }
            } else if loaded {
                if linkedID != nil && (exactLink || legacy) {
                    Text("Linked Recipe unavailable").foregroundStyle(.secondary)
                    Button("Unlink Recipe") { Task { await unlink() } }
                } else if attempt != nil {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: SGTheme.Space.medium) { relationshipActions }
                        VStack(alignment: .leading, spacing: SGTheme.Space.small) { relationshipActions }
                    }

                } else { Text("Choose a cook to link a Recipe.").foregroundStyle(.secondary) }
            }
            if !cookAvailable { Text("Recipe links are available once this cook syncs.").font(.footnote) }
            else if let relationshipError {
                Text(relationshipError).font(.footnote).accessibilityIdentifier("cook-recipe-error")
                Button("Retry Recipe") { Task { await load() } }
            }
        }.task(id: "\(attempt?.id ?? dish.id):\(cookAvailable)") { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
            .onChange(of: phase) { _, next in generation = UUID(); recipe = nil; usedRecipe = nil; linkedID = nil; exactLink = false; legacy = false; loaded = false; if next == .active { Task { await load() } } }
            .onDisappear { generation = UUID() }
            .sheet(isPresented: $creating, onDismiss: { Task { await load() } }) {
                RecipeEditor(attemptID: attempt?.id, title: dish.name, course: attempt?.categoryCode ?? dish.defaultCategoryCode, cuisine: dish.cuisineLabel) { recipe = $0; loaded = true }
            }
            .sheet(isPresented: $selecting, onDismiss: { Task { await load() } }) { NavigationStack { RecipeLibraryView(attemptID: attempt?.id) } }
    }
    @ViewBuilder private var relationshipActions: some View {
        if usedRecipe == nil {
            Button("Add Recipe", systemImage: "plus") { creating = true }
                .buttonStyle(RecipeInlineAction()).accessibilityIdentifier("dish-add-recipe")
        }
        Button("Link Existing Recipe", systemImage: "link") { selecting = true }
            .buttonStyle(RecipeInlineAction()).accessibilityIdentifier("dish-link-recipe")
    }
    private func load() async {
        guard cookAvailable, let request else { return }; let token = UUID(); generation = token
        do {
            var payload = SocialPayload(); payload.dishID = dish.id; payload.attemptID = attempt?.id
            let data = try await request("recipes", attempt == nil ? "dish" : "cook", payload)
            let page = try JSONDecoder().decode(CookRecipeResponse.self, from: data)
            guard !Task.isCancelled, generation == token else { return }
            recipe = page.recipe; usedRecipe = page.usedRecipe; exactLink = page.exactCookLink ?? false; linkedID = page.linkedRecipeID; legacy = page.legacyFamilyLink ?? (attempt == nil); loaded = true; relationshipError = nil
        } catch is CancellationError {} catch {
            guard generation == token else { return }
            recipe = nil; usedRecipe = nil; linkedID = nil; exactLink = false; legacy = false; loaded = false
            if error is DecodingError { relationshipError = "Couldn’t read this Recipe link. Try again." }
            else if error is URLError { relationshipError = "Recipe links need a connection. Try again when you’re online." }
            else if (error as? PostgrestError)?.code == "42501" { relationshipError = "This cook or its Recipe link is unavailable." }
            else { relationshipError = "Couldn’t load Recipe links. Try again." }
        }
    }
    private func unlink() async {
        guard let request, let linkedID else { return }
        do {
            var payload = SocialPayload(); payload.recipeID = linkedID
            if legacy { payload.dishID = dish.id; _ = try await request("recipes", "detach", payload) }
            else { payload.previousAttemptID = attempt?.id; _ = try await request("recipes", "unlink_cook", payload) }
            NotificationCenter.default.post(name: .socialContentChanged, object: nil); await load()
        } catch { relationshipError = "Couldn’t unlink this Recipe. Try again." }
    }
}

// Presentation-only selection, reusing existing media without copying files or relationships.
extension Dish {
    var cookbookRepresentativeCook: CookingAttempt? {
        let ordered = attempts.sorted { $0.createdAt != $1.createdAt ? $0.createdAt > $1.createdAt : $0.sequenceNumber != $1.sequenceNumber ? $0.sequenceNumber > $1.sequenceNumber : $0.id.uuidString < $1.id.uuidString }
        return ordered.first { $0.primaryImage != nil } ?? ordered.first
    }
}
