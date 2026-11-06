import SwiftUI

struct SocialFeedView: View {
    var isSelected = true
    @Environment(\.socialRequest) private var request
    @Environment(\.socialMedia) private var media
    @Environment(\.scenePhase) private var scenePhase
    @State private var posts: [GrubListActivity] = []
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
                ContentUnavailableView("Grub List", systemImage: "person.2", description: Text("Sign in to connect with friends. Your development cooking library remains private."))
            } else if let identity, !identity.isConfigured {
                Section {
                    Text("Choose your profile name and username to connect. Your cooking stays private until you share it.")
                    Button("Set up Profile") { editingIdentity = true }
                }
            } else {
                if loading && posts.isEmpty { ProgressView("Loading posts") }
                if failed {
                    Text("Couldn’t load posts. Check your connection and retry.").accessibilityIdentifier("feed-error")
                    Button("Retry") { revision += 1 }.accessibilityIdentifier("feed-retry")
                } else if !loading && posts.isEmpty {
                    ContentUnavailableView("Nothing shared yet", systemImage: "fork.knife",
                        description: Text(friendCount == 0 ? "Find a Sous Chef to see their cooks and Recipes." : "Cooks and Recipes from your Sous Chefs will appear here."))
                    NavigationLink("Find Sous Chefs") { FriendsView() }.accessibilityIdentifier("feed-find-friends")
                }
                ForEach(posts) { activity in
                    switch activity {
                    case .cook(let post): SocialFeedCard(post: post, profile: { person = post.author }, delete: { deleting = post; confirmingDelete = true }, navigate: { route = $0 })
                    case .recipe(let recipe): RecipeActivityCard(activity: recipe, profile: { person = recipe.author })
                    }
                }.listRowSeparator(.hidden).listRowBackground(SGTheme.ColorToken.background)
                if hasMore { Button("Load more posts") { Task { await load(more: true) } }.disabled(loading).accessibilityIdentifier("feed-more") }
            }
        }
        .accessibilityIdentifier("grub-list")
        .listStyle(.plain).background(SGTheme.ColorToken.background)
        .navigationTitle("Grub List").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) { SGPrimaryBrandTitle(page: "Grub List") }
            ToolbarItem(placement: .topBarTrailing) { NotificationsLink().labelStyle(.iconOnly) }.sgIndependentToolbarBackground()
            ToolbarItem(placement: .topBarTrailing) { NavigationLink { FriendsView() } label: { Label("Sous Chefs", systemImage: "person.2") }.labelStyle(.iconOnly) }.sgIndependentToolbarBackground()
        }
        .safeAreaPadding(.bottom, SGTheme.Space.medium)
        .navigationDestination(item: $route) { SocialPostDestination(route: $0) }
        .refreshable { await load() }
        .onSocialRefresh { if isSelected { await load() } }
        .onReceive(NotificationCenter.default.publisher(for: .socialEngagementChanged)) { _ in if isSelected { Task { await load() } } }
        .task(id: "\(isSelected):\(revision)") {
            guard isSelected else { generation = UUID(); posts = []; return }
            await load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in posts = []; revision += 1 }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && isSelected { revision += 1 }
            else { generation = UUID(); posts = [] }
        }
        .onDisappear { generation = UUID() }
        .sheet(item: $person, onDismiss: { revision += 1 }) { person in
            NavigationStack {
                FriendProfileView(person: person) { revision += 1 }
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { self.person = nil } } }
            }
        }
        .sheet(isPresented: $editingIdentity, onDismiss: { revision += 1 }) {
            if let identity { SocialIdentityEditor(identity: identity) { self.identity = $0; revision += 1 } }
        }
        .confirmationDialog("Delete this shared post?", isPresented: $confirmingDelete, titleVisibility: .visible, presenting: deleting) { post in
            Button("Delete shared post", role: .destructive) { Task { await delete(post) } }
        } message: { _ in Text("Your private cook, photo and ranking stay intact.") }
    }
    private func load(more: Bool = false) async {
        guard let request else { return }
        let token = UUID(); generation = token; loading = true; failed = false
        let cursor = more ? posts.last : nil
        if !more { hasMore = false }
        defer { if generation == token { loading = false } }
        do {
            let ownIdentity = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "get", .init()))
            guard !Task.isCancelled, generation == token else { return }; identity = ownIdentity
            guard ownIdentity.isConfigured else { return }
            let people = try JSONDecoder().decode(SocialPeoplePage.self, from: await request("social_people", "friends", .init()))
            let next = try JSONDecoder().decode(GrubListPage.self, from: await request("social_feed", "activity_page", .init(beforeTime: cursor?.createdAt, beforeID: cursor?.id)))
            guard !Task.isCancelled, generation == token else { return }
            friendCount = people.people.count
            if more { let ids = Set(posts.map(\.id)); posts += next.activities.filter { !ids.contains($0.id) } } else { posts = next.activities }; hasMore = next.activities.count == 25
            await SocialPhotoCleanup.run(request: request, media: media)
        } catch is CancellationError { } catch {
            guard generation == token else { return }; posts = []; hasMore = false; failed = true
        }
    }
    private func delete(_ post: SocialPost) async {
        guard let request else { return }
        do {
            _ = try await request("social_content", "delete", .init(postID: post.id))
            posts.removeAll { $0.id == post.id }
            await SocialPhotoCleanup.run(request: request, media: media)
            NotificationCenter.default.post(name: .socialContentChanged, object: nil)
        } catch is CancellationError { } catch { posts = []; failed = true }
    }
}

struct SocialFeedCard: View {
    let post: SocialPost
    var profile: () -> Void
    var delete: () -> Void
    var isDetail = false
    var navigate: (SocialPostRoute) -> Void = { _ in }
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            HStack(alignment: .center, spacing: SGTheme.Space.small) {
                if post.isAuthor { authorIdentity }
                else {
                    Button(action: profile) { authorIdentity }.buttonStyle(.plain)
                        .accessibilityLabel("View \(post.author.displayName)’s profile")
                }
                Spacer(minLength: 4)
                SocialPostActions(post: post, delete: delete)
            }
            if isDetail { foodIdentity }
            else {
                Button { navigate(.post(post.id)) } label: { foodIdentity }
                    .buttonStyle(.plain).accessibilityLabel("Open post: \(post.title)")
                    .accessibilityValue(post.scoreText.map { "Score \($0)" } ?? "Score locked")
                    .accessibilityIdentifier("post-open-\(post.id)")
            }
            if let description = post.postDescription, !description.isEmpty {
                Text(description).font(SGTheme.TypeRole.body).lineLimit(isDetail ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("post-description-\(post.id)")
            }
            if isDetail {
                if let metadata = post.metadata { SocialPostMetadata(metadata: metadata) }
            }
            if post.recipeID != nil && post.published && post.moderationState == "active" {
                Button { navigate(.recipe(post.id)) } label: { Label("View Recipe", systemImage: "book.closed") }
                    .frame(minHeight: SGTheme.Size.minimumTap).accessibilityIdentifier("post-recipe")
            }
            if let provenance = post.provenance {
                if provenance.kind == "recreated", let creator = provenance.creator {
                    Label("Inspired by \(creator.displayName)", systemImage: "arrow.triangle.branch").font(.subheadline)
                } else if let people = provenance.people, !people.isEmpty {
                    Text("Cooked with " + people.map(\.displayName).joined(separator: ", ")).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
            }
            if post.scoreText == nil { Label("Score locked", systemImage: "lock").font(.subheadline).foregroundStyle(.secondary) }
            if let achievement = post.achievement { Text(achievement).font(.subheadline) }
            if !post.published { Text("Unpublished photo draft").foregroundStyle(.secondary) }
            if post.moderationState != "active" { Text("Hidden by moderation").foregroundStyle(.secondary) }
            if post.published && post.moderationState == "active" { SocialEngagementView(post: post) }
        }
        .padding(.vertical, SGTheme.Space.medium)
        .overlay(alignment: .bottom) { SGTheme.ColorToken.border.frame(height: SGTheme.Size.border) }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .contain).accessibilityIdentifier("feed-post-\(post.id)")
    }
    private var authorIdentity: some View {
        HStack(spacing: SGTheme.Space.small) {
            SocialAvatar(name: post.author.displayName, path: post.author.avatarPath, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(post.isAuthor ? "You" : post.author.displayName).font(SGTheme.TypeRole.headline)
                    .foregroundStyle(SGTheme.ColorToken.primaryText)
                Text(SocialPostPresentation.timestamp(post.date)).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            }
        }.frame(minHeight: SGTheme.Size.minimumTap)
    }
    private var foodIdentity: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            HStack(alignment: .center, spacing: SGTheme.Space.small) {
                VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                    Text(post.title).font(SGTheme.TypeRole.title).fixedSize(horizontal: false, vertical: true)
                    if let metadata = SocialPostPresentation.metadata(post.metadata) {
                        Text(metadata).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("post-course-cuisine")
                    }
                    if let version = post.versionTitle { Text(version).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if let score = post.scoreText { SocialScoreMedallion(text: score) }
            }
            Color.clear.aspectRatio(4 / 3, contentMode: .fit)
                .overlay { SocialPhoto(path: post.photoPath) }.clipped()
                .clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.hero))
                .accessibilityHidden(true)
        }.foregroundStyle(SGTheme.ColorToken.primaryText).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
}

/// A presentation of an already-authorized/unlocked server snapshot. No new score policy.
struct SocialScoreMedallion: View {
    let text: String
    @ScaledMetric(relativeTo: .headline) private var diameter = 52.0
    var body: some View {
        Text(text).font(.headline.weight(.bold)).monospacedDigit()
            .foregroundStyle(SGTheme.ScoreColor.color(forDisplayedScore: text))
            .frame(width: diameter, height: diameter)
            .background(SGTheme.ColorToken.surface, in: Circle())
            .overlay { Circle().stroke(SGTheme.ScoreColor.color(forDisplayedScore: text).opacity(0.6), lineWidth: 1.5) }
            .accessibilityLabel("Score \(text)").accessibilityIdentifier("social-score")
    }
}
