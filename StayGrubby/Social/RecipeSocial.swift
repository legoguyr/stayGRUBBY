import SwiftUI

nonisolated struct RecipeShareOption: Codable {
    var recipe: Recipe?
    var fromCookSnapshot: Bool?
    var unavailable: Bool? = nil
}
nonisolated struct SharedRecipe: Codable, Sendable {
    var postID: UUID
    var recipeID: UUID
    var revision: Int
    var content: RecipeContent
    var creator: SocialPerson?
    var cook: SocialPerson?
    var photoPath: String?
    var isAuthor: Bool
}

/// Which Recipe a post can carry, and how it is chosen (Connected Recipe sharing, November 16, 2026).
nonisolated enum RecipeAttachmentPolicy {
    /// The server's owner-authorized option wins. Older servers can require the Dish's own Recipe as a fallback.
    static func resolve(shareOption: Recipe?, dishRecipe: Recipe?) -> Recipe? {
        if let shareOption { return shareOption }
        guard let dishRecipe, dishRecipe.isOwner else { return nil }
        return dishRecipe
    }
    /// A Recipe already visible to Sous Chefs is attached by default; a private one never is.
    static func selectedByDefault(_ recipe: Recipe) -> Bool { recipe.isOwner && recipe.visibility == "friends" }
    /// Attaching a private Recipe makes the server share it with current Sous Chefs (`share_post_recipe`),
    /// so the choice must say so explicitly.
    static func changesVisibility(_ recipe: Recipe) -> Bool { recipe.visibility != "friends" }
}

/// Resolves the Recipe a post can carry. Hosts start `resolve` from their own task (the attachment
/// view renders nothing until a Recipe exists, so it cannot own the lookup).
@MainActor @Observable final class RecipeAttachmentModel {
    var recipe: Recipe?
    /// The attached Recipe (nil = post without a Recipe).
    var selection: Recipe?
    var checking = true
    var failed = false
    @ObservationIgnored private var resolved = false

    func resolve(attemptID: UUID?, postID: UUID?, dish: Dish?, request: SocialRequest?, cache: AccountContentCache?) async {
        guard let request else { checking = false; return }
        checking = true; failed = false
        defer { checking = false }
        do {
            let option = try JSONDecoder().decode(RecipeShareOption.self, from: await request("recipes", "share_options", .init(postID: postID, attemptID: attemptID)))
            var dishRecipe: Recipe?
            if option.recipe == nil, option.unavailable != true, let dish {
                if let cached = cache?.dishRecipe(dish.id), cached.isFresh() { dishRecipe = cached.value ?? nil }
                else {
                    var payload = SocialPayload(); payload.dishID = dish.id
                    dishRecipe = try JSONDecoder().decode(DishRecipeResponse.self, from: await request("recipes", "dish", payload)).recipe
                    cache?.storeDishRecipe(dishRecipe, for: dish.id)
                }
            }
            try Task.checkCancellation()
            let next = RecipeAttachmentPolicy.resolve(shareOption: option.recipe, dishRecipe: dishRecipe)
            recipe = next
            if !resolved { selection = next.flatMap { RecipeAttachmentPolicy.selectedByDefault($0) ? $0 : nil }; resolved = true }
        } catch is CancellationError {} catch { failed = true; recipe = nil; selection = nil }
    }
}

/// The composer's Recipe attachment. Shown only when the cook or its Dish has the poster's own Recipe:
/// title, a one-line preview and one explicit control. A Recipe already shared with Sous Chefs starts
/// included; a private Recipe starts excluded and its control says it will be shared.
struct RecipeShareChoice: View {
    @Bindable var model: RecipeAttachmentModel
    var retry: () -> Void = {}
    var body: some View {
        if let recipe = model.recipe {
            Section {
                NavigationLink {
                    ScrollView { VStack(alignment: .leading, spacing: SGTheme.Space.group) {
                        Text(recipe.content.title).font(SGTheme.TypeRole.title)
                        if let description = recipe.content.description { Text(description) }
                        RecipeReadingBody(content: recipe.content)
                    }.padding(SGTheme.Space.readingMargin) }.navigationTitle("Recipe")
                } label: {
                    VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                        Label(recipe.content.title, systemImage: "book.closed").font(SGTheme.TypeRole.headline)
                        if let summary = DishRecipePreview.summary(recipe, dishName: nil) {
                            Text(summary).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                        }
                    }
                }.accessibilityIdentifier("post-recipe-preview")
                Toggle(RecipeAttachmentPolicy.changesVisibility(recipe) ? "Share Recipe with Sous Chefs" : "Include Recipe",
                       isOn: Binding(get: { model.selection != nil }, set: { model.selection = $0 ? recipe : nil }))
                    .accessibilityIdentifier("post-include-recipe")
            } header: { Text("Recipe") } footer: {
                if RecipeAttachmentPolicy.changesVisibility(recipe) {
                    Text("This Recipe is private. Including it shares it with your current Sous Chefs; you can turn Recipe sharing off later in Edit Recipe.")
                        .accessibilityIdentifier("post-recipe-private-note")
                } else if model.selection != nil {
                    Text("This Recipe stays linked and may update when you edit it.").accessibilityIdentifier("post-recipe-linked-note")
                }
            }
        } else if model.failed {
            Section("Recipe") {
                Button("Couldn’t check for a Recipe · Retry", action: retry).font(.footnote).accessibilityIdentifier("post-recipe-retry")
            }
        }
        // No Recipe: no section at all.
    }
}

struct RecipePostSharingEditor: View {
    let post: SocialPost
    /// The cook's Dish when known (the composer), so the Dish's own Recipe can be attached later.
    var dish: Dish? = nil
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @State private var attachment = RecipeAttachmentModel()
    @State private var busy = false
    @State private var failed = false
    @State private var confirmingRemoval = false
    @Environment(\.accountContentCache) private var cache
    var body: some View {
        NavigationStack {
            Form {
                if post.recipeAttachmentPresent == true || post.recipeID != nil {
                    Section {
                        Text("This post links your Recipe. Sous Chefs see its latest version while it stays shared; the revision you posted is kept for attribution.")
                        if let recipeID = post.recipeID { NavigationLink("View Recipe") { RecipeDetailView(id: recipeID) } }
                        else { Text("Recipe access is currently off. You can still remove this saved attachment.") }
                        Button("Remove Recipe from Post", role: .destructive) { confirmingRemoval = true }.accessibilityIdentifier("post-unshare-recipe")
                        Text("The post stays available. This removes its Recipe reader. Turn Recipe sharing off in Edit Recipe to revoke every Sous Chef’s Recipe access.").font(.footnote)
                    }
                } else {
                    RecipeShareChoice(model: attachment) { Task { await resolve() } }
                    if attachment.checking { ProgressView("Checking for a Recipe") }
                    else if attachment.recipe == nil && !attachment.failed { Text("This Dish has no Recipe of yours to add yet.").font(.footnote) }
                    else if attachment.recipe != nil {
                        Button("Add Recipe to Post") { Task { await change(remove: false) } }.disabled(attachment.selection == nil || busy).accessibilityIdentifier("post-share-recipe")
                    }
                }
                if failed { Text("Couldn’t change Recipe sharing. Your access or the Recipe may have changed. Refresh and try again.") }
            }.navigationTitle("Recipe Sharing").disabled(busy)
                .task { await resolve() }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Remove this Recipe attachment?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
                    Button("Remove Recipe from Post", role: .destructive) { Task { await change(remove: true) } }
                }.interactiveDismissDisabled(busy)
        }
    }
    private func resolve() async {
        await attachment.resolve(attemptID: nil, postID: post.id, dish: dish, request: request, cache: cache)
    }
    private func change(remove: Bool) async {
        guard let request else { return }; busy = true; failed = false; defer { busy = false }
        do {
            _ = try await request("recipes", remove ? "unshare_post" : "share_post", .init(postID: post.id, confirmed: true, recipeID: attachment.selection?.id, sourceRevision: attachment.selection?.revision))
            try Task.checkCancellation(); NotificationCenter.default.post(name: .socialContentChanged, object: nil); dismiss()
        } catch is CancellationError {} catch { failed = true }
    }
}

/// Authorized pinned reading, never owner editing/history or local private-Dish fallback.
struct SharedRecipeView: View {
    let postID: UUID
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @State private var value: SharedRecipe?
    @State private var reportTarget: RecipeReportTarget?
    @State private var failed = false
    @State private var busy = false
    @State private var generation = UUID()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGTheme.Space.large) {
                if let value {
                    if let photoID = value.content.photoID {
                        RecipePhoto(id: photoID, name: value.content.title).sgPhotoFrame(.hero)
                    } else { SocialPhoto(path: value.photoPath).sgPhotoFrame(.hero) }
                    Text(value.content.title).font(SGTheme.TypeRole.hero).accessibilityIdentifier("shared-recipe-title")
                    if let description = value.content.description { Text(description).accessibilityIdentifier("shared-recipe-description") }
                    if let creator = value.creator { Text("Recipe shared by \(creator.displayName)").font(.subheadline) }
                    if let cook = value.cook { Text("Cooked by \(cook.displayName)").font(.subheadline) }
                    Text("Shared revision \(value.revision). The current Recipe may have changed.").font(.footnote).foregroundStyle(.secondary)
                    // Connected UI: no in-app copies of another creator's Recipe. Open the current Recipe
                    // (live access check) to save a reference or Rank My Version there.
                    NavigationLink { RecipeDetailView(id: value.recipeID) } label: {
                        Label("Open Recipe to Save", systemImage: "bookmark").frame(maxWidth: .infinity)
                    }.buttonStyle(SGButtonStyle()).disabled(busy).accessibilityIdentifier("shared-recipe-open-current")
                    RecipeReadingBody(content: value.content, allowScaling: true)
                    if let source = value.content.source { Text("Source · \(source)") }
                    if let creator = value.content.originalCreator { Text("Original creator · \(creator)") }
                    Text("This link opens this post’s shared revision for Sous Chefs who still have access.").font(.footnote).foregroundStyle(.secondary)

                } else if !failed { ProgressView("Loading shared Recipe") }
                if failed { Text("Recipe unavailable or sharing has changed. Your saved cooking is unchanged.").accessibilityIdentifier("shared-recipe-unavailable"); Button("Retry") { Task { await load() } } }
            }.padding(SGTheme.Space.medium).frame(maxWidth: SGTheme.Size.contentMaximum).frame(maxWidth: .infinity)
        }.background(SGTheme.ColorToken.background).navigationTitle("Shared Recipe").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let value {
                    RecipeToolbarActions(url: AppRoute.sharedRecipeURL(postID: postID), sendContent: .recipe(value.recipeID), sendTitle: "Send Current Recipe to Sous Chefs", disabled: busy) {
                            NavigationLink { RecipeDetailView(id: value.recipeID) } label: { Label("Current Recipe", systemImage: "book.closed") }
                            if !value.isAuthor {
                                Button("Report Recipe", systemImage: "flag") {
                                    reportTarget = .init(id: value.recipeID, postID: value.postID, revision: value.revision)
                                }.accessibilityIdentifier("social-report-recipe")
                            }
                        }

                }
            }
            .recipeReportSheet($reportTarget, reload: load)
            .task(id: postID) { await load() }.refreshable { await load() }
            .onSocialRefresh { if !busy { await load() } }
            .onChange(of: phase) { _, next in generation = UUID(); value = nil; if next == .active { Task { await load() } } }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
            .onDisappear { generation = UUID(); value = nil }
    }
    private func load() async {
        guard let request else { failed = true; return }; let token = UUID(); generation = token; failed = false
        do {
            let next = try JSONDecoder().decode(SharedRecipe.self, from: await request("recipes", "shared_post", .init(postID: postID)))
            guard !Task.isCancelled, token == generation else { return }; value = next
        } catch is CancellationError {} catch { if token == generation { value = nil; failed = true } }
    }
}

nonisolated struct RecipeForkProvenance: Codable {
    var sourceRecipeID: UUID?
    var sourceRevision: Int
    var creator: SocialPerson?
    var postID: UUID?
}
nonisolated struct RecipeForkProvenancePage: Codable { var provenance: RecipeForkProvenance? }
struct RecipeForkAttribution: View {
    let recipeID: UUID
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @State private var provenance: RecipeForkProvenance?
    var body: some View {
        Group {
            if let provenance {
                Text(provenance.creator.map { "Private copy from \($0.displayName) · source revision \(provenance.sourceRevision)" } ?? "Independent private copy · source revision \(provenance.sourceRevision)").font(.footnote).foregroundStyle(.secondary)
            }
        }.task(id: recipeID) { await load() }
            .onChange(of: phase) { _, next in provenance = nil; if next == .active { Task { await load() } } }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
    }
    private func load() async {
        guard let request else { return }
        do { let next = try JSONDecoder().decode(RecipeForkProvenancePage.self, from: await request("recipes", "fork_provenance", .init(recipeID: recipeID))); try Task.checkCancellation(); provenance = next.provenance }
        catch { provenance = nil }
    }
}
