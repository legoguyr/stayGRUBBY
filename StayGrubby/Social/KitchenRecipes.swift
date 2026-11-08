import SwiftUI
import SwiftData

/// Own Recipes or an explicitly authorized other Kitchen. Never a bookmark collection.
struct KitchenRecipesSection: View {
    var personID: UUID? = nil
    @Environment(\.socialRequest) private var request
    @State private var showingRecipes = false
    var body: some View {
        if request != nil {
            if let personID {
                // A social Kitchen already has native sheet navigation. Keep one modal host.
                // The visitor Kitchen is a List, whose NavigationLink draws the disclosure chevron.
                NavigationLink { KitchenRecipeCollection(personID: personID) } label: { control(chevron: false) }
                    .buttonStyle(.plain).accessibilityIdentifier("kitchen-recipes-open")
            } else {
                Button { showingRecipes = true } label: { control(chevron: true) }
                    .buttonStyle(.plain).accessibilityIdentifier("kitchen-recipes-open")
                    .sheet(isPresented: $showingRecipes) {
                        NavigationStack {
                            KitchenRecipeCollection(personID: nil)
                                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingRecipes = false } } }
                        }
                    }
            }
        }
    }
    private func control(chevron: Bool) -> some View {
        HStack {
            Label("Recipes", systemImage: "book.closed"); Spacer()
            if chevron { Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary).accessibilityHidden(true) }
        }
            .frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
    }
}

/// Reuses Food Bible's cards and reader; profile_index supplies the owner/authorized collection.
private struct KitchenRecipeCollection: View {
    let personID: UUID?
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @Environment(\.dynamicTypeSize) private var size
    @Query private var dishes: [Dish]
    @State private var entries: [CookbookEntry] = []
    @State private var loading = false
    @State private var failed = false
    @State private var query = ""
    private var visible: [CookbookEntry] { entries.filter { CookbookSearch.matches($0.searchableText, query: query) } }
    @State private var generation = UUID()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
                if loading && entries.isEmpty { ProgressView("Loading Recipes") }
                if failed {
                    Text("Recipes unavailable. Try again when connected.").font(.subheadline)
                    Button("Retry Recipes") { Task { await load() } }.frame(minHeight: SGTheme.Size.minimumTap).accessibilityIdentifier("kitchen-recipes-retry")
                } else if !loading && entries.isEmpty {
                    Text(personID == nil ? "No Recipes yet" : "No shared Recipes available").foregroundStyle(.secondary)
                        .accessibilityIdentifier("kitchen-recipes-empty")
                }
                if !loading && !failed && !entries.isEmpty && visible.isEmpty {
                    ContentUnavailableView.search(text: query).accessibilityIdentifier("kitchen-recipes-no-results")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SGTheme.Space.small, alignment: .top), count: size.isAccessibilitySize ? 1 : 2), alignment: .leading, spacing: SGTheme.Space.medium) {
                    ForEach(visible) { entry in
                        NavigationLink { RecipeDetailView(id: entry.recipeID) } label: {
                            CookbookCard(entry: entry, dish: personID == nil ? dishes.first { $0.id == entry.dishID } : nil)
                        }.buttonStyle(.plain).accessibilityIdentifier("kitchen-recipe-\(entry.recipeID)")
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
                .task(id: personID) { await load() }
                .onSocialRefresh { await load() }
                .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
                .onChange(of: phase) { _, next in  generation = UUID(); entries = []; if next == .active { Task { await load() } } }
                // Pushing a reader must retain its source collection. Dismissal destroys the sheet;
                // scene/account/access refreshes still clear or reauthorize foreign summaries.
                .onDisappear { generation = UUID() }
                .padding(SGTheme.Space.medium)
        }
        .safeAreaInset(edge: .top) {
            SGSearchField(placeholder: "Search Recipes", text: $query, identifier: "kitchen-recipes-search")
                .padding(.horizontal, SGTheme.Space.medium).padding(.vertical, SGTheme.Space.small).background(SGTheme.ColorToken.background)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(SGTheme.ColorToken.background).navigationTitle("Recipes").navigationBarTitleDisplayMode(.inline)
    }
    private func load() async {
        guard let request else { return }; let token = UUID(); generation = token
        if personID != nil { entries = [] }
        loading = true; failed = false; defer { if generation == token { loading = false } }
        do {
            let next = try await CookbookIndex.profile(request: request, personID: personID)
            guard !Task.isCancelled, token == generation else { return }
            entries = next
        } catch is CancellationError {} catch { if token == generation { entries = []; failed = true } }
    }
}

/// Shared Kitchen sections use the same authorized sources for owner and visitor.
struct KitchenSharedContent<Between: View>: View {
    var personID: UUID? = nil
    let open: (UUID) -> Void
    @ViewBuilder let between: () -> Between

    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.large) {
            KitchenRecipesSection(personID: personID).id("recipes:\(personID?.uuidString ?? "own")")
            between()
            SocialProfilePosts(open: open, personID: personID).id("posts:\(personID?.uuidString ?? "own")")
        }.frame(maxWidth: SGTheme.Size.contentMaximum, alignment: .leading)
    }
}
