import SwiftUI
import SwiftData
import Supabase

struct SocialShareAction: View {
    let attempt: CookingAttempt
    @Environment(\.socialRequest) private var request
    @State private var showing = false
    var body: some View {
        if request != nil {
            Button { showing = true } label: { Label("Post to The Pass", systemImage: "person.2").frame(maxWidth: .infinity) }
                .buttonStyle(SGButtonStyle()).accessibilityIdentifier("share-with-friends")
                .accessibilityHint("Review and explicitly publish a separate friends-only cooking post.")
                .sheet(isPresented: $showing) { SocialPostComposer(attempt: attempt, close: { showing = false }) }
        }
    }
}
struct SocialPostComposer: View {
    let attempt: CookingAttempt
    let close: () -> Void
    @Environment(\.cookingMediaRoot) private var mediaRoot
    @Environment(\.socialRequest) private var request
    @Environment(\.socialMedia) private var media
    @Environment(\.socialPublication) private var publication
    @Query private var bindings: [SyncStoreBinding]
    @State private var lookupGeneration = 0
    @State private var alreadyShared = false
    @State private var checkingPost = true
    @State private var publicationError: String?
    @State private var identity: SocialIdentity?
    @State private var editingIdentity = false
    @State private var includePhoto = false
    @State private var postDescription = ""
    @State private var descriptionInitialized = false
    @State private var sharedRecipe: Recipe?
    @State private var postID = UUID()
    @State private var originalPostID: UUID?
    @State private var savedPost: SocialPost?
    @State private var busy = false
    @State private var failed = false
    @State private var attemptedShare = false
    @State private var didPublish = false
    private var model: ShareCardModel { .make(for: attempt) }
    private var preservedExistingDescription: Bool {
        didPublish && (savedPost?.postDescription ?? "") != postDescription.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n\r"))
    }
    private var preservedExistingRecipe: Bool {
        guard didPublish, let sharedRecipe else { return false }
        return savedPost?.recipeID != sharedRecipe.id || savedPost?.recipeRevision != sharedRecipe.revision
    }
    private var revision: Int? {
        CookPublicationReadiness.revision(for: attempt, binding: bindings.first)
    }
    private var cookAccepted: Bool {
        CookPublicationReadiness.revision(for: attempt, binding: bindings.first, requireCurrent: false) != nil
    }
    private var photo: Data? {
        attempt.primaryImage.flatMap { LocalPhotoStore.data(for: $0, thumbnail: false, rootURL: mediaRoot) }
    }
    private var lookup: String {
        "\(attempt.id):\(cookAccepted):\(lookupGeneration):\(publication?.status(attempt.rankedItemID) == .shared)"
    }
    var body: some View {
        NavigationStack {
            SGEditorialList {
                if didPublish {
                    Section {
                        Label(alreadyShared ? "Already on The Pass" : "Posted to The Pass", systemImage: "checkmark.circle.fill").accessibilityIdentifier("social-share-success")
                        Text("Your separate cooking post is available to eligible friends. Your private cooking and ranking are unchanged.")
                        if preservedExistingDescription {
                            Text("This cook was already shared. Its description was kept. To change it, use Edit Post in the post’s menu in My Kitchen.").accessibilityIdentifier("social-existing-description-preserved")
                        }
                        if preservedExistingRecipe {
                            Text("This cook was already shared. Its Recipe attachment was kept. Use Recipe Sharing in the post’s menu to change it.").accessibilityIdentifier("social-existing-recipe-preserved")
                        }
                        if let savedPost {
                            NavigationLink("View Post") { SocialPostDestination(route: .post(savedPost.id)) }
                            SocialLinkShareAction(url: AppRoute.postURL(savedPost.id), title: "Share Post Link")
                        }
                        Button("Done", action: close).accessibilityIdentifier("social-share-done")
                    }
                } else {
                Section("Post to The Pass") {
                    Text("Your cooking stays private unless you publish here. This creates a separate post for your current eligible friends.")
                    Text(model.title).font(SGTheme.TypeRole.headline)
                    if let version = model.versionSubtitle { Text(version).foregroundStyle(.secondary) }
                    if let score = model.scoreText { SGScore(text: score, role: .outOfTen) }
                    else { Text("Your score is locked and will not be shared.").accessibilityIdentifier("social-share-score-locked") }
                    if attempt.primaryImage != nil { Toggle("Include this food photo", isOn: $includePhoto).accessibilityIdentifier("social-share-photo") }
                    Text("Includes Course, Cuisine and public cookbook/restaurant/online attribution. Private notes, tags, allergens, Friend/Family details, and comparison history are not shared. Unlocked rankings may include the position and total at sharing. Cooking-derived snapshot details stay fixed. Post Descriptions can be edited from the post’s menu.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                RecipeShareChoice(attemptID: attempt.id, selection: $sharedRecipe)
                Section("Post Description · optional") {
                    TextField("Tell your Sous Chefs about this cook", text: $postDescription, axis: .vertical)
                        .lineLimit(3...8).accessibilityIdentifier("post-description-input")
                    Text("Shared with this post’s authorized audience. Personal Notes stay private and are never copied here. Up to 2,000 characters.").font(.footnote).foregroundStyle(.secondary)
                }
                if let identity {
                    if !identity.isConfigured {
                        Button("Set up Profile") { editingIdentity = true }.accessibilityIdentifier("social-share-setup")
                    } else {
                        Text("Posting as \(identity.handle). If you have no friends yet, only you can see the post until you connect.")
                        if revision == nil { Text("Waiting for this cook to sync.").accessibilityIdentifier("social-share-waiting-for-cook") }
                        else if checkingPost { ProgressView("Checking for an existing post") }
                        if let publicationError {
                            Text(publicationError).accessibilityIdentifier("social-share-error")
                            Button("Check again") { checkingPost = true; lookupGeneration += 1 }
                        }
                        Button(busy ? "Posting…" : "Post to The Pass") { Task { await publish() } }
                            .disabled(busy || checkingPost || revision == nil || postDescription.unicodeScalars.count > 2000).accessibilityIdentifier("social-share-publish")
                    }
                } else {
                    if failed { Button("Retry identity") { Task { await load() } } }
                    else { ProgressView("Loading profile") }
                }
                if failed { Text("Couldn’t share. Check your connection and cooking sync, then retry. You can cancel a pending draft and try again.").accessibilityIdentifier("social-share-error") }
                Text("The separate Share action opens the native image share sheet; it does not publish to Sous Chefs.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Post to The Pass").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { if !didPublish { Button("Cancel") { Task { await cancel() } }.disabled(busy) } } }
            .interactiveDismissDisabled(busy).task { await load() }
            .task(id: lookup) { await reconcile() }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in lookupGeneration += 1 }
            .sheet(isPresented: $editingIdentity) {
                if let identity { SocialIdentityEditor(identity: identity) { self.identity = $0 } }
            }
        }
    }
    private func load() async {
        if !descriptionInitialized {
            postDescription = attempt.dish?.publicDescription ?? ""
            // Posting a cook that has a photo includes it by default (owner decision, Nov 11 2026); the toggle
            // stays visible to post without it. Off when the display bytes aren't on this device.
            includePhoto = photo.map(SocialMediaRules.validJPEG) == true
            descriptionInitialized = true
        }
        guard let request else { return }
        do { identity = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "get", .init())) }
        catch is CancellationError { } catch { failed = true }
    }
    private func reconcile() async {
        guard !didPublish, let request, cookAccepted else { return }
        let current = lookup
        checkingPost = true
        defer { if current == lookup && !Task.isCancelled { checkingPost = false } }
        do {
            let existing = try await SocialPostPublisher.existing(attemptID: attempt.id, request: request)
            guard !Task.isCancelled, current == lookup, !didPublish else { return }
            publicationError = nil
            if let existing { savedPost = existing; alreadyShared = true; didPublish = true }
        } catch is CancellationError {} catch {
            if current == lookup, !Task.isCancelled { publicationError = "Couldn’t check the existing post. Try again." }
        }
    }
    private func publish() async {
        guard let request, let revision, !checkingPost, !didPublish else { return }
        busy = true; failed = false; publicationError = nil
        defer { busy = false }
        do {
            let bytes = includePhoto ? photo : nil
            if includePhoto && (media == nil || bytes.map(SocialMediaRules.validJPEG) != true) {
                publicationError = "The selected photo isn’t available. Retry the photo or turn off Include this food photo."
                return
            }
            attemptedShare = true
            if originalPostID == nil { originalPostID = postID }
            func send(_ revision: Int) async throws -> SocialPost {
                try await SocialPostPublisher.publish(attemptID: attempt.id, postID: postID, revision: revision,
                    includePhoto: includePhoto, photo: bytes, request: request, media: media, postDescription: postDescription, sharedRecipe: sharedRecipe, scoreLocked: model.scoreText == nil, prepared: { post in
                        savedPost = post; postID = post.id
                    })
            }
            let post: SocialPost
            do { post = try await send(revision) }
            catch where StayGrubbyConflict.matches(error) {
                // Right after ranking, follow-up sync operations can advance the account revision
                // between readiness and prepare. Retry once with the newer accepted revision.
                guard let newer = self.revision, newer != revision else { throw error }
                post = try await send(newer)
            }
            savedPost = post
            alreadyShared = post.id != originalPostID
            didPublish = true
            publication?.sharedManually(attempt.rankedItemID)
            NotificationCenter.default.post(name: .socialContentChanged, object: nil)
        } catch is CancellationError {} catch {
            await reconcile()
            if !didPublish {
                publicationError = StayGrubbyConflict.matches(error)
                    ? "Your cooking is still syncing. Wait a moment, then publish again."
                    : "Couldn’t publish this post. Check your connection and retry."
            }
        }
    }
    private func cancel() async {
        if attemptedShare && !didPublish, let request, let originalPostID {
            _ = try? await request("social_content", "cancelDraft", .init(postID: originalPostID))
            await SocialPhotoCleanup.run(request: request, media: media)
        }
        close()
    }
}
extension Notification.Name { static let socialContentChanged = Notification.Name("StayGrubby.socialContentChanged") }
