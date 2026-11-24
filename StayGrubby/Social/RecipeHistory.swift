import SwiftUI
import Supabase
import SwiftData

nonisolated struct RecipeVersion: Codable, Identifiable, Sendable {
    var revision: Int
    var createdAt: Double
    var title: String
    var id: Int { revision }
}
nonisolated struct RecipeHistoryPage: Codable { var versions: [RecipeVersion] }
nonisolated struct RecipeRevisionContent: Codable { var content: RecipeContent; var revision: Int }

struct RecipeHistoryView: View {
    let recipe: Recipe
    let restored: (Recipe) -> Void
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @State private var versions: [RecipeVersion] = []
    @State private var selection: RecipeVersion?
    @State private var failed = false
    @State private var loading = false
    @State private var more = true
    var body: some View {
        NavigationStack {
            List {
                ForEach(versions) { version in
                    Button { selection = version } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Revision \(version.revision)\(version.revision == recipe.revision ? " · Current" : "")").font(SGTheme.TypeRole.headline)
                            Text(version.title).font(SGTheme.TypeRole.body)
                            Text(Date(timeIntervalSince1970: version.createdAt), format: .dateTime.month().day().year()).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                        }.frame(minHeight: 44)
                    }.accessibilityIdentifier("recipe-version-\(version.revision)")
                }
                if more { Button(loading ? "Loading…" : "Load More") { Task { await load() } }.disabled(loading) }
                if failed { Text("Couldn’t load Recipe History. Your Recipe is unchanged."); Button("Retry") { Task { await load() } } }
            }.navigationTitle("Recipe History")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
                .task { await load() }
                .navigationDestination(item: $selection) { version in
                    RecipeVersionReader(recipe: recipe, version: version.revision) { next in restored(next); dismiss() }
                }
        }
    }
    private func load() async {
        guard let request, !loading else { return }; loading = true; failed = false; defer { loading = false }
        do {
            var payload = SocialPayload(); payload.recipeID = recipe.id; payload.expectedRevision = versions.last?.revision
            let page = try JSONDecoder().decode(RecipeHistoryPage.self, from: await request("recipes", "history", payload))
            try Task.checkCancellation(); let seen = Set(versions.map(\.revision)); versions += page.versions.filter { !seen.contains($0.revision) }; more = page.versions.count == 50
        } catch is CancellationError {} catch { failed = true }
    }
}
extension RecipeVersion: Hashable {}
private struct RecipeVersionReader: View {
    let recipe: Recipe
    let version: Int
    let restored: (Recipe) -> Void
    @Environment(\.socialRequest) private var request
    @State private var content: RecipeContent?
    @State private var failed = false
    @State private var busy = false
    @State private var confirming = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGTheme.Space.large) {
                if let content {
                    RecipePhoto(id: content.photoID, name: content.title).sgPhotoFrame(.hero)
                    Text(content.title).font(SGTheme.TypeRole.hero)
                    if let text = content.description { Text(text) }
                    RecipeReadingBody(content: content)
                    if version != recipe.revision { Button("Restore as Current Revision") { confirming = true }.buttonStyle(SGButtonStyle(prominent: true)).disabled(busy).accessibilityIdentifier("recipe-restore") }
                    Text("Restoring creates a new current revision. Earlier revisions and cooked snapshots stay unchanged.").font(SGTheme.TypeRole.footnote).foregroundStyle(.secondary)
                } else if !failed { ProgressView() }
                if failed { Text("This revision is unavailable or the Recipe changed. Close Recipe History and refresh before retrying.") }
            }.padding(SGTheme.Space.readingMargin)
        }.background(SGTheme.ColorToken.background).navigationTitle("Revision \(version)")
            .task {
                guard let request else { failed = true; return }
                do { content = try JSONDecoder().decode(RecipeRevisionContent.self, from: await request("recipes", "revision", .init(expectedRevision: version, recipeID: recipe.id))).content } catch { failed = true }
            }
            .confirmationDialog("Restore Revision \(version)?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Create New Current Revision") { Task { await restore() } }
            }
    }
    private func restore() async {
        guard let request else { return }; busy = true; defer { busy = false }
        do {
            var payload = SocialPayload(); payload.recipeID = recipe.id; payload.expectedRevision = recipe.revision; payload.sourceRevision = version
            let next = try JSONDecoder().decode(Recipe.self, from: await request("recipes", "restore", payload))
            try Task.checkCancellation(); NotificationCenter.default.post(name: .socialContentChanged, object: nil); restored(next)
        } catch is CancellationError {} catch { failed = true }
    }
}

/// Choose a Dish (Recipe menu, owner, Recipe without a Dish; FOOD_ARCHITECTURE §3.6): relinks an
/// unlinked Recipe through the one shared Dish picker. Only Dishes without a Recipe are offered; the
/// server (`recipes.set_dish`) still refuses a Dish that gained one meanwhile. Nothing is copied or moved.
struct RecipeDishChooser: View {
    let recipe: Recipe
    let linked: (Recipe) -> Void
    @Query(sort: \Dish.name) private var dishes: [Dish]
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @State private var taken: Set<UUID>?
    @State private var busy = false
    @State private var failure: String?
    private var available: [Dish] { dishes.filter { !(taken ?? []).contains($0.id) } }
    var body: some View {
        DishSelectionView(dishes: taken == nil ? [] : available, onSelect: { dish in Task { await link(dish) } },
                          onCancel: { dismiss() }, disabled: busy || taken == nil)
            .overlay { if taken == nil && failure == nil { SGLoadingState(label: "Loading your Dishes") } }
            .safeAreaInset(edge: .bottom) {
                if let failure {
                    Text(failure).font(SGTheme.TypeRole.footnote).padding().frame(maxWidth: .infinity)
                        .background(SGTheme.ColorToken.background).accessibilityIdentifier("recipe-choose-dish-error")
                }
            }
            .interactiveDismissDisabled(busy)
            .task { await loadTaken() }
    }
    /// Dishes that already have a Recipe (each Dish has at most one).
    private func loadTaken() async {
        guard let request else { failure = DishRecipeService.message(for: URLError(.notConnectedToInternet)); return }
        do { taken = Set(try await CookbookIndex.load(request: request).compactMap(\.dishID)); failure = nil }
        catch is CancellationError {} catch { failure = DishRecipeService.message(for: error) }
    }
    private func link(_ dish: Dish) async {
        guard let request else { return }; busy = true; defer { busy = false }
        do {
            var payload = SocialPayload(); payload.recipeID = recipe.id; payload.recipeDishID = dish.id
            let next = try JSONDecoder().decode(Recipe.self, from: await request("recipes", "set_dish", payload))
            try Task.checkCancellation()
            guard next.dishID == dish.id else { throw URLError(.cannotParseResponse) }
            NotificationCenter.default.post(name: .socialContentChanged, object: nil)
            linked(next); dismiss()
        } catch is CancellationError {} catch {
            failure = (error as? PostgrestError)?.code == "PT409" ? "\(dish.name) already has a Recipe. Choose another Dish." : DishRecipeService.message(for: error)
            await loadTaken()
        }
    }
}
