import SwiftUI

/// Recipe Unlink and Recently Deleted (November 20, 2026; FOOD_ARCHITECTURE §3.6). Server-authoritative
/// (`api.recipe_library`): nothing here is stored or synced on the device, so a device can neither
/// resurrect a deleted Recipe nor erase a restored one. Gated by `FeatureFlag.recipeRecovery` until the
/// backend migration is deployed.
@MainActor enum RecipeLibraryService {
    nonisolated struct DeletedRecipe: Codable, Identifiable, Sendable {
        var id: UUID
        var title: String
        var photoID: String?
        var deletedAt: Double
        var expiresAt: Double
        var dishID: UUID?
        var dishName: String?
        var daysLeft: Int { max(0, Int(ceil((expiresAt - Date.now.timeIntervalSince1970) / 86_400))) }
    }
    nonisolated struct Restored: Codable { var recipe: Recipe?; var dishReattached: Bool? }
    private nonisolated struct Deleted: Codable { var recipes: [DeletedRecipe] }

    /// Removes only the Dish association; the Recipe stays in Food Bible with its history and photos.
    static func unlink(_ recipe: Recipe, request: SocialRequest) async throws -> Recipe? {
        var payload = SocialPayload(); payload.recipeID = recipe.id; payload.dishID = recipe.dishID
        return try JSONDecoder().decode(DishRecipeResponse.self, from: await request("recipe_library", "unlink_dish", payload)).recipe
    }
    static func deleted(request: SocialRequest) async throws -> [DeletedRecipe] {
        try JSONDecoder().decode(Deleted.self, from: await request("recipe_library", "deleted", SocialPayload())).recipes
    }
    static func restore(_ id: UUID, request: SocialRequest) async throws -> Restored {
        var payload = SocialPayload(); payload.recipeID = id
        return try JSONDecoder().decode(Restored.self, from: await request("recipe_library", "restore", payload))
    }
    static func purge(_ id: UUID, request: SocialRequest) async throws {
        var payload = SocialPayload(); payload.recipeID = id
        _ = try await request("recipe_library", "purge", payload)
    }
}

/// Food Bible → Recently Deleted: Recipes deleted in the last 30 days. Restore brings back the same
/// Recipe with its history; Delete Permanently is separate and confirmed.
struct RecentlyDeletedRecipesView: View {
    @Environment(\.socialRequest) private var request
    @State private var items: [RecipeLibraryService.DeletedRecipe] = []
    @State private var loading = true
    @State private var failed = false
    @State private var busy: UUID?
    @State private var purging: RecipeLibraryService.DeletedRecipe?
    @State private var notice: String?

    var body: some View {
        List {
            Section {
                ForEach(items) { item in row(item) }
            } footer: {
                if !items.isEmpty { Text("Recipes stay here for 30 days, then are deleted permanently. Restoring brings back the Recipe and its Recipe History.") }
            }
        }
        .overlay {
            if loading && items.isEmpty { SGLoadingState(label: "Opening Recently Deleted") }
            else if failed && items.isEmpty {
                SGContentState(title: "Couldn’t load", symbol: "wifi.exclamationmark", message: "Recently Deleted needs a connection.") {
                    Button("Retry") { Task { await load() } }.buttonStyle(SGButtonStyle())
                }
            } else if items.isEmpty {
                SGContentState(title: "No recently deleted Recipes", symbol: "trash", message: "Deleted Recipes stay here for 30 days.") { EmptyView() }
                    .accessibilityIdentifier("recently-deleted-empty")
            }
        }
        .scrollContentBackground(.hidden).background(SGTheme.ColorToken.background)
        .navigationTitle("Recently Deleted").navigationBarTitleDisplayMode(.inline)
        .task { await load() }.refreshable { await load() }
        .confirmationDialog("Delete “\(purging?.title ?? "")” permanently?", isPresented: Binding(get: { purging != nil }, set: { if !$0 { purging = nil } }), titleVisibility: .visible) {
            Button("Delete Permanently", role: .destructive) { if let item = purging { Task { await purge(item) } } }
                .accessibilityIdentifier("recently-deleted-confirm-purge")
        } message: { Text("The Recipe and its Recipe History can’t be recovered after this. Your Dishes, cooks and rankings stay.") }
        .alert("Recently Deleted", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) { Button("OK") { notice = nil } } message: { Text(notice ?? "") }
    }

    private func row(_ item: RecipeLibraryService.DeletedRecipe) -> some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            Text(item.title).font(SGTheme.TypeRole.headline)
            Text([item.dishName.map { "From \($0)" }, item.daysLeft == 1 ? "1 day left" : "\(item.daysLeft) days left"].compactMap { $0 }.joined(separator: " · "))
                .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            HStack(spacing: SGTheme.Space.small) {
                Button("Restore", systemImage: "arrow.uturn.backward") { Task { await restore(item) } }
                    .buttonStyle(SGButtonStyle(prominent: true, compact: true)).accessibilityIdentifier("recently-deleted-restore-\(item.title)")
                Button("Delete Permanently", role: .destructive) { purging = item }
                    .buttonStyle(SGButtonStyle(compact: true)).accessibilityIdentifier("recently-deleted-purge-\(item.title)")
            }.disabled(busy != nil).padding(.top, SGTheme.Space.xSmall)
        }
        .padding(.vertical, SGTheme.Space.xSmall)
        .accessibilityElement(children: .contain).accessibilityIdentifier("recently-deleted-\(item.title)")
    }

    private func load() async {
        guard let request else { failed = true; loading = false; return }
        do { items = try await RecipeLibraryService.deleted(request: request); failed = false } catch is CancellationError {} catch { failed = true }
        loading = false
    }
    private func restore(_ item: RecipeLibraryService.DeletedRecipe) async {
        guard let request else { return }; busy = item.id; defer { busy = nil }
        do {
            let result = try await RecipeLibraryService.restore(item.id, request: request)
            items.removeAll { $0.id == item.id }
            NotificationCenter.default.post(name: .socialContentChanged, object: nil)
            if result.dishReattached == false, let dish = item.dishName {
                notice = "“\(item.title)” is back in Food Bible. \(dish) already has another Recipe, so it isn’t linked to it."
            } else {
                notice = "“\(item.title)” is back in Food Bible."
            }
        } catch { notice = "Couldn’t restore. Try again." }
    }
    private func purge(_ item: RecipeLibraryService.DeletedRecipe) async {
        guard let request else { return }; busy = item.id; defer { busy = nil; purging = nil }
        do { try await RecipeLibraryService.purge(item.id, request: request); items.removeAll { $0.id == item.id } }
        catch { notice = "Couldn’t delete. Try again." }
    }
}
