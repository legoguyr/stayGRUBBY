import SwiftUI
import SwiftData

/// Own Recipes or an explicitly authorized other Kitchen. Never a bookmark collection.
struct KitchenRecipesSection: View {
    var personID: UUID? = nil
    var expanded = false
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @Environment(\.dynamicTypeSize) private var size
    @Environment(AppLinkRouter.self) private var links
    @Query private var dishes: [Dish]
    @State private var entries: [CookbookEntry] = []
    @State private var loading = false
    @State private var failed = false
    @State private var more = false
    @State private var generation = UUID()
    @State private var selected: CookbookRoute?
    private var visible: [CookbookEntry] { expanded ? entries : Array(entries.prefix(2)) }
    var body: some View {
        if request != nil {
            VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
                if !expanded {
                    HStack {
                        Text("Recipes").font(SGTheme.TypeRole.headline).accessibilityAddTraits(.isHeader)
                        Spacer()
                        if personID == nil {
                            Button(entries.isEmpty ? "Food Bible" : "See All") { links.openFoodBible() }
                                .frame(minHeight: SGTheme.Size.minimumTap).accessibilityHint("Opens Food Bible").accessibilityIdentifier("kitchen-recipes-all")
                        } else if !entries.isEmpty {
                            NavigationLink("See All") {
                                ScrollView { KitchenRecipesSection(personID: personID, expanded: true).padding(SGTheme.Space.medium) }
                                    .background(SGTheme.ColorToken.background).navigationTitle("Recipes").navigationBarTitleDisplayMode(.inline)
                            }.frame(minHeight: SGTheme.Size.minimumTap).accessibilityIdentifier("kitchen-recipes-all")
                        }
                    }
                }
                if loading && entries.isEmpty { ProgressView("Loading Recipes") }
                if failed {
                    Text("Recipes unavailable. Try again when connected.").font(.subheadline)
                    Button("Retry Recipes") { Task { await load() } }.frame(minHeight: SGTheme.Size.minimumTap).accessibilityIdentifier("kitchen-recipes-retry")
                } else if !loading && entries.isEmpty {
                    Text(personID == nil ? "No Recipes yet" : "No shared Recipes available").foregroundStyle(.secondary)
                        .accessibilityIdentifier("kitchen-recipes-empty")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SGTheme.Space.small, alignment: .top), count: size.isAccessibilitySize ? 1 : 2), alignment: .leading, spacing: SGTheme.Space.medium) {
                    ForEach(visible) { entry in
                        Button { selected = .init(recipeID: entry.recipeID, dishID: entry.dishID) } label: {
                            CookbookCard(entry: entry, dish: personID == nil ? dishes.first { $0.id == entry.dishID } : nil)
                        }.buttonStyle(.plain).accessibilityIdentifier("kitchen-recipe-\(entry.recipeID)")
                    }
                }
                if expanded && more { Button("More Recipes") { Task { await load(nextPage: true) } }.frame(minHeight: SGTheme.Size.minimumTap).disabled(loading) }
            }.frame(maxWidth: .infinity, alignment: .leading)
                .task(id: personID) { await load() }
                .onSocialRefresh { await load() }
                .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
                .onChange(of: phase) { _, next in generation = UUID(); entries = []; more = false; if next == .active { Task { await load() } } }
                .onDisappear { generation = UUID(); if personID != nil { entries = [] } }
                .navigationDestination(item: $selected) { RecipeDetailView(id: $0.recipeID) }
        }
    }
    private func load(nextPage: Bool = false) async {
        guard let request else { return }; let token = UUID(); generation = token
        let cursor = nextPage ? entries.last?.id : nil
        if !nextPage { if personID != nil { entries = [] }; more = false }
        loading = true; failed = false; defer { if generation == token { loading = false } }
        do {
            let page = try JSONDecoder().decode(CookbookPage.self, from: await request("recipes", "profile_index", .init(peerID: personID, beforeID: cursor)))
            guard !Task.isCancelled, token == generation else { return }
            if nextPage { let seen = Set(entries.map(\.id)); entries += page.entries.filter { !seen.contains($0.id) } } else { entries = page.entries }
            more = page.entries.count == 25
        } catch is CancellationError {} catch { if token == generation { entries = []; more = false; failed = true } }
    }
}
