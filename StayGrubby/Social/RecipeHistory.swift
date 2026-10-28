import SwiftUI
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
                            Text("Version \(version.revision)\(version.revision == recipe.revision ? " · Current" : "")").font(.headline)
                            Text(version.title).font(.subheadline)
                            Text(Date(timeIntervalSince1970: version.createdAt), format: .dateTime.month().day().year()).font(.caption).foregroundStyle(.secondary)
                        }.frame(minHeight: 44)
                    }.accessibilityIdentifier("recipe-version-\(version.revision)")
                }
                if more { Button(loading ? "Loading…" : "Load Versions") { Task { await load() } }.disabled(loading) }
                if failed { Text("Couldn’t load versions. Your Recipe history is unchanged."); Button("Retry") { Task { await load() } } }
            }.navigationTitle("Version History")
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
            VStack(alignment: .leading, spacing: 24) {
                if let content {
                    RecipePhoto(id: content.photoID, name: content.title).frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 16))
                    Text(content.title).font(SGTheme.TypeRole.hero)
                    if let text = content.description { Text(text) }
                    RecipeReadingBody(content: content)
                    if version != recipe.revision { Button("Restore as New Current Version") { confirming = true }.buttonStyle(SGButtonStyle(prominent: true)).disabled(busy).accessibilityIdentifier("recipe-restore") }
                    Text("Restoring creates a new current version. Existing versions and cooked snapshots stay unchanged.").font(.footnote).foregroundStyle(.secondary)
                } else if !failed { ProgressView() }
                if failed { Text("This version is unavailable or the Recipe changed. Close history and refresh before retrying.") }
            }.padding(20)
        }.background(SGTheme.ColorToken.background).navigationTitle("Version \(version)")
            .task {
                guard let request else { failed = true; return }
                do { content = try JSONDecoder().decode(RecipeRevisionContent.self, from: await request("recipes", "revision", .init(expectedRevision: version, recipeID: recipe.id))).content } catch { failed = true }
            }
            .confirmationDialog("Restore Version \(version)?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Create New Current Version") { Task { await restore() } }
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

struct RecipeDishLinker: View {
    let recipe: Recipe
    let linked: () -> Void
    @Query(sort: \Dish.name) private var dishes: [Dish]
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var busy = false
    @State private var failed = false
    var body: some View {
        NavigationStack {
            List {
                Text("Link an existing Dish without changing either record or its cooking history. A Dish can have one linked Recipe.").font(.subheadline)
                ForEach(dishes.filter { !$0.attempts.isEmpty && CookbookSearch.matches($0.name, query: query) }) { dish in
                    Button(dish.name) { Task { await attach(dish) } }.disabled(busy).accessibilityIdentifier("recipe-link-dish-\(dish.id)")
                }
                if failed { Text("Couldn’t link. Check cooking sync; if the Dish already has a Recipe, remove that link first.") }
            }.searchable(text: $query).navigationTitle("Link to Dish")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
    private func attach(_ dish: Dish) async {
        guard let request else { return }; busy = true; defer { busy = false }
        do { _ = try await request("recipes", "attach", .init(dishID: dish.id, recipeID: recipe.id)); try Task.checkCancellation(); NotificationCenter.default.post(name: .socialContentChanged, object: nil); linked(); dismiss() } catch is CancellationError {} catch { failed = true }
    }
}
