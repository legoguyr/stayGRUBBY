import SwiftUI
import SwiftData

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
    @State private var filterGroup: RecipeFilterGroup?
    @State private var loading = true
    @State private var failed = false
    @State private var generation = UUID()
    @State private var choosing = false
    @State private var selected: CookbookRoute?
    @FocusState private var searching: Bool
    private var visible: [CookbookEntry] { filters.entries(entries, query: query, sort: sort) }
    private var dishLookup: [UUID: Dish] { Dictionary(uniqueKeysWithValues: dishes.map { ($0.id,$0) }) }
    var body: some View {
        let lookup = dishLookup
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if loading && entries.isEmpty { ProgressView("Opening your cookbook").frame(maxWidth: .infinity) }
                if failed {
                    Label("Your cookbook needs a connection to refresh.", systemImage: "wifi.exclamationmark").font(.subheadline)
                    Button("Retry") { Task { await load() } }.buttonStyle(SGButtonStyle())
                }
                if !loading && !failed && visible.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: "book.closed").font(.system(size: 44, weight: .light)).foregroundStyle(SGTheme.ColorToken.accent).accessibilityHidden(true)
                        Text(entries.isEmpty ? "No recipes yet" : "No matching recipes").font(SGTheme.TypeRole.hero)
                        Text(entries.isEmpty ? "Add a recipe to your Food Bible." : "Try another search or clear your filters.").foregroundStyle(.secondary)
                        Button(entries.isEmpty ? "Add Recipe" : "Clear search & filters") {
                            if entries.isEmpty { choosing = true } else { query = ""; filters = RecipeFilters() }
                        }.buttonStyle(SGButtonStyle(prominent: true)).accessibilityIdentifier("bible-empty-add")
                    }.padding(.vertical, 32)
                }
                LazyVGrid(columns: textSize.isAccessibilitySize ? [GridItem(.flexible(minimum: 0), alignment: .top)] : [GridItem(.flexible(minimum: 0), alignment: .top), GridItem(.flexible(minimum: 0), alignment: .top)], alignment: .leading, spacing: 24) {
                    ForEach(visible) { entry in
                        Button { selected = .init(recipeID: entry.recipeID, dishID: entry.dishID) } label: {
                            CookbookCard(entry: entry, dish: entry.dishID.flatMap { lookup[$0] })
                        }.buttonStyle(.plain).accessibilityIdentifier("bible-entry-\(entry.recipeID)")
                    }
                }
                if !entries.isEmpty { Text("\(entries.count) recipes").font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("bible-count") }
            }.padding(16).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.accessibilityIdentifier("bible-scroll").background(SGTheme.ColorToken.background).scrollDismissesKeyboard(.interactively)
            .safeAreaPadding(.bottom, SGTheme.Space.medium)
            .safeAreaInset(edge: .top, spacing: 0) { searchHeader }
            .navigationTitle("Food Bible").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { SGPrimaryBrandTitle(page: "Food Bible") }; ToolbarItem(placement: .primaryAction) { Button("Add Recipe", systemImage: "plus") { choosing = true }.accessibilityIdentifier("bible-add") }.sharedBackgroundVisibility(.hidden) }
            .task { await load() }.refreshable { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
            .onChange(of: phase) { _, next in generation = UUID(); entries = []; if next == .active { Task { await load() } } }
            .sheet(item: $filterGroup) { RecipeFilterView(filters: $filters, group: $0, entries: entries) }
            .sheet(isPresented: $choosing) { RecipeCreationChoice(entries: entries) }
            .navigationDestination(item: $selected) { route in RecipeDetailView(id: route.recipeID, dishID: route.dishID) }
    }
    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").accessibilityHidden(true)
                TextField("Dish, ingredient, cuisine…", text: $query).accessibilityLabel("Search your cookbook").accessibilityIdentifier("bible-search").focused($searching).submitLabel(.search).onSubmit { searching = false }
                if !query.isEmpty { Button("Clear search", systemImage: "xmark.circle.fill") { query = "" }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("bible-search-clear") }
            }.sgField()
            HStack(spacing: SGTheme.Space.xSmall) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SGTheme.Space.xSmall) {
                        ForEach(RecipeFilterGroup.allCases) { group in
                            let count = filters.count(group)
                            Button { searching = false; filterGroup = group } label: {
                                SGBrowseControlLabel(title: group.rawValue + (count > 0 ? " \(count)" : ""), symbol: "chevron.down", active: count > 0)
                            }.buttonStyle(.plain).accessibilityLabel("\(group.rawValue), \(count) active selections").accessibilityIdentifier("bible-filter-\(group.rawValue.lowercased())")
                        }
                    }
                }.accessibilityIdentifier("bible-filters")
                SGBrowseSortMenu(options: RecipeBrowseSort.allCases, selection: $sort, title: { $0.rawValue }, active: sort != .updated, identifier: "bible-sort")
                if filters.isActive { SGIconButton(title: "Clear Filters", symbol: "xmark") { filters = RecipeFilters() }.accessibilityIdentifier("bible-clear-filters") }
            }

        }.padding(.horizontal, 16).padding(.top, 8).background(SGTheme.ColorToken.background)
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
            SGFoodPlaceholder().accessibilityLabel("No photo for \(name)")
        }
    }
}
struct CookbookCard: View {
    let entry: CookbookEntry
    var dish: Dish?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RecipePhoto(id: entry.photoID, dish: dish, name: entry.recipeTitle, cook: dish?.attempts.first { $0.id == entry.linkedAttemptID }, exactCookLink: entry.linkedAttemptID != nil).aspectRatio(0.9, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityHidden(true)
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
    @State private var failed = false
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
            SGSectionHeader(title: legacy ? "Dish family Recipe" : exactLink ? "Linked Recipe" : "Current Recipe")
            if let recipe {
                NavigationLink { RecipeDetailView(id: recipe.id) } label: { Label(recipe.content.title, systemImage: "book") }.accessibilityIdentifier("dish-view-recipe")
                if legacy { Text("Legacy link: no specific version recorded.").font(.footnote).foregroundStyle(.secondary) }
            } else if loaded {
                if linkedID != nil && (exactLink || legacy) {
                    Text("Linked Recipe unavailable").foregroundStyle(.secondary)
                    Button("Unlink Recipe") { Task { await unlink() } }
                } else if attempt != nil {
                    if usedRecipe == nil { Button("Add Recipe", systemImage: "plus") { creating = true }.buttonStyle(SGButtonStyle()).accessibilityIdentifier("dish-add-recipe") }
                    Button("Link an Existing Recipe") { selecting = true }.frame(minHeight: 44).accessibilityIdentifier("dish-link-recipe")
                } else { Text("Choose a version to link a Recipe.").foregroundStyle(.secondary) }
            }
            if failed { Button("Retry Recipe") { Task { await load() } }; Text("Recipe access needs a connection and completed cooking sync.").font(.footnote) }
        }.task(id: attempt?.id ?? dish.id) { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
            .onChange(of: phase) { _, next in generation = UUID(); recipe = nil; usedRecipe = nil; linkedID = nil; exactLink = false; legacy = false; loaded = false; if next == .active { Task { await load() } } }
            .onDisappear { generation = UUID() }
            .sheet(isPresented: $creating, onDismiss: { Task { await load() } }) {
                RecipeEditor(attemptID: attempt?.id, title: dish.name, course: attempt?.categoryCode ?? dish.defaultCategoryCode, cuisine: dish.cuisineLabel) { recipe = $0; loaded = true }
            }
            .sheet(isPresented: $selecting, onDismiss: { Task { await load() } }) { NavigationStack { RecipeLibraryView(attemptID: attempt?.id) } }
    }
    private func load() async {
        guard let request else { failed = true; return }; let token = UUID(); generation = token
        do {
            var payload = SocialPayload(); payload.dishID = dish.id; payload.attemptID = attempt?.id
            let data = try await request("recipes", attempt == nil ? "dish" : "cook", payload)
            let page = try JSONDecoder().decode(CookRecipeResponse.self, from: data)
            guard !Task.isCancelled, generation == token else { return }
            recipe = page.recipe; usedRecipe = page.usedRecipe; exactLink = page.exactCookLink ?? false; linkedID = page.linkedRecipeID; legacy = page.legacyFamilyLink ?? (attempt == nil); loaded = true; failed = false
        } catch is CancellationError {} catch { if generation == token { recipe = nil; usedRecipe = nil; linkedID = nil; exactLink = false; legacy = false; loaded = false; failed = true } }
    }
    private func unlink() async {
        guard let request, let linkedID else { return }
        do {
            var payload = SocialPayload(); payload.recipeID = linkedID
            if legacy { payload.dishID = dish.id; _ = try await request("recipes", "detach", payload) }
            else { payload.previousAttemptID = attempt?.id; _ = try await request("recipes", "unlink_cook", payload) }
            NotificationCenter.default.post(name: .socialContentChanged, object: nil); await load()
        } catch { failed = true }
    }
}

// Presentation-only selection, reusing existing media without copying files or relationships.
extension Dish {
    var cookbookRepresentativeCook: CookingAttempt? {
        let ordered = attempts.sorted { $0.createdAt != $1.createdAt ? $0.createdAt > $1.createdAt : $0.sequenceNumber != $1.sequenceNumber ? $0.sequenceNumber > $1.sequenceNumber : $0.id.uuidString < $1.id.uuidString }
        return ordered.first { $0.primaryImage != nil } ?? ordered.first
    }
}
