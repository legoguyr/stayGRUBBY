import SwiftUI
import SwiftData

/// One explicit action per button, avoiding competing NavigationLinks in a List row.
enum SocialPostRoute: Hashable { case post(UUID), recreate(UUID), recipe(UUID), currentRecipe(UUID) }
struct SocialPostDestination: View {
    let route: SocialPostRoute
    var body: some View {
        switch route {
        case .post(let id): SocialPostDetailView(postID: id)
        case .recreate(let id): SharedCookingEntryView(postID: id)
        case .recipe(let id): SharedRecipeView(postID: id)
        case .currentRecipe(let id): RecipeDetailView(id: id)
        }
    }
}

/// Secondary actions share one location. Only supported, authorized actions are offered.
struct SocialPostActions: View {
    let post: SocialPost
    var delete: () -> Void
    @Environment(\.socialRequest) private var request
    @Environment(\.modelContext) private var context
    @State private var sending: SocialSendContent?
    @State private var editing = false
    /// The exact cook behind the author's post (`sourceAttemptID`), when it is on this device.
    @State private var editingCook: CookingAttempt?
    @State private var sharingRecipe = false
    @State private var reporting = false
    @State private var blocking = false
    @State private var failed = false
    @State private var blocked = false
    private func openEditor() {
        if let cook = try? PublicDescriptionSync.attempt(owning: post, in: context) { editingCook = cook } else { editing = true }
    }
    var body: some View {
        Menu {
            if post.published && post.moderationState == "active" {
                SocialLinkShareAction(url: AppRoute.postURL(post.id), title: "Share Post Link")
                Button("Send to Sous Chefs", systemImage: "person.crop.circle.badge.checkmark") { sending = .post(post.id) }.accessibilityIdentifier("post-send-friend")
            }
            if post.isAuthor {
                if post.published && post.moderationState == "active" {
                    Button("Edit Description", systemImage: "pencil") { openEditor() }.accessibilityIdentifier("post-edit-\(post.id)")
                    Button("Recipe Sharing", systemImage: "book") { sharingRecipe = true }.accessibilityIdentifier("post-recipe-sharing")
                }
                Button("Delete Post", systemImage: "trash", role: .destructive, action: delete).accessibilityIdentifier("feed-delete-\(post.id)")
            } else {
                Button("Report post", systemImage: "flag") { reporting = true }.accessibilityIdentifier("social-report-post")
                Button("Block account", systemImage: "person.crop.circle.badge.xmark", role: .destructive) { blocking = true }
            }
        } label: {
            SGToolbarIcon(symbol: "ellipsis")
        }.sgUtilityTint().accessibilityLabel("Post actions for \(post.title)").accessibilityIdentifier("post-actions-\(post.id)")
            .sheet(item: $sending) { SocialSendSheet(content: $0) }
            // Cook descriptions (November 21, 2026): editing opens the cook's own Edit Cook screen; saving
            // there updates this caption through ordinary sync. Without the cook on this device (not synced
            // yet), the exact-cook caption editor below is the fallback.
            .sheet(item: $editingCook, onDismiss: { NotificationCenter.default.post(name: .socialContentChanged, object: nil) }) { EditCookingView(attempt: $0) }
            .sheet(isPresented: $editing) { SocialPostDescriptionEditor(post: post) }
            .sheet(isPresented: $sharingRecipe) { RecipePostSharingEditor(post: post) }
            .sheet(isPresented: $reporting) { SocialReportEditor(kind: "post", targetID: post.id, close: { reporting = false }) }
            .confirmationDialog("Block this account?", isPresented: $blocking, titleVisibility: .visible) {
                Button("Block account", role: .destructive) { Task { await block() } }
            } message: { Text("Their posts will no longer be available to you. Your private cooking is unchanged.") }
            .alert("Couldn’t block account", isPresented: $failed) { Button("OK", role: .cancel) {} } message: { Text("Check your connection and try again.") }
            .alert("Account blocked", isPresented: $blocked) {
                Button("OK", role: .cancel) { NotificationCenter.default.post(name: .socialContentChanged, object: nil) }
            } message: { Text("You won’t see \(post.author.displayName)’s posts, and they can’t see what you share. Unblock anytime in Settings › Blocked Accounts.") }
    }
    private func block() async {
        guard let request else { return }
        // The refresh that hides their content runs when the confirmation closes, so the card isn't
        // removed out from under the alert.
        do { _ = try await request("social_people", "block", .init(peerID: post.author.id)); blocked = true }
        catch is CancellationError {} catch { failed = true }
    }
}

/// Fallback caption editor for the author's post when its cook is not on this device yet. The server applies
/// it to exactly that cook (`social_content editDescription`); no Dish and no other post changes.
struct SocialPostDescriptionEditor: View {
    let post: SocialPost
    @Environment(\.socialRequest) private var request
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var description: String
    @State private var busy = false
    @State private var failed = false
    init(post: SocialPost) { self.post = post; _description = State(initialValue: post.postDescription ?? "") }
    var body: some View {
        NavigationStack {
            Form {
                Section("Description · optional") {
                    Text(post.title).font(SGTheme.TypeRole.headline)
                    TextField("Tell your Sous Chefs about this cook", text: $description, axis: .vertical).lineLimit(3...10)
                        .accessibilityIdentifier("post-description-input")
                    Text("This cook’s description, shown as this caption. Your other cooks keep their own. Private Notes are never shared.").font(SGTheme.TypeRole.footnote)
                }
                if failed { Text("Couldn’t save. The post or your access may have changed. Check your connection and retry.").accessibilityIdentifier("post-edit-error") }
            }.navigationTitle("Edit Description").navigationBarTitleDisplayMode(.inline).disabled(busy)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(busy || description.unicodeScalars.count > 2000).accessibilityIdentifier("post-edit-save") }
                }.interactiveDismissDisabled(busy)
        }
    }
    private func save() async {
        guard let request else { failed = true; return }; busy = true; failed = false; defer { busy = false }
        do {
            _ = try JSONDecoder().decode(SocialPostsPage.self, from: await request("social_content", "editDescription", .init(postID: post.id, postDescription: description)))
            try Task.checkCancellation(); NotificationCenter.default.post(name: .socialContentChanged, object: nil)
            dismiss()
        } catch is CancellationError {} catch { failed = true }
    }
}
