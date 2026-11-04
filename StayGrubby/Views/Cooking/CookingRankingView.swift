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
        .onChange(of: scores.isUnlocked) { _, unlocked in if !unlocked && sort == .score { sort = .grubRank } }
        .navigationTitle("Grub Rank").navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: SGTheme.Space.xSmall) {
                StayGrubbyHeader(page: "Rankings", onCreate: {
                    withAnimation(reduceMotion ? nil : SGTheme.Motion.quick) { creationExpanded.toggle() }
                }, onSearch: { creationExpanded = false }, searchText: $searchText, searching: $searching)
                if creationExpanded {
                    SGCreationChoices(canCreateVersion: !eligibleDishes.isEmpty, newDish: {
                        creationExpanded = false; newDish = true
                    }, newVersion: {
                        creationExpanded = false; choosingDish = true
                    })
                    .transition(.opacity)
                }
                Picker("Ranking display", selection: $displayPreference) {
                    ForEach(RankingsDisplayMode.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }.pickerStyle(.segmented).padding(.horizontal, SGTheme.Space.medium)
                    .accessibilityIdentifier("rankings-display-mode")
                filterControls
                if !list.items.isEmpty && (hasSearch || filters.isActive) {
                    Text("\(entries.count) of \(eligible.count) ranked cooks · Global ranks")
                        .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, SGTheme.Space.medium)
                        .accessibilityIdentifier("discovery-result-count")
                }
            }.padding(.bottom, SGTheme.Space.xSmall).background(SGTheme.ColorToken.background)
        }
        .safeAreaPadding(.bottom, SGTheme.Space.medium)
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $filterGroup) { group in
            if group == .cuisine {
                CuisinePicker(selection: Binding(
                    get: { CuisineCatalog.options(saved: dishes.compactMap(\.cuisine)).first { $0.id == filters.cuisineID } },
                    set: { filters.cuisineID = $0?.id }), allowsCreation: false)
            } else { CookingFilterView(filters: $filters, group: group) }
        }
        .sheet(isPresented: $newDish) { AddCookingView(list: list) }
        .sheet(item: $selectedDish) { AddCookingView(list: list, dish: $0) }
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

    private var filterControls: some View {
        HStack(spacing: SGTheme.Space.xSmall) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SGTheme.Space.xSmall) {
                    filterButton(.course, detail: filters.category?.label, count: filters.category == nil ? 0 : 1)
                    filterButton(.cuisine, detail: dishes.compactMap(\.cuisine).first { $0.id == filters.cuisineID }?.label, count: filters.cuisineID == nil ? 0 : 1)
                    filterButton(.dietary, count: filters.dietary.count)
                    filterButton(.avoid, count: filters.avoidedAllergens.count)
                }
            }.accessibilityIdentifier("filter-strip")
            Menu {
                ForEach(CookingBrowseSort.allCases) { option in
                    Button {
                        sort = option
                    } label: {
                        if option == sort { Label(option.rawValue, systemImage: "checkmark") }
                        else { Text(option.rawValue) }
                    }.disabled(option == .score && !scores.isUnlocked).accessibilityIdentifier("ranking-sort-\(option.id)")
                }
            } label: { SGBrowseControlLabel(title: "Sort", symbol: "arrow.up.arrow.down", active: sort != .grubRank) }
                .accessibilityLabel("Sort, \(sort.rawValue)").accessibilityIdentifier("ranking-sort")
            if filters.isActive {
                SGIconButton(title: "Clear Filters", symbol: "xmark") { filters = CookingFilters() }
                    .accessibilityIdentifier("clear-filters")
            }
        }.padding(.horizontal, SGTheme.Space.medium)
    }

    private func filterButton(_ group: CookingFilterGroup, detail: String? = nil, count: Int) -> some View {
        Button { filterGroup = group } label: {
            SGBrowseControlLabel(title: detail ?? (count > 0 ? "\(group.title) \(count)" : group.title), symbol: "chevron.down", active: count > 0)
        }
        .buttonStyle(.plain).accessibilityIdentifier("ranking-filter-\(group.rawValue)")
        .accessibilityLabel("\(group.title), \(count) active selections")
        .accessibilityHint("Choose or remove \(group.title.lowercased()) filters")
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
