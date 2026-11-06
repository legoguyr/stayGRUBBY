import SwiftUI

nonisolated struct RecipeShareOption: Codable {
    var recipe: Recipe?
    var fromCookSnapshot: Bool?
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

/// Deliberate, OFF-by-default attachment. Neither a Dish link nor auto-posting opts in.
struct RecipeShareChoice: View {
    var attemptID: UUID? = nil
    var postID: UUID? = nil
    @Binding var selection: Recipe?
    @Environment(\.socialRequest) private var request
    @State private var option: RecipeShareOption?
    @State private var failed = false
    @State private var loading = true
    @State private var retry = 0
    var body: some View {
        Section("Recipe · optional") {
            if let recipe = option?.recipe {
                Toggle("Include Recipe", isOn: Binding(get: { selection != nil }, set: { selection = $0 ? recipe : nil })).accessibilityIdentifier("post-include-recipe")
                NavigationLink {
                    ScrollView { VStack(alignment: .leading, spacing: 20) {
                        Text(recipe.content.title).font(SGTheme.TypeRole.title)
                        if let description = recipe.content.description { Text(description) }
                        RecipeReadingBody(content: recipe.content)
                    }.padding(20) }.navigationTitle("Recipe to Share")
                } label: { Text("\(recipe.content.title) · revision \(recipe.revision)") }
                Text(option?.fromCookSnapshot == true ? "This is the Recipe snapshot associated with this cook." : "This is the currently linked Recipe. The link does not establish which Recipe was used for this cook.").font(.footnote)
                Text("Including it shares this revision and its Recipe photo with current Sous Chefs. The Recipe becomes friends-visible. Later edits won’t rewrite this attachment. Personal Notes and private cooking photos are never included.").font(.footnote).foregroundStyle(.secondary)
            } else if loading { ProgressView("Checking Recipe availability") }
            else if failed { Text("Recipe unavailable. You can still publish without it."); Button("Retry Recipe") { retry += 1 } }
            else { Text("No owned Recipe is associated with this cook. You can share the post without one, or link your Recipe to this cook first.").font(.footnote) }
        }.task(id: retry) {
            guard let request else { loading = false; return }; loading = true
            do {
                let next = try JSONDecoder().decode(RecipeShareOption.self, from: await request("recipes", "share_options", .init(postID: postID, attemptID: attemptID)))
                try Task.checkCancellation(); option = next; failed = false
            } catch is CancellationError {} catch { failed = true; option = nil; selection = nil }
            loading = false
        }
    }
}

struct RecipePostSharingEditor: View {
    let post: SocialPost
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Recipe?
    @State private var busy = false
    @State private var failed = false
    @State private var confirmingRemoval = false
    var body: some View {
        NavigationStack {
            Form {
                if post.recipeAttachmentPresent == true || post.recipeID != nil {
                    Section {
                        Text("This post has an intentionally shared Recipe revision. Editing the current Recipe does not change it.")
                        if post.recipeID != nil { NavigationLink("Read Shared Recipe") { SharedRecipeView(postID: post.id) } }
                        else { Text("Recipe access is currently off. You can still remove this saved attachment.") }
                        Button("Remove Recipe from Post", role: .destructive) { confirmingRemoval = true }.accessibilityIdentifier("post-unshare-recipe")
                        Text("The post stays available. This removes its Recipe reader. Turn Recipe sharing off in Edit Recipe to revoke all friends’ Recipe access.").font(.footnote)
                    }
                } else {
                    RecipeShareChoice(postID: post.id, selection: $selection)
                    Button("Share Selected Recipe") { Task { await change(remove: false) } }.disabled(selection == nil || busy).accessibilityIdentifier("post-share-recipe")
                }
                if failed { Text("Couldn’t change Recipe sharing. Your access or the Recipe may have changed. Refresh and try again.") }
            }.navigationTitle("Recipe Sharing").disabled(busy)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Remove this Recipe attachment?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
                    Button("Remove Recipe from Post", role: .destructive) { Task { await change(remove: true) } }
                }.interactiveDismissDisabled(busy)
        }
    }
    private func change(remove: Bool) async {
        guard let request else { return }; busy = true; failed = false; defer { busy = false }
        do {
            _ = try await request("recipes", remove ? "unshare_post" : "share_post", .init(postID: post.id, confirmed: true, recipeID: selection?.id, sourceRevision: selection?.revision))
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
    @State private var failed = false
    @State private var busy = false
    @State private var generation = UUID()
    @State private var copyID = UUID()
    @State private var copiedID: UUID?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let value {
                    if let photoID = value.content.photoID {
                        RecipePhoto(id: photoID, name: value.content.title).frame(height: 240).clipped()
                    } else { SocialPhoto(path: value.photoPath).frame(height: 240).clipped() }
                    Text(value.content.title).font(SGTheme.TypeRole.hero).accessibilityIdentifier("shared-recipe-title")
                    if let description = value.content.description { Text(description).accessibilityIdentifier("shared-recipe-description") }
                    if let creator = value.creator { Text("Recipe shared by \(creator.displayName)").font(.subheadline) }
                    if let cook = value.cook { Text("Cooked by \(cook.displayName)").font(.subheadline) }
                    Text("Shared revision \(value.revision). The current Recipe may have changed.").font(.footnote).foregroundStyle(.secondary)
                    Button("Save a Private Copy") { Task { await fork() } }.buttonStyle(SGButtonStyle()).disabled(busy).accessibilityIdentifier("shared-recipe-fork")
                    Text("A copy is yours to edit independently. The original stays with its creator. Private copies and completed cook snapshots remain yours if sharing later stops. Add your own photo to a copy.").font(.footnote).foregroundStyle(.secondary)
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
                    RecipeToolbarActions(url: AppRoute.sharedRecipeURL(postID: postID), sendContent: .recipe(value.recipeID), sendTitle: "Send Current Recipe to Sous Chef", disabled: busy) {
                            NavigationLink { RecipeDetailView(id: value.recipeID) } label: { Label("Current Recipe", systemImage: "book.closed") }
                        }

                }
            }
            .task(id: postID) { await load() }.refreshable { await load() }
            .onSocialRefresh { if !busy { await load() } }
            .navigationDestination(item: $copiedID) { RecipeDetailView(id: $0) }
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
    private func fork() async {
        guard let request else { return }; busy = true; defer { busy = false }
        do {
            let next = try JSONDecoder().decode(Recipe.self, from: await request("recipes", "fork_post", .init(targetID: copyID, postID: postID, confirmed: true)))
            try Task.checkCancellation(); copiedID = next.id; NotificationCenter.default.post(name: .socialContentChanged, object: nil)
        } catch is CancellationError {} catch { value = nil; failed = true }
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
