import SwiftUI
import SwiftData

struct CookingRankingView: View {
    let list: RankingList
    /// Dish Variations V2: scope this page to one variation's Dishes (its own title, back navigation and
    /// numbering within the variation). Nil is Grub Rank itself.
    var variation: String? = nil
    /// Variation pages: Remove from Variation on a row (the Dish and its cooks always stay).
    var removeFromVariation: ((Dish) -> Void)? = nil
    @Environment(\.modelContext) private var context
    @Query private var attempts: [CookingAttempt]
    @Query(sort: \Dish.name) private var dishes: [Dish]
    @State private var newDish = false
    @State private var choosingDish = false
    @State private var selectedDish: Dish?
    @State private var pendingDish: Dish?
    /// Rank a Dish → "Add another cook": which Dish (nil = open the picker), applied once the sheet closes.
    @State private var existingChoice: Dish??
    @Environment(\.featureFlags) private var flags
    /// All Dishes | Folders (Folders only while the `dish_collections` gate is on).
    @State private var section = GrubRankSection.dishes
    @State private var searchText = ""
    @State private var sort = CookingBrowseSort.grubRank
    @State private var filters = CookingFilters()
    @State private var filterGroup: CookingFilterGroup?
    @State private var appliedRequest: UUID?
    @Environment(\.sgReduceMotion) private var reduceMotion
    @Environment(\.scoreUnlockState) private var scores
    @Environment(\.grubRankRequest) private var grubRankRequest
    private var eligibleDishes: [Dish] { dishes.filter { dish in dish.attempts.contains { $0.rankedItem?.list?.id == list.id } } }
    private var hasSearch: Bool { !TagNormalization.display(searchText).isEmpty }

    /// A variation page lists only that variation's Dishes; Grub Rank lists every ranked Dish.
    private func inScope(_ entry: CookingDiscovery.Entry) -> Bool {
        guard let variation else { return true }
        let key = DishCollectionPolicy.key(variation)
        return entry.attempt.dish?.collections.contains { DishCollectionPolicy.key($0) == key } == true
    }
    private var variationDishes: [Dish] {
        guard let variation else { return [] }
        let key = DishCollectionPolicy.key(variation)
        return dishes.filter { $0.collections.contains { DishCollectionPolicy.key($0) == key } }
    }

    var body: some View {
        let eligible = ScoreUnlockPolicy.entries(in: context, list: list).filter(inScope)
        let matching = CookingDiscovery.entries(in: list, attempts: attempts, query: searchText, filters: filters).filter(inScope)
        // All Dishes: one row per Dish, placed by its best-ranked cook (owner decision, Nov 18, 2026).
        let entries = CookingBrowseOrder.entries(RankingsPresentation.entries(eligible, matching: matching,
            mode: .topVersion), order: sort, scores: scores)
        // Dish positions (1, 2, 3…) from the unfiltered All Dishes order, so a Dish keeps its number while
        // filtering and a hidden second cook never leaves a gap. Ranking evidence is untouched.
        let dishRank = RankingsPresentation.dishPositions(eligible)
        ScrollView {
            if variation != nil {
                variationPage(entries: entries, eligible: eligible, dishRank: dishRank)
            } else if showsFolders {
                FolderGrid(summaries: DishCollectionSummary.all(dishes: dishes, entries: eligible, scores: scores))
                    .padding(.horizontal, SGTheme.Space.medium).padding(.vertical, SGTheme.Space.small)
                    .frame(maxWidth: SGTheme.Size.contentMaximum).frame(maxWidth: .infinity)
            } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !scores.isUnlocked { ScoreUnlockProgressBanner(state: scores) }
                if !list.items.isEmpty && (hasSearch || filters.isActive) {
                    Text("\(entries.count) of \(Set(eligible.compactMap { $0.attempt.dish?.id }).count) Dishes · Global ranks")
                        .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, SGTheme.Space.xSmall)
                        .accessibilityIdentifier("discovery-result-count")
                }
                if list.items.isEmpty {
                    GrubRankEmptyState { newDish = true }
                } else if entries.isEmpty { noResults }
                ForEach(entries) { entry in
                    NavigationLink(value: entry.attempt.id) {
                        if dishRank[entry.attempt.id] == 1 && sort == .grubRank && !hasSearch && !filters.isActive {
                            SignatureRankHero(attempt: entry.attempt)
                        } else { RankedDishRow(attempt: entry.attempt, rank: dishRank[entry.attempt.id] ?? entry.globalRank) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("cook-row-\(entry.attempt.rankedItemID)")
                    .accessibilityLabel(rowLabel(entry, rank: dishRank[entry.attempt.id] ?? entry.globalRank))
                    .accessibilityHint("Course \(entry.attempt.category.label). Ranked by its best cook. Opens dish details.")
                    Divider().overlay(SGTheme.ColorToken.border).accessibilityHidden(true)
                }
            }
            .animation(reduceMotion ? nil : SGTheme.Motion.standard, value: entries.map(\.id))
            .frame(maxWidth: SGTheme.Size.contentMaximum)
            .padding(.horizontal, SGTheme.Space.medium).padding(.bottom, SGTheme.Space.large)
            .frame(maxWidth: .infinity)
            }
        }
        .accessibilityIdentifier("ranking-scroll")
        .background(SGTheme.ColorToken.background)
        .onChange(of: scores.isUnlocked) { _, unlocked in if !unlocked && sort.needsScores { sort = .grubRank } }
        // My Kitchen statistics: show exactly what was counted (Dishes Ranked → one row per Dish,
        // Total Makes → All Cooks). Applied once per request; the All Cooks toggle shows the result.
        .task(id: grubRankRequest?.id) {
            guard let request = grubRankRequest, appliedRequest != request.id else { return }
            appliedRequest = request.id
            filters = CookingFilters(); searchText = ""; sort = .grubRank; section = .dishes
        }
        .modifier(GrubRankChrome(isVariation: variation != nil))
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: SGTheme.Space.xSmall) {
                // Grub Rank's + goes straight to Rank a Dish (no menu; Recipes are added in Food Bible).
                // A variation page keeps the navigation bar (title, back, its ⋯ menu) instead of the tab header.
                if variation == nil {
                    SGLibraryHeader(page: "Grub Rank", create: { newDish = true }, createTitle: "Rank a Dish",
                                    createIdentifier: "new-dish", identifier: "staygrubby-header-rankings")
                }
                if variation != nil, !variationDishes.isEmpty {
                    SGSearchField(placeholder: "Search this variation", text: $searchText,
                                  identifier: "ranking-search-field", clearIdentifier: "header-clear-search")
                    browseControls
                } else if variation == nil, !list.items.isEmpty {
                    SGSearchField(placeholder: "Search dishes and cooks", text: $searchText,
                                  identifier: "ranking-search-field", clearIdentifier: "header-clear-search")
                    if flags.isOn(.dishCollections) {
                        Picker("Grub Rank view", selection: $section) {
                            ForEach(GrubRankSection.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented).accessibilityIdentifier("grub-rank-sections")
                    }
                    if !showsFolders { browseControls }
                }
            }
            .padding(.horizontal, SGTheme.Space.medium).padding(.vertical, SGTheme.Space.xSmall)
            .background(SGTheme.ColorToken.background)
        }
        .safeAreaPadding(.bottom, SGTheme.Space.medium)
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $filterGroup) { CookingFilterGroupSheet(filters: $filters, group: $0) }
        .sheet(isPresented: $newDish, onDismiss: {
            // Rank a Dish → the owner chose an existing Dish: continue as another cook of it.
            guard let choice = existingChoice else { return }
            existingChoice = nil
            if let dish = choice { selectedDish = dish } else { choosingDish = true }
        }) {
            AddCookingView(list: list, chooseExisting: { dish in existingChoice = .some(dish); newDish = false })
        }
        .sheet(item: $selectedDish) { CookAgainFlow(list: list, dish: $0) }
        .sheet(isPresented: $choosingDish, onDismiss: {
            selectedDish = pendingDish; pendingDish = nil
        }) {
            DishSelectionView(dishes: eligibleDishes, onSelect: { dish in
                pendingDish = dish; choosingDish = false
            }, onCancel: { choosingDish = false })
        }
    }

    /// One variation, Grub Rank style: its average, its Dishes ranked 1, 2, 3… by each Dish's best cook (the
    /// same rows as Grub Rank), then any Dish in it that has no ranked cook yet.
    @ViewBuilder private func variationPage(entries: [CookingDiscovery.Entry], eligible: [CookingDiscovery.Entry], dishRank: [UUID: Int]) -> some View {
        let summary = variation.flatMap { label in
            DishCollectionSummary.all(dishes: variationDishes, entries: eligible, scores: scores).first { $0.id == DishCollectionPolicy.key(label) }
        }
        let ranked = Set(eligible.compactMap { $0.attempt.dish?.id })
        let unranked = variationDishes.filter { !ranked.contains($0.id) && (!hasSearch || TagNormalization.key($0.name).contains(TagNormalization.key(searchText))) }
        LazyVStack(alignment: .leading, spacing: 0) {
            if let summary {
                Text("\(summary.dishCountText) · \(summary.averageText(scores))").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, SGTheme.Space.xSmall)
                    .accessibilityIdentifier("collection-counts")
            }
            if variationDishes.isEmpty {
                SGContentState(title: "No Dishes yet", symbol: DishVariationCopy.symbol, message: "Add Dishes with \(DishVariationCopy.edit) in the ⋯ menu.")
            } else if entries.isEmpty && unranked.isEmpty { noResults }
            ForEach(entries) { entry in
                if let dish = entry.attempt.dish {
                    NavigationLink { AttemptDetailView(attempt: entry.attempt) } label: {
                        RankedDishRow(attempt: entry.attempt, rank: dishRank[entry.attempt.id] ?? entry.globalRank)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(rowLabel(entry, rank: dishRank[entry.attempt.id] ?? entry.globalRank))
                    .accessibilityHint("Ranked by its best cook. Opens dish details.")
                    .accessibilityIdentifier("collection-dish-\(dish.name)")
                    .modifier(VariationRowActions(dish: dish, remove: removeFromVariation))
                    Divider().overlay(SGTheme.ColorToken.border).accessibilityHidden(true)
                }
            }
            if !unranked.isEmpty {
                SGSectionHeader(title: "Not ranked yet").padding(.top, SGTheme.Space.medium)
                ForEach(unranked) { dish in
                    NavigationLink { DishView(dish: dish) } label: { DishPickerRow(dish: dish, accessory: .disclosure) }
                        .buttonStyle(.plain).accessibilityIdentifier("collection-dish-\(dish.name)")
                        .modifier(VariationRowActions(dish: dish, remove: removeFromVariation))
                }
            }
        }
        .animation(reduceMotion ? nil : SGTheme.Motion.standard, value: entries.map(\.id))
        .frame(maxWidth: SGTheme.Size.contentMaximum)
        .padding(.horizontal, SGTheme.Space.medium).padding(.bottom, SGTheme.Space.large)
        .frame(maxWidth: .infinity)
    }

    private func rowLabel(_ entry: CookingDiscovery.Entry, rank: Int) -> String {
        let detail = entry.attempt.rankedItem.flatMap { scores.scoreText($0.score) }.map { "score \($0)" } ?? "score locked"
        return "Rank \(rank), \(entry.attempt.displayName), \(detail)"
    }

    private var showsFolders: Bool { section == .folders && flags.isOn(.dishCollections) }
    /// Grub Rank browse controls: the shared filter rail (Course · Cuisine scroll horizontally, clear X at
    /// their end) with the circular Sort beside it. All Dishes always shows one row per Dish (Nov 18, 2026).
    private var browseControls: some View {
        SGFilterRail(clearActive: clearActive, clearTitle: hasSearch && !filters.isActive ? "Clear Search" : "Clear Search and Filters",
                     clear: { filters = CookingFilters(); searchText = "" }) {
            filterChips(CookingFilterGroup.grubRank)
        } sort: { sortMenu }
        .accessibilityElement(children: .contain).accessibilityIdentifier("filter-strip")
    }
    private func filterChips(_ groups: [CookingFilterGroup]) -> some View {
        ForEach(groups) { group in
            SGFilterChip(title: group.title, count: group.count(in: filters), summary: group.summary(in: filters, dishes: dishes),
                         identifier: "ranking-filter-\(group.rawValue)") { filterGroup = group }
        }
    }
    private var sortMenu: some View {
        SGBrowseSortMenu(options: CookingBrowseSort.allCases, selection: $sort, title: { $0.rawValue },
                         disabled: { $0.needsScores && !scores.isUnlocked },
                         active: sort != .grubRank, identifier: "ranking-sort", label: sort.rawValue, circular: true)
    }
    private var clearActive: Bool { filters.isActive || hasSearch }

    private var noResults: some View {
        ContentUnavailableView {
            Label(filters.isActive ? "No filter matches" : "No search results", systemImage: "magnifyingglass")
        } description: {
            if filters.isActive {
                Text(hasSearch ? "No ranked dishes match this search and these filters." : "No ranked dishes match these filters.")
            } else {
                Text("No dishes match ‘\(TagNormalization.display(searchText))’.")
            }
        } actions: {
            if hasSearch {
                Button("Clear Search") { searchText = "" }
                    .frame(minHeight: SGTheme.Size.minimumTap).accessibilityIdentifier("clear-search")
            }
            if filters.isActive {
                Button("Clear Filters") { filters = CookingFilters() }
                    .frame(minHeight: SGTheme.Size.minimumTap)
                    .accessibilityIdentifier("empty-clear-filters")
            }
        }
        .buttonStyle(SGButtonStyle())
    }
}

/// Grub Rank shows its own tab header (no navigation bar); a variation page keeps the navigation bar so it
/// has a title, a back button to all variations and its ⋯ menu.
private struct GrubRankChrome: ViewModifier {
    let isVariation: Bool
    func body(content: Content) -> some View {
        if isVariation { content }
        else { content.navigationTitle("Grub Rank").navigationBarTitleDisplayMode(.inline).toolbar(.hidden, for: .navigationBar) }
    }
}

/// Remove from Variation on a variation row: only the label goes; the Dish and its cooks stay.
private struct VariationRowActions: ViewModifier {
    let dish: Dish
    let remove: ((Dish) -> Void)?
    func body(content: Content) -> some View {
        if let remove {
            content
                .contextMenu {
                    Button(DishVariationCopy.removeFrom, systemImage: "minus.circle") { remove(dish) }.accessibilityIdentifier("collection-dish-remove")
                }
                .accessibilityAction(named: DishVariationCopy.removeFrom) { remove(dish) }
        } else { content }
    }
}

/// A new kitchen's Grub Rank: one clear first action (shared with the internal first-run preview).
struct GrubRankEmptyState: View {
    let rankADish: () -> Void
    var body: some View {
        ContentUnavailableView {
            Label("Your kitchen is open", systemImage: "fork.knife").accessibilityIdentifier("ranking-empty-title")
        } description: { Text("Rank the last thing you cooked. Each Dish you add finds its place in your Grub Rank.") } actions: {
            Button("Rank a Dish", action: rankADish)
                .buttonStyle(SGButtonStyle(prominent: true)).accessibilityIdentifier("ranking-empty-rank-dish")
        }
    }
}
