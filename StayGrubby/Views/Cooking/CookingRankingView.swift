import SwiftUI
import SwiftData

struct CookingRankingView: View {
    let list: RankingList
    @Environment(\.modelContext) private var context
    @AppStorage(RankingsDisplayMode.preferenceKey, store: RankingsDisplayPreferences.defaults) private var displayPreference = RankingsDisplayMode.topVersion.rawValue
    @Query private var attempts: [CookingAttempt]
    @Query(sort: \Dish.name) private var dishes: [Dish]
    @State private var newDish = false
    @State private var choosingDish = false
    @State private var selectedDish: Dish?
    @State private var pendingDish: Dish?
    @State private var searchText = ""
    @State private var sort = CookingBrowseSort.grubRank
    @State private var filters = CookingFilters()
    @State private var filterGroup: CookingFilterGroup?
    @State private var searching = false
    @State private var creationExpanded = false
    @Environment(\.sgReduceMotion) private var reduceMotion
    @Environment(\.scoreUnlockState) private var scores
    private var eligibleDishes: [Dish] { dishes.filter { dish in dish.attempts.contains { $0.rankedItem?.list?.id == list.id } } }
    private var hasSearch: Bool { !TagNormalization.display(searchText).isEmpty }

    var body: some View {
        let eligible = ScoreUnlockPolicy.entries(in: context, list: list)
        let matching = CookingDiscovery.entries(in: list, attempts: attempts, query: searchText, filters: filters)
        let entries = CookingBrowseOrder.entries(RankingsPresentation.entries(eligible, matching: matching,
            mode: RankingsDisplayMode(rawValue: displayPreference) ?? .topVersion), order: sort, scores: scores)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !scores.isUnlocked { ScoreUnlockProgressBanner(state: scores) }
                if !list.items.isEmpty && (hasSearch || filters.isActive) {
                    Text("\(entries.count) of \(eligible.count) ranked cooks · Global ranks")
                        .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, SGTheme.Space.xSmall)
                        .accessibilityIdentifier("discovery-result-count")
                }
                if list.items.isEmpty {
                    ContentUnavailableView {
                        Label("No dishes yet", systemImage: "chart.bar").accessibilityIdentifier("ranking-empty-title")
                    } description: { Text("Add your first dish to begin.") } actions: {
                        Button("Add Your First Dish") { newDish = true }
                            .buttonStyle(SGButtonStyle(prominent: true))
                    }
                } else if entries.isEmpty { noResults }
                ForEach(entries) { entry in
                    NavigationLink(value: entry.attempt.id) {
                        if entry.globalRank == 1 && sort == .grubRank && !hasSearch && !filters.isActive {
                            SignatureRankHero(attempt: entry.attempt)
                        } else { RankedDishRow(attempt: entry.attempt, rank: entry.globalRank) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("cook-row-\(entry.attempt.rankedItemID)")
                    .accessibilityLabel(rowLabel(entry))
                    .accessibilityHint("Course \(entry.attempt.category.label). Global rank. Opens dish details.")
                    Divider().overlay(SGTheme.ColorToken.border).accessibilityHidden(true)
                }
            }
            .animation(reduceMotion ? nil : SGTheme.Motion.standard, value: entries.map(\.id))
            .frame(maxWidth: SGTheme.Size.contentMaximum)
            .padding(.horizontal, SGTheme.Space.medium).padding(.bottom, SGTheme.Space.large)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("ranking-scroll")
        .background(SGTheme.ColorToken.background)
        .onChange(of: scores.isUnlocked) { _, unlocked in if !unlocked && sort.needsScores { sort = .grubRank } }
        .navigationTitle("Grub Rank").navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: SGTheme.Space.xSmall) {
                StayGrubbyHeader(page: "Rankings", onCreate: {
                    withAnimation(reduceMotion ? nil : SGTheme.Motion.quick) { creationExpanded.toggle() }
                }, onSearch: list.items.isEmpty ? nil : { creationExpanded = false }, searchText: $searchText, searching: $searching)
                if creationExpanded {
                    SGCreationChoices(canCreateVersion: !eligibleDishes.isEmpty, newDish: {
                        creationExpanded = false; newDish = true
                    }, newVersion: {
                        creationExpanded = false; choosingDish = true
                    })
                    .transition(.opacity)
                }
                // An empty library has nothing to browse: no filter/sort/view controls.
                if !list.items.isEmpty { browseControls }
            }.padding(.bottom, SGTheme.Space.xSmall).background(SGTheme.ColorToken.background)
        }
        .safeAreaPadding(.bottom, SGTheme.Space.medium)
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $filterGroup) { CookingFilterGroupSheet(filters: $filters, group: $0) }
        .sheet(isPresented: $newDish) { AddCookingView(list: list) }
        .sheet(item: $selectedDish) { CookAgainFlow(list: list, dish: $0) }
        .sheet(isPresented: $choosingDish, onDismiss: {
            selectedDish = pendingDish; pendingDish = nil
        }) {
            DishSelectionView(dishes: eligibleDishes, onSelect: { dish in
                pendingDish = dish; choosingDish = false
            }, onCancel: { choosingDish = false })
        }
    }

    private func rowLabel(_ entry: CookingDiscovery.Entry) -> String {
        let detail = entry.attempt.rankedItem.flatMap { scores.scoreText($0.score) }.map { "score \($0)" } ?? "score locked"
        return "Rank \(entry.globalRank), \(entry.attempt.displayName), \(detail)"
    }

    private var displayMode: RankingsDisplayMode { RankingsDisplayMode(rawValue: displayPreference) ?? .topVersion }

    /// Grub Rank browse controls: one even row of direct filter groups, then Sort, the
    /// Show All Versions switch and a clear action shown only while filters are active.
    /// Nothing moves when filters toggle. At large text sizes each row wraps instead of clipping.
    private var browseControls: some View {
        VStack(spacing: SGTheme.Space.xSmall) {
            HStack(spacing: SGTheme.Space.xSmall) { filterChips(CookingFilterGroup.grubRank) }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: SGTheme.Space.xSmall) { sortMenu; Spacer(minLength: 0); versionsToggle; clearFilters }
                VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                    HStack(spacing: SGTheme.Space.xSmall) { sortMenu; Spacer(minLength: 0); clearFilters }
                    versionsToggle
                }
            }
        }
        .padding(.horizontal, SGTheme.Space.medium)
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
                         active: sort != .grubRank, identifier: "ranking-sort", label: sort.rawValue)
    }
    /// Presentation only: Off = one row per Dish (its top cook), On = All Cooks. The stored raw
    /// values ("Top Version" / "All Versions") are unchanged so existing preferences survive.
    private var versionsToggle: some View {
        SGBrowseToggle(title: "All Cooks", isOn: Binding(
            get: { displayMode == .allVersions },
            set: { displayPreference = ($0 ? RankingsDisplayMode.allVersions : .topVersion).rawValue }),
                       identifier: "rankings-show-all-versions", spokenTitle: "Show All Cooks of Each Dish")
    }
    /// One X clears search and filters: shown while either is active, hidden otherwise. It keeps its
    /// slot while hidden so activating a filter or typing never moves Sort or All Cooks.
    private var clearActive: Bool { filters.isActive || hasSearch }
    private var clearFilters: some View {
        SGIconButton(title: hasSearch && !filters.isActive ? "Clear Search" : "Clear Search and Filters", symbol: "xmark") {
            filters = CookingFilters(); searchText = ""
        }
            .opacity(clearActive ? 1 : 0).disabled(!clearActive)
            .accessibilityHidden(!clearActive)
            .accessibilityIdentifier(clearActive ? "clear-filters" : "clear-filters-hidden")
    }

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
