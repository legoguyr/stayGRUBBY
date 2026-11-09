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
    @State private var filterGroup: RecipeFilterGroup?
    @State private var loading = true
    @State private var failed = false
    @State private var generation = UUID()
    @State private var choosing = false
    @State private var selected: CookbookRoute?
    private var visible: [CookbookEntry] { filters.entries(CookbookIndex.resolvingCooked(entries, dishes: dishLookup), query: query, sort: sort) }
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
            .sheet(item: $filterGroup) { group in SGFilterGroupSheet { RecipeFilterView(filters: $filters, group: group, entries: entries) } }
            .sheet(isPresented: $choosing) { AddRecipeFlow(context: .library, entries: entries) }
            .navigationDestination(item: $selected) { route in RecipeDetailView(id: route.recipeID, dishID: route.dishID) }
    }
    /// Same LEGO filter grammar as Grub Rank (`SGFilterChip` → `SGFilterGroupSheet`, Sort, one clear X);
    /// Food Bible offers the deeper Recipe groups. Chips wrap into two even rows.
    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            SGSearchField(placeholder: "Dish, ingredient, cuisine…", text: $query, identifier: "bible-search",
                          clearIdentifier: "bible-search-clear", accessibilityLabel: "Search your cookbook")
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
        }.padding(.horizontal, SGTheme.Space.margin).padding(.top, SGTheme.Space.compact).padding(.bottom, SGTheme.Space.xSmall)
            .background(SGTheme.ColorToken.background)
    }
    private var clearActive: Bool { filters.isActive || !query.isEmpty }
    private func filterChips(_ groups: [RecipeFilterGroup]) -> some View {
        ForEach(groups) { group in
            SGFilterChip(title: group.rawValue, count: filters.count(group), identifier: "bible-filter-\(group.rawValue.lowercased())") { filterGroup = group }
        }
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
    private var title: String { dish?.name ?? entry.recipeTitle }
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.compact) {
            RecipePhoto(id: entry.photoID, dish: dish, name: entry.recipeTitle, cook: dish?.attempts.first { $0.id == entry.linkedAttemptID }, exactCookLink: entry.linkedAttemptID != nil).sgPhotoFrame(.cookbook).accessibilityHidden(true)
            // Food Bible lists Dishes with Recipe content: the Dish name leads, the Recipe title
            // follows only when it differs.
            Text(title).font(SGTheme.TypeRole.dish).foregroundStyle(SGTheme.ColorToken.primaryText).fixedSize(horizontal: false, vertical: true)
            if title != entry.recipeTitle { Text(entry.recipeTitle).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            let metadata = [entry.cuisine, entry.duration.map { "\($0) min" } ?? entry.course.flatMap { DishCategory(rawValue: $0)?.label }].compactMap { $0 }.joined(separator: " · ")
            if !metadata.isEmpty { Text(metadata).font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .ignore).accessibilityLabel([title, title == entry.recipeTitle ? nil : entry.recipeTitle, entry.cuisine, entry.duration.map { "\($0) minutes" }].compactMap { $0 }.joined(separator: ", ")).accessibilityHint("Opens the recipe")
    }
}
// Presentation-only selection, reusing existing media without copying files or relationships.
extension Dish {
    var cookbookRepresentativeCook: CookingAttempt? {
        let ordered = attempts.sorted { $0.createdAt != $1.createdAt ? $0.createdAt > $1.createdAt : $0.sequenceNumber != $1.sequenceNumber ? $0.sequenceNumber > $1.sequenceNumber : $0.id.uuidString < $1.id.uuidString }
        return ordered.first { $0.primaryImage != nil } ?? ordered.first
    }
}
