import SwiftUI
import SwiftData
import Supabase

/// Independent authorized Recipes; optional cooking links never define Recipe identity.
struct FoodBibleView: View {
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.accountContentCache) private var cache
    @Query private var dishes: [Dish]
    @State private var entries: [CookbookEntry] = []
    @State private var query = ""
    @State private var filters = RecipeFilters()
    @State private var sort = RecipeBrowseSort.updated
    @State private var filterGroup: RecipeFilterGroup?
    @State private var loading = true
    @State private var failed = false
    @State private var generation = UUID()
    @State private var choosing = false
    @State private var selected: CookbookRoute?
    /// Connected UI Phase 1: owned Recipes vs saved references to other Sous Chefs' Recipes.
    @State private var library = FoodBibleLibrary.mine
    @State private var saved: [RecipeTicket] = []
    @State private var savedLoaded = false
    @State private var savedFailed = false
    @State private var savedGeneration = UUID()
    @State private var openingSaved: UUID?
    private var visible: [CookbookEntry] { filters.entries(CookbookIndex.resolvingCooked(entries, dishes: dishLookup), query: query, sort: sort) }
    private var dishLookup: [UUID: Dish] { Dictionary(uniqueKeysWithValues: dishes.map { ($0.id,$0) }) }
    var body: some View {
        let lookup = dishLookup
        ScrollView {
            if library == .saved { savedRecipes } else {
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
            }
        }.accessibilityIdentifier("bible-scroll").background(SGTheme.ColorToken.background).scrollDismissesKeyboard(.interactively)
            .safeAreaPadding(.bottom, SGTheme.Space.medium)
            .safeAreaInset(edge: .top, spacing: 0) { searchHeader }
            .navigationTitle("Food Bible").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { SGPrimaryBrandTitle(page: "Food Bible") }; ToolbarItem(placement: .primaryAction) { Button("Add Recipe", systemImage: "plus") { choosing = true }.accessibilityIdentifier("bible-add") }.sgIndependentToolbarBackground() }
            // Read caching (MVP stabilization): tab switches, back navigation and returning to the app show
            // the cookbook at once; it refreshes in the background only when stale or after a change.
            .task { await load(onlyIfStale: true) }.refreshable { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in cache?.invalidateRecipes(); Task { await load() } }
            .onChange(of: phase) { _, next in generation = UUID(); if next == .active { Task { await load(onlyIfStale: true) } } }
            .sheet(item: $filterGroup) { group in SGFilterGroupSheet { RecipeFilterView(filters: $filters, group: group, entries: entries) } }
            .sheet(isPresented: $choosing) { AddRecipeFlow(context: .library, entries: entries) }
            // Connected UI: an owned Recipe whose Dish is on this device opens that Dish's page on its
            // Recipe tab; otherwise the standalone reader (it still links to the Dish when it can).
            .navigationDestination(item: $selected) { route in
                if let dish = route.dishID.flatMap({ lookup[$0] }) { DishView(dish: dish, tab: .recipe) }
                else { RecipeDetailView(id: route.recipeID, dishID: route.dishID) }
            }
            .navigationDestination(item: $openingSaved) { RecipeDetailView(id: $0) }
            .onChange(of: library) { _, next in if next == .saved { Task { await loadSaved(onlyIfStale: true) } } }
            .onReceive(NotificationCenter.default.publisher(for: .recipeSavesChanged)) { _ in cache?.savedRecipes.invalidate(); if savedLoaded { Task { await loadSaved() } } }
    }
    /// Same LEGO filter grammar as Grub Rank (`SGFilterChip` → `SGFilterGroupSheet`, Sort, one clear X);
    /// Food Bible offers the deeper Recipe groups. Chips wrap into two even rows.
    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            Picker("Recipes", selection: $library) {
                ForEach(FoodBibleLibrary.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented).accessibilityIdentifier("bible-library")
            SGSearchField(placeholder: library == .saved ? "Search saved Recipes" : "Dish, ingredient, cuisine…", text: $query, identifier: "bible-search",
                          clearIdentifier: "bible-search-clear", accessibilityLabel: "Search your cookbook")
            if library == .mine {
            VStack(spacing: SGTheme.Space.xSmall) {
                HStack(spacing: SGTheme.Space.xSmall) { filterChips([.course, .cuisine, .diet, .cooked]) }
                HStack(spacing: SGTheme.Space.xSmall) { filterChips([.contains, .avoid, .source]) }
            }
            HStack(spacing: SGTheme.Space.xSmall) {
                SGBrowseSortMenu(options: RecipeBrowseSort.allCases, selection: $sort, title: { $0.rawValue },
                                 active: sort != .updated, identifier: "bible-sort", label: sort.rawValue)
                Spacer(minLength: 0)
                // One X clears search and filters, shown while either is active (same control as Grub Rank).
                SGIconButton(title: filters.isActive ? "Clear Search and Filters" : "Clear Search", symbol: "xmark") { filters = RecipeFilters(); query = "" }
                    .opacity(clearActive ? 1 : 0).disabled(!clearActive).accessibilityHidden(!clearActive)
                    .accessibilityIdentifier(clearActive ? "bible-clear-filters" : "bible-clear-filters-hidden")
            }.accessibilityElement(children: .contain).accessibilityIdentifier("bible-filters")
            }
        }.padding(.horizontal, SGTheme.Space.margin).padding(.top, SGTheme.Space.compact).padding(.bottom, SGTheme.Space.xSmall)
            .background(SGTheme.ColorToken.background)
    }
    private var clearActive: Bool { filters.isActive || !query.isEmpty }

    private var visibleSaved: [RecipeTicket] {
        let needle = CookbookSearch.normalized(query)
        guard !needle.isEmpty else { return saved }
        return saved.filter { ticket in
            guard let recipe = ticket.recipe else { return false }
            return CookbookSearch.normalized([recipe.content.title, recipe.content.cuisine, recipe.creator?.displayName, recipe.content.originalCreator].compactMap { $0 }.joined(separator: " ")).contains(needle)
        }
    }
    /// Saved references only: the original creator keeps ownership; nothing is copied.
    private var savedRecipes: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.large) {
            if !savedLoaded && !savedFailed { SGLoadingState(label: "Opening Saved Recipes") }
            if savedFailed {
                SGContentState(title: "Couldn’t load Saved Recipes", symbol: "wifi.exclamationmark", message: "Saved Recipes need a connection.") {
                    Button("Retry") { Task { await loadSaved() } }.buttonStyle(SGButtonStyle())
                }
            }
            if savedLoaded && visibleSaved.isEmpty {
                SGContentState(title: saved.isEmpty ? "No Saved Recipes yet" : "No matching Saved Recipes", symbol: "bookmark",
                               message: saved.isEmpty ? "Save a Sous Chef’s Recipe from its page. It stays theirs; you keep a reference." : "Try another search.") { EmptyView() }
                    .accessibilityIdentifier("bible-saved-empty")
            }
            LazyVGrid(columns: textSize.isAccessibilitySize ? [GridItem(.flexible(minimum: 0), alignment: .top)] : [GridItem(.flexible(minimum: 0), alignment: .top), GridItem(.flexible(minimum: 0), alignment: .top)], alignment: .leading, spacing: SGTheme.Space.large) {
                ForEach(visibleSaved) { ticket in
                    if let recipe = ticket.recipe {
                        Button { openingSaved = recipe.id } label: { SavedRecipeCard(recipe: recipe) }
                            .buttonStyle(.plain).accessibilityIdentifier("bible-saved-\(recipe.id)")
                    } else {
                        // Access ended (unshared, blocked or no longer Sous Chefs): no content, only removal.
                        VStack(alignment: .leading, spacing: SGTheme.Space.compact) {
                            SGPhotoPlaceholder().sgPhotoFrame(.cookbook).accessibilityHidden(true)
                            Text("Recipe unavailable").font(SGTheme.TypeRole.dish).foregroundStyle(.secondary)
                            Button("Remove", role: .destructive) { Task { await unsave(ticket.id) } }.frame(minHeight: 44)
                        }.accessibilityElement(children: .contain).accessibilityIdentifier("bible-saved-unavailable-\(ticket.id)")
                    }
                }
            }
            if !saved.isEmpty { Text(saved.count == 1 ? "1 Saved Recipe" : "\(saved.count) Saved Recipes").font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("bible-saved-count") }
        }.padding(SGTheme.Space.margin).frame(maxWidth: SGTheme.Size.contentMaximum).frame(maxWidth: .infinity)
    }
    private func loadSaved(onlyIfStale: Bool = false) async {
        if !savedLoaded, let cached = cache?.savedRecipes.value { saved = cached; savedLoaded = true }
        if onlyIfStale, savedLoaded, cache?.savedRecipes.isFresh() == true { return }
        guard let request else { savedFailed = true; return }
        let token = UUID(); savedGeneration = token; savedFailed = false
        do {
            let page = try JSONDecoder().decode(TicketsPage.self, from: await request("recipes", "tickets", .init()))
            guard !Task.isCancelled, savedGeneration == token else { return }
            saved = page.tickets; savedLoaded = true; cache?.savedRecipes.store(page.tickets)
        } catch is CancellationError {} catch { if savedGeneration == token, !savedLoaded { savedFailed = true } }
    }
    private func unsave(_ id: UUID) async {
        guard let request else { return }
        var payload = SocialPayload(); payload.recipeID = id
        do { _ = try await request("recipes", "unticket", payload); cache?.savedRecipes.invalidate(); await loadSaved() } catch { savedFailed = true }
    }
    private func filterChips(_ groups: [RecipeFilterGroup]) -> some View {
        ForEach(groups) { group in
            SGFilterChip(title: group.rawValue, count: filters.count(group), identifier: "bible-filter-\(group.rawValue.lowercased())") { filterGroup = group }
        }
    }
    private func load(onlyIfStale: Bool = false) async {
        if entries.isEmpty, let cached = cache?.cookbook.value { entries = cached; loading = false }
        if onlyIfStale, !entries.isEmpty || cache?.cookbook.hasValue == true, cache?.cookbook.isFresh() == true { loading = false; return }
        guard let request else { failed = true; loading = false; return }
        let token = UUID(); generation = token; loading = true; failed = false
        defer { if generation == token { loading = false } }
        do {
            let next = try await CookbookIndex.load(request: request); guard !Task.isCancelled, generation == token else { return }
            entries = next; cache?.cookbook.store(next)
        }
        // A failed background refresh keeps the cookbook already shown.
        catch is CancellationError {} catch { if generation == token, entries.isEmpty { failed = true } }
    }
}
struct CookbookRoute: Hashable { let recipeID: UUID; let dishID: UUID? }
enum FoodBibleLibrary: String, CaseIterable, Identifiable {
    case mine, saved
    var id: String { rawValue }
    var title: String { switch self { case .mine: "My Recipes"; case .saved: "Saved Recipes" } }
}
/// A saved Sous Chef Recipe: its own title, photo and creator credit (never presented as the saver's).
struct SavedRecipeCard: View {
    let recipe: Recipe
    private var creator: String? { RecipeSharingPolicy.creatorCredit(recipe) ?? recipe.creator?.displayName }
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.compact) {
            RecipePhoto(id: recipe.content.photoID, name: recipe.content.title).sgPhotoFrame(.cookbook).accessibilityHidden(true)
            Text(recipe.content.title).font(SGTheme.TypeRole.dish).foregroundStyle(SGTheme.ColorToken.primaryText).fixedSize(horizontal: false, vertical: true)
            if let creator { Text("by \(creator)").font(.caption).foregroundStyle(.secondary).lineLimit(1) }
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .ignore)
            .accessibilityLabel([recipe.content.title, creator.map { "by \($0)" }].compactMap { $0 }.joined(separator: ", "))
            .accessibilityHint("Opens the saved Recipe")
    }
}

struct CookbookPhoto: View {
    var dish: Dish?
    var name: String
    /// The frame this photo fills; it selects the stored rendition (never a stretched thumbnail).
    var role: SGPhotoRole = .hero
    var cook: CookingAttempt? = nil
    var body: some View {
        if let media = (cook ?? dish?.cookbookRepresentativeCook)?.primaryImage {
            // The Recipe shows its Dish's existing cook photo by reference: same stored asset, no copy.
            DishPhoto(media: media, thumbnail: role.usesThumbnailRendition, name: name)
        } else {
            SGPhotoPlaceholder().accessibilityLabel("No photo for \(name)")
        }
    }
}
struct CookbookCard: View {
    let entry: CookbookEntry
    var dish: Dish?
    private var title: String { dish?.name ?? entry.recipeTitle }
    private var status: String? {
        guard let dish else { return entry.cooked == false ? "Not cooked yet" : nil }
        let count = dish.attempts.count
        return count == 0 ? "Not cooked yet" : count == 1 ? "Cooked once" : "Cooked \(count) times"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.compact) {
            RecipePhoto(id: entry.photoID, dish: dish, name: entry.recipeTitle, cook: dish?.attempts.first { $0.id == entry.linkedAttemptID }, exactCookLink: entry.linkedAttemptID != nil).sgPhotoFrame(.cookbook).accessibilityHidden(true)
            // Food Bible lists Dishes with Recipe content: the Dish name leads, the Recipe title
            // follows only when it differs.
            Text(title).font(SGTheme.TypeRole.dish).foregroundStyle(SGTheme.ColorToken.primaryText).fixedSize(horizontal: false, vertical: true)
            if title != entry.recipeTitle { Text(entry.recipeTitle).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            let metadata = [entry.cuisine, entry.duration.map { "\($0) min" } ?? entry.course.flatMap { DishCategory(rawValue: $0)?.label }].compactMap { $0 }.joined(separator: " · ")
            if !metadata.isEmpty { Text(metadata).font(.caption).foregroundStyle(.secondary) }
            // The Dish's verified local cook count (same wording as the Dish page header).
            if let status { Text(status).font(.caption.weight(.semibold)).foregroundStyle(SGTheme.ColorToken.accent).accessibilityIdentifier("bible-cook-status-\(entry.recipeID)") }
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .ignore).accessibilityLabel([title, title == entry.recipeTitle ? nil : entry.recipeTitle, entry.cuisine, entry.duration.map { "\($0) minutes" }, status].compactMap { $0 }.joined(separator: ", ")).accessibilityHint("Opens the recipe")
    }
}
// Presentation-only selection, reusing existing media without copying files or relationships.
extension Dish {
    var cookbookRepresentativeCook: CookingAttempt? {
        let ordered = attempts.sorted { $0.createdAt != $1.createdAt ? $0.createdAt > $1.createdAt : $0.sequenceNumber != $1.sequenceNumber ? $0.sequenceNumber > $1.sequenceNumber : $0.id.uuidString < $1.id.uuidString }
        return ordered.first { $0.primaryImage != nil } ?? ordered.first
    }
}
