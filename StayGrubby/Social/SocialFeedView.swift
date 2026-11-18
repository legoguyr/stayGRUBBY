import SwiftUI

struct SocialFeedView: View {
    var isSelected = true
    @Environment(\.socialRequest) private var request
    @Environment(\.socialMedia) private var media
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accountContentCache) private var cache
    @State private var posts: [SocialPost] = []
    @State private var cursor: PassPage.Cursor?
    @State private var identity: SocialIdentity?
    @State private var friendCount = 0
    @State private var loading = false
    @State private var failed = false
    @State private var hasMore = false
    @State private var generation = UUID()
    @State private var revision = 0
    @State private var editingIdentity = false
    @State private var person: SocialPerson?
    @State private var deleting: SocialPost?
    @State private var confirmingDelete = false
    @State private var route: SocialPostRoute?
    var body: some View {
        SGEditorialList {
            if request == nil {
                ContentUnavailableView("The Pass", systemImage: "person.2", description: Text("Sign in to connect with your Sous Chefs. Your cooking library stays private."))
            } else if let identity, !identity.isConfigured {
                Section {
                    Text("Choose your profile name and username to connect. Your cooking stays private until you share it.")
                    Button("Set up Profile") { editingIdentity = true }
                }
            } else {
                if loading && posts.isEmpty { ProgressView("Loading posts") }
                if failed {
                    Text("Couldn’t load posts. Check your connection and retry.").accessibilityIdentifier("feed-error")
                    Button("Retry") { refresh() }.accessibilityIdentifier("feed-retry")
                } else if !loading && posts.isEmpty {
                    ContentUnavailableView("Nothing shared yet", systemImage: "fork.knife",
                        description: Text(friendCount == 0 ? "Find a Sous Chef to see what they cook." : "Cooks from your Sous Chefs will appear here."))
                    NavigationLink("Find Sous Chefs") { FriendsView() }.accessibilityIdentifier("feed-find-friends")
                }
                ForEach(posts) { post in
                    SocialFeedCard(post: post, profile: { person = post.author }, delete: { deleting = post; confirmingDelete = true }, navigate: { route = $0 })
                }.listRowSeparator(.hidden).listRowBackground(SGTheme.ColorToken.background)
                if hasMore { Button("Load more posts") { Task { await load(more: true) } }.disabled(loading).accessibilityIdentifier("feed-more") }
            }
        }
        .accessibilityIdentifier("grub-list")
        .listStyle(.plain).background(SGTheme.ColorToken.background)
        .navigationTitle("The Pass").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) { SGPrimaryBrandTitle(page: "The Pass") }
            ToolbarItem(placement: .topBarTrailing) { NotificationsLink().labelStyle(.iconOnly) }.sgIndependentToolbarBackground()
            ToolbarItem(placement: .topBarTrailing) { NavigationLink { FriendsView() } label: { SGToolbarIcon(asset: "SousChefs") }.sgUtilityTint().accessibilityLabel("Sous Chefs") }.sgIndependentToolbarBackground()
        }
        .safeAreaPadding(.bottom, SGTheme.Space.medium)
        .navigationDestination(item: $route) { SocialPostDestination(route: $0) }
        .refreshable { await load() }
        .onSocialRefresh { if isSelected { await load(poll: true) } }
        .onReceive(NotificationCenter.default.publisher(for: .socialEngagementChanged)) { _ in cache?.pass.invalidate(); if isSelected { Task { await load() } } }
        // Read caching (MVP stabilization): leaving the tab or the app keeps the posts. Returning shows them
        // at once and refreshes in the background only when they are stale or something changed.
        .task(id: "\(isSelected):\(revision)") {
            guard isSelected else { generation = UUID(); return }
            if posts.isEmpty, identity == nil, let snapshot = cache?.pass.value { restore(snapshot) }
            // Fresh and unchanged (an empty feed counts): nothing to fetch. `refresh()` withdraws freshness.
            if cache?.pass.isFresh() == true { return }
            await load(poll: cache?.pass.hasValue == true && identity?.isConfigured == true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && isSelected && cache?.pass.isFresh() != true { Task { await load(poll: identity?.isConfigured == true) } }
            else if phase != .active { generation = UUID() }
        }
        .onDisappear { generation = UUID() }
        .sheet(item: $person, onDismiss: { refresh() }) { person in
            NavigationStack {
                FriendProfileView(person: person) { refresh() }
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { self.person = nil } } }
            }
        }
        .sheet(isPresented: $editingIdentity, onDismiss: { refresh() }) {
            if let identity { SocialIdentityEditor(identity: identity) { self.identity = $0; refresh() } }
        }
        .confirmationDialog("Delete this Post?", isPresented: $confirmingDelete, titleVisibility: .visible, presenting: deleting) { post in
            Button("Delete Post", role: .destructive) { Task { await delete(post) } }
        } message: { _ in Text("This removes the shared post and can’t be undone. Your private cook, photo and ranking stay intact.") }
    }
    /// `poll`: the 30 s foreground refresh. It re-reads only the first feed page; identity and Sous Chefs
    /// already loaded on this screen are reused (they change through their own screens, which notify).
    private func load(more: Bool = false, poll: Bool = false) async {
        guard let request else { return }
        let token = UUID(); generation = token; loading = true; failed = false
        let cursor = more ? self.cursor : nil
        if !more { hasMore = false }
        defer { if generation == token { loading = false } }
        do {
            let reuse = (poll || more) && identity?.isConfigured == true
            let ownIdentity: SocialIdentity
            if reuse, let known = identity { ownIdentity = known }
            else { ownIdentity = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "get", .init())) }
            guard !Task.isCancelled, generation == token else { return }; identity = ownIdentity
            guard ownIdentity.isConfigured else {
                // Not set up yet: remember that too, so tab switches don't re-ask until something changes.
                cache?.pass.store(PassSnapshot(posts: [], cursor: nil, hasMore: false, identity: ownIdentity, friendCount: 0)); return
            }
            var people: SocialPeoplePage?
            if !reuse { people = try JSONDecoder().decode(SocialPeoplePage.self, from: await request("social_people", "friends", .init())) }
            let next = try JSONDecoder().decode(PassPage.self, from: await request("social_feed", "activity_page", .init(beforeTime: cursor?.createdAt, beforeID: cursor?.id)))
            guard !Task.isCancelled, generation == token else { return }
            if let people { friendCount = people.people.count }
            // The Pass is shared Cook activity only (PassPage drops legacy Recipe items; a cook post can still offer its Recipe).
            if more { let ids = Set(posts.map(\.id)); posts += next.posts.filter { !ids.contains($0.id) } } else { posts = next.posts }
            self.cursor = next.cursor ?? self.cursor; hasMore = next.hasMore
            if !more { cache?.pass.store(PassSnapshot(posts: next.posts, cursor: next.cursor, hasMore: next.hasMore, identity: ownIdentity, friendCount: friendCount)) }
            await SocialPhotoCleanup.run(request: request, media: media)
        } catch is CancellationError { } catch {
            // A failed background refresh keeps what is already shown.
            guard generation == token else { return }; if posts.isEmpty { hasMore = false }; failed = true
        }
    }
    /// An explicit or change-driven refresh: withdraw freshness and re-run the load.
    private func refresh() { cache?.pass.invalidate(); revision += 1 }
    private func restore(_ snapshot: PassSnapshot) {
        posts = snapshot.posts; cursor = snapshot.cursor; hasMore = snapshot.hasMore
        identity = snapshot.identity; friendCount = snapshot.friendCount
    }
    private func delete(_ post: SocialPost) async {
        guard let request else { return }
        do {
            _ = try await request("social_content", "delete", .init(postID: post.id))
            posts.removeAll { $0.id == post.id }; cache?.pass.value?.posts.removeAll { $0.id == post.id }
            await SocialPhotoCleanup.run(request: request, media: media, afterRetirement: true)
            NotificationCenter.default.post(name: .socialContentChanged, object: nil)
        } catch is CancellationError { } catch { posts = []; failed = true }
    }
}

/// One cook on The Pass (November 17, 2026 redesign): who cooked, the Dish and its photo, the score they
/// shared, and their description as a caption — readable without another tap. Dish Details holds the rest.
/// The Pass card (master UI milestone, November 18, 2026). Hierarchy: creator → Dish identity (name, cook
/// and course, compact score) → photo → caption → Hands · Comments · Recipe on one row. Tapping the Dish
/// or photo opens Dish Details; nothing on the card writes until the viewer acts.
struct SocialFeedCard: View {
    let post: SocialPost
    var profile: () -> Void
    var delete: () -> Void
    var navigate: (SocialPostRoute) -> Void = { _ in }
    private var active: Bool { post.published && post.moderationState == "active" }
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            HStack(alignment: .center, spacing: SGTheme.Space.small) {
                SocialPostAuthor(post: post, profile: profile)
                Spacer(minLength: 4)
                SocialPostActions(post: post, delete: delete)
            }
            Button { navigate(.post(post.id)) } label: { foodIdentity }
                .buttonStyle(.plain).accessibilityLabel("Open Dish Details: \(post.title)")
                .accessibilityValue([post.versionTitle, post.scoreText.map { "Score \($0)" + (post.sharedRankText.map { ", rank at sharing \($0)" } ?? "") } ?? "Score locked",
                                     post.photoPath != nil ? "Food photo" : nil].compactMap { $0 }.joined(separator: ", "))
                .accessibilityIdentifier("post-open-\(post.id)")
            if let description = post.postDescription, !description.isEmpty {
                SocialPostCaption(post: post, description: description)
            }
            if let line = SocialPostPresentation.provenance(post.provenance) {
                Label(line, systemImage: "person.2").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let achievement = post.achievement {
                Label(achievement, systemImage: "trophy").font(SGTheme.TypeRole.secondary.weight(.medium)).foregroundStyle(SGTheme.ColorToken.accent)
            }
            if !post.published { Text("Unpublished photo draft").foregroundStyle(.secondary) }
            if post.moderationState != "active" { Text("Hidden by moderation").foregroundStyle(.secondary) }
            if active {
                SocialEngagementView(post: post) {
                    if let recipeID = post.recipeID { SocialRecipeChip(recipeID: recipeID, navigate: navigate) }
                }
            }
        }
        .padding(.top, SGTheme.Space.medium).padding(.bottom, SGTheme.Space.xSmall)
        .overlay(alignment: .bottom) { SGTheme.ColorToken.border.frame(height: SGTheme.Size.border) }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .contain).accessibilityIdentifier("feed-post-\(post.id)")
    }
    private var foodIdentity: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: SGTheme.Space.small) {
                    Text(post.title).font(.title3.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SocialCompactScore(post: post)
                }
                if let line = SocialPostPresentation.cookLine(post) {
                    Text(line).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("post-course-cuisine")
                }
            }
            // No placeholder for a post without a photo: the Dish name leads instead of an empty frame.
            if post.photoPath != nil { SocialPhoto(path: post.photoPath).sgPhotoFrame(.card).accessibilityHidden(true) }
        }.foregroundStyle(SGTheme.ColorToken.primaryText).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
}

/// The card's score: a compact pill with rank at sharing, or a quiet lock. Same authorized snapshot rules
/// as `SocialPostScore`; no score policy here.
struct SocialCompactScore: View {
    let post: SocialPost
    var body: some View {
        if let score = post.scoreText {
            HStack(spacing: SGTheme.Space.xSmall) {
                if let rank = post.sharedRankText {
                    Text(rank).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary).monospacedDigit()
                        .accessibilityLabel("Rank at sharing: \(rank)")
                }
                SGScore(text: score, role: .pill, identifier: "social-score")
            }
        } else {
            Image(systemName: "lock").font(.subheadline).foregroundStyle(.secondary)
                .accessibilityLabel("Score locked").accessibilityIdentifier("post-score-locked")
        }
    }
}

/// Compact Recipe entry for a card's engagement row. Opens the creator's live Recipe (access-checked on
/// every open); never a copy.
struct SocialRecipeChip: View {
    let recipeID: UUID
    var navigate: (SocialPostRoute) -> Void
    var body: some View {
        Button { navigate(.currentRecipe(recipeID)) } label: {
            Label("Recipe", systemImage: "book.closed").font(SGTheme.TypeRole.secondary.weight(.semibold))
                .padding(.horizontal, SGTheme.Space.small).frame(minHeight: 32)
                .background(SGTheme.ColorToken.surface, in: Capsule())
                .frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(SGTheme.ColorToken.accent)
        .accessibilityLabel("View Recipe").accessibilityHint("Opens the latest version of the linked Recipe")
        .accessibilityIdentifier("post-recipe")
    }
}

/// Instagram-style caption: the creator's name, then the Dish's Public Description, trimmed to two lines
/// with an in-place **more**. Expanding is local presentation only (no request, nothing stored).
struct SocialPostCaption: View {
    let post: SocialPost
    let description: String
    var collapsedLines = 2
    @State private var expanded = false
    @State private var truncated = false
    private var text: Text {
        Text(post.isAuthor ? "You" : post.author.displayName).fontWeight(.semibold) + Text(" ") + Text(description)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            text.font(SGTheme.TypeRole.body).lineLimit(expanded ? nil : collapsedLines)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    // Whether the full caption fits in the collapsed height decides if "more" is offered.
                    ViewThatFits(in: .vertical) {
                        text.font(SGTheme.TypeRole.body).fixedSize(horizontal: false, vertical: true).hidden()
                            .onAppear { truncated = false }
                        Color.clear.onAppear { truncated = true }
                    }
                }
                .accessibilityIdentifier("post-description-\(post.id)")
            if truncated && !expanded {
                // A 44-point target that sits visually tight under the caption.
                Button("more") { expanded = true }
                    .font(SGTheme.TypeRole.secondary.weight(.semibold)).foregroundStyle(.secondary)
                    .frame(minWidth: SGTheme.Size.minimumTap, minHeight: SGTheme.Size.minimumTap, alignment: .leading)
                    .contentShape(Rectangle()).padding(.vertical, -10)
                    .accessibilityLabel("Show full description").accessibilityIdentifier("post-caption-more-\(post.id)")
            }
        }
    }
}

/// A presentation of an already-authorized/unlocked server snapshot. No new score policy.
struct SocialScoreMedallion: View {
    let text: String
    var body: some View { SGScore(text: text, role: .medallion, identifier: "social-score") }
}
