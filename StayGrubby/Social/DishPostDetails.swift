import SwiftUI

/// Dish Details for a post on The Pass (November 17, 2026; UI_ARCHITECTURE "The Pass — feed, comments and
/// Dish Details"). The feed card already says what was cooked; this page adds what the card doesn't:
/// the full description, source and cooking context, the linked Recipe (live and as posted) and the
/// creator's other shared cooks of the same Dish.
///
/// Reads only server-authorized post snapshots (`social_feed post` / `dish`); opening it never writes.
/// The page is an ordered list of independent sections (`DishDetailsSection`), so a later section such as
/// Shop This Dish (equipment, specialty ingredients, creator recommendations) is one more case, not a redesign.
struct SocialPostDetailView: View {
    let postID: UUID
    var comments = false
    @Environment(\.socialRequest) private var request
    @Environment(\.accountContentCache) private var cache
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var dismiss
    @State private var post: SocialPost?
    @State private var loadedAt: Date?
    @State private var failed = false
    @State private var showingComments = false
    @State private var person: SocialPerson?
    @State private var deleting = false
    @State private var route: SocialPostRoute?
    @State private var generation = UUID()
    @State private var openedComments = false
    var body: some View {
        ScrollView {
            if let post {
                VStack(alignment: .leading, spacing: SGTheme.Space.group) {
                    ForEach(DishDetailsSection.allCases) { section in
                        DishDetailsSectionView(section: section, post: post, profile: { person = post.author },
                                               delete: { deleting = true }, navigate: { route = $0 })
                    }
                }
                .frame(maxWidth: SGTheme.Size.contentMaximum, alignment: .leading)
                .padding(.horizontal, SGTheme.Space.margin).padding(.bottom, SGTheme.Space.xLarge)
                .frame(maxWidth: .infinity)
            } else if failed {
                SGContentState(title: "Post unavailable", symbol: "lock", message: "The post or your access may have changed.") {
                    Button("Retry") { Task { await load() } }.buttonStyle(SGButtonStyle()).accessibilityIdentifier("dish-details-retry")
                }.padding(.top, SGTheme.Space.xLarge)
            } else { SGLoadingState(label: "Opening Dish Details") }
        }
        .background(SGTheme.ColorToken.background)
        .navigationTitle("Dish Details").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .accessibilityIdentifier("dish-details")
        .task {
            // The Pass already holds this post: show it at once, and fetch only when that copy is stale.
            if post == nil, let seed = cache?.pass.value?.posts.first(where: { $0.id == postID }) {
                post = seed
                if cache?.pass.isFresh() != true { await load() }
            } else if post == nil { await load() }
            if post != nil, comments, !openedComments { openedComments = true; showingComments = true }
        }
        .refreshable { await load() }
        .navigationDestination(item: $route) { SocialPostDestination(route: $0) }
        // Returning to the app refreshes only a copy older than the shared read-cache window.
        .onChange(of: phase) { _, next in
            generation = UUID()
            if next == .active, loadedAt.map({ Date().timeIntervalSince($0) > AccountContentCache.maximumAge }) ?? true { Task { await load() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
        .onReceive(NotificationCenter.default.publisher(for: .socialEngagementChanged)) { _ in Task { await load() } }
        .onDisappear { generation = UUID() }
        .sheet(isPresented: $showingComments, onDismiss: { Task { await load() } }) { SocialCommentsView(postID: postID) }
        .sheet(item: $person, onDismiss: { Task { await load() } }) { person in
            NavigationStack {
                FriendProfileView(person: person) { Task { await load() } }
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { self.person = nil } } }
            }
        }
        .confirmationDialog("Delete this Post?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete Post", role: .destructive) { Task { await remove() } }
        } message: { Text("This removes the shared post and can’t be undone. Your private cook, photo and ranking stay intact.") }
    }
    private func load() async {
        guard let request else { failed = true; return }; let token = UUID(); generation = token; failed = false
        do {
            let next = try JSONDecoder().decode(SocialPostsPage.self, from: await request("social_feed", "post", .init(postID: postID)))
            guard !Task.isCancelled, generation == token else { return }
            post = next.posts.first; failed = post == nil; loadedAt = Date()
        } catch is CancellationError { } catch { if generation == token { post = nil; failed = true } }
    }
    private func remove() async {
        guard let request else { return }
        do {
            _ = try await request("social_content", "delete", .init(postID: postID))
            // The post is gone: return to where it was opened rather than showing an unavailable page.
            NotificationCenter.default.post(name: .socialContentChanged, object: nil); dismiss()
        } catch { post = nil; failed = true }
    }
}

/// Dish Details sections, in page order. Each section decides for itself whether it has anything to show.
/// Future: `.shop` (Shop This Dish) slots in after `.recipe` without touching the others.
enum DishDetailsSection: String, CaseIterable, Identifiable {
    case photo, identity, creator, story, details, recipe, engagement, otherCooks
    var id: String { rawValue }
}

private struct DishDetailsSectionView: View {
    let section: DishDetailsSection
    let post: SocialPost
    var profile: () -> Void
    var delete: () -> Void
    var navigate: (SocialPostRoute) -> Void
    private var active: Bool { post.published && post.moderationState == "active" }
    var body: some View {
        switch section {
        case .photo:
            if post.photoPath != nil { SocialPhoto(path: post.photoPath).sgPhotoFrame(.hero).padding(.top, SGTheme.Space.small) }
        case .identity:
            HStack(alignment: .top, spacing: SGTheme.Space.small) {
                VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                    Text(post.title).font(SGTheme.TypeRole.title).fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let version = post.versionTitle { Text(version).font(SGTheme.TypeRole.headline).foregroundStyle(.secondary) }
                    if let metadata = SocialPostPresentation.metadata(post.metadata) {
                        Text(metadata).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary).accessibilityIdentifier("post-course-cuisine")
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                SocialPostScore(post: post)
            }.padding(.top, post.photoPath == nil ? SGTheme.Space.medium : 0)
        case .creator:
            HStack(spacing: SGTheme.Space.small) {
                SocialPostAuthor(post: post, profile: profile)
                Spacer(minLength: SGTheme.Space.xSmall)
                SocialPostActions(post: post, delete: delete)
            }
        case .story:
            if let description = post.postDescription, !description.isEmpty {
                Text(description).font(SGTheme.TypeRole.body).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("post-description-\(post.id)")
            }
        case .details:
            DishPostFacts(post: post)
        case .recipe:
            if let recipeID = post.recipeID, active {
                VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                    SGSectionHeader(title: "Recipe")
                    SocialPostRecipeLink(recipeID: recipeID, navigate: navigate)
                    if let revision = post.recipeRevision {
                        Button { navigate(.recipe(post.id)) } label: { Text("Recipe as posted · revision \(revision)") }
                            .font(.footnote).buttonStyle(.borderless).frame(minHeight: SGTheme.Size.minimumTap)
                            .accessibilityIdentifier("post-recipe-as-posted")
                    }
                }
            }
        case .engagement:
            if !post.published { Text("Unpublished photo draft").foregroundStyle(.secondary) }
            else if post.moderationState != "active" { Text("Hidden by moderation").foregroundStyle(.secondary) }
            else { SocialEngagementView(post: post) }
        case .otherCooks:
            if active { DishSharedCooks(post: post, navigate: navigate) }
        }
    }
}

/// Source, collaborators and context — only facts the feed card leaves out.
private struct DishPostFacts: View {
    let post: SocialPost
    private var facts: [(label: String, value: String)] {
        // The creator line already carries the shared date; cooked-at needs a server snapshot (roadmap).
        var rows: [(String, String)] = []
        if let source = post.metadata?.source {
            let text = [source.recipe, source.name, source.author, source.page.map { "Page \($0)" }]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if !text.isEmpty { rows.append(("Source", text.joined(separator: " · "))) }
        }
        if let provenance = post.provenance {
            if provenance.kind == "recreated", let creator = provenance.creator { rows.append(("Inspired by", creator.displayName)) }
            else if let people = provenance.people, !people.isEmpty { rows.append(("Cooked with", ListFormatter.localizedString(byJoining: people.map(\.displayName)))) }
        }
        if let achievement = post.achievement { rows.append(("Milestone", achievement)) }
        return rows
    }
    var body: some View {
        let facts = facts
        if !facts.isEmpty {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            ForEach(facts, id: \.label) { fact in
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(fact.label).foregroundStyle(.secondary)
                        Spacer(minLength: SGTheme.Space.small)
                        Text(fact.value).multilineTextAlignment(.trailing)
                    }
                    VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                        Text(fact.label).foregroundStyle(.secondary)
                        Text(fact.value).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .font(SGTheme.TypeRole.secondary).frame(minHeight: SGTheme.Size.minimumTap * 0.75)
                .accessibilityElement(children: .combine).accessibilityIdentifier("dish-fact-\(fact.label)")
            }
        }
        .padding(SGTheme.Space.medium)
        .background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: SGTheme.Radius.card, style: .continuous))
        }
    }
}

/// Previous Cooks: the creator's other shared cooks of this exact Dish (`dishKey`), from posts the viewer
/// can already see. Newest first.
struct DishSharedCooks: View {
    let post: SocialPost
    var navigate: (SocialPostRoute) -> Void
    @Environment(\.socialRequest) private var request
    @Environment(\.accountContentCache) private var cache
    @State private var model = SharedCooksModel()
    @State private var order: SharedCookOrder = .recent
    private var cooks: [SocialPost] { SharedCookOrder.otherCooks(of: post, among: model.posts ?? [], order: order) }
    var body: some View {
        // A container that always exists, so the load task runs even before there is anything to show.
        VStack(alignment: .leading, spacing: 0) {
            if model.failed {
                VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                    SGSectionHeader(title: "Previous Cooks")
                    Text("Couldn’t load other cooks.").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                    Button("Retry") { Task { await load(force: true) } }.accessibilityIdentifier("dish-cooks-retry")
                }
            } else if !cooks.isEmpty || model.hasMore {
                VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                    SGSectionHeader(title: "Previous Cooks") {
                        // Sorting only helps with several cooks and at least one unlocked score to rank by;
                        // newest first is the default.
                        if (cooks.count > 1 || model.hasMore), cooks.contains(where: { $0.scoreText != nil }) {
                            SGBrowseSortMenu(options: SharedCookOrder.allCases, selection: $order, title: \.title,
                                             identifier: "dish-cooks-sort", label: order.title)
                        }
                    }
                    ForEach(cooks) { cook in
                        Button { navigate(.post(cook.id)) } label: { SharedCookRow(post: cook) }
                            .buttonStyle(SGRowButtonStyle()).accessibilityIdentifier("dish-cook-\(cook.id)")
                    }
                    if model.hasMore {
                        Button("Load more cooks") { Task { await load(more: true) } }
                            .disabled(model.loading).accessibilityIdentifier("dish-cooks-more")
                    }
                }.accessibilityElement(children: .contain).accessibilityIdentifier("dish-other-cooks")
            } else { Color.clear.frame(height: 0).accessibilityHidden(true) }
        }
        .task(id: "\(post.id)/\(post.dishKey ?? "legacy")/\(order.rawValue)") { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load(force: true) } }
    }
    private func load(more: Bool = false, force: Bool = false) async {
        guard let request else { return }
        await model.load(for: post, order: order, more: more, force: force, request: request, cache: cache)
    }
}

private struct SharedCookRow: View {
    let post: SocialPost
    var body: some View {
        HStack(spacing: SGTheme.Space.small) {
            SocialPhoto(path: post.photoPath).sgPhotoFrame(.compactThumbnail)
            VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                Text(post.versionTitle ?? post.title).font(SGTheme.TypeRole.body.weight(.medium)).lineLimit(2)
                Text(SocialPostPresentation.timestamp(post.date)).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if let score = post.scoreText { SGScore(text: score, role: .standard, identifier: "dish-cook-score") }
            else { Image(systemName: "lock").foregroundStyle(.secondary).accessibilityLabel("Score locked") }
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary).accessibilityHidden(true)
        }
        .foregroundStyle(SGTheme.ColorToken.primaryText)
        .frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Ordering for a creator's shared cooks of one Dish. Pure, so it is unit-tested.
nonisolated enum SharedCookOrder: String, CaseIterable, Identifiable, Sendable {
    case recent, highestRated
    var id: String { rawValue }
    var title: String { self == .recent ? "Recent" : "Highest Rated" }

    /// The unlocked score a post's snapshot carries; a locked score (nil) never ranks.
    static func score(_ post: SocialPost) -> Double? {
        post.scoreText.flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
    }
    /// Visible, active posts of the same Dish (`SharedCookLookup.sameDish`), excluding the one shown.
    static func otherCooks(of post: SocialPost, among posts: [SocialPost], order: SharedCookOrder) -> [SocialPost] {
        let matches = posts.filter {
            $0.id != post.id && $0.published && $0.moderationState == "active" && SharedCookLookup.sameDish($0, as: post)
        }
        let recent: (SocialPost, SocialPost) -> Bool = { $0.createdAt == $1.createdAt ? $0.id.uuidString > $1.id.uuidString : $0.createdAt > $1.createdAt }
        switch order {
        case .recent: return matches.sorted(by: recent)
        case .highestRated:
            return matches.sorted { a, b in
                switch (score(a), score(b)) {
                case let (x?, y?) where x != y: return x > y
                case (.some, nil): return true
                case (nil, .some): return false
                default: return recent(a, b)
                }
            }
        }
    }
}

/// Author identity used by the feed card and Dish Details.
struct SocialPostAuthor: View {
    let post: SocialPost
    var profile: () -> Void
    var body: some View {
        if post.isAuthor { label }
        else { Button(action: profile) { label }.buttonStyle(.plain).accessibilityLabel("View \(post.author.displayName)’s profile") }
    }
    private var label: some View {
        HStack(spacing: SGTheme.Space.small) {
            SocialAvatar(name: post.author.displayName, path: post.author.avatarPath, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(post.isAuthor ? "You" : post.author.displayName).font(SGTheme.TypeRole.headline)
                    .foregroundStyle(SGTheme.ColorToken.primaryText)
                Text(SocialPostPresentation.timestamp(post.date)).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            }
        }.frame(minHeight: SGTheme.Size.minimumTap)
    }
}

/// The score snapshot exactly as the server authorized it, with rank at sharing; locked stays locked.
struct SocialPostScore: View {
    let post: SocialPost
    var body: some View {
        if let score = post.scoreText {
            VStack(alignment: .trailing, spacing: SGTheme.Space.xSmall) {
                SocialScoreMedallion(text: score)
                if let rank = post.sharedRankText {
                    Text(rank).font(SGTheme.TypeRole.secondary).monospacedDigit().accessibilityLabel("Rank at sharing: \(rank)")
                }
            }
        } else {
            Label("Score locked", systemImage: "lock").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                .labelStyle(.iconOnly).frame(minWidth: SGTheme.Size.minimumTap, minHeight: SGTheme.Size.minimumTap)
                .accessibilityIdentifier("post-score-locked")
        }
    }
}

/// The linked Recipe as one compact row: it references the creator's Recipe (never a copy) and opens its
/// latest version, which the server access-checks on every open.
struct SocialPostRecipeLink: View {
    let recipeID: UUID
    var navigate: (SocialPostRoute) -> Void
    var body: some View {
        Button { navigate(.currentRecipe(recipeID)) } label: {
            HStack(spacing: SGTheme.Space.small) {
                Image(systemName: "book.closed").font(.body.weight(.medium)).foregroundStyle(SGTheme.ColorToken.accent)
                    .frame(width: 28).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("View Recipe").font(SGTheme.TypeRole.body.weight(.semibold)).foregroundStyle(SGTheme.ColorToken.accent)
                    Text("Linked Recipe · always the latest version").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary).accessibilityHidden(true)
            }
            .padding(.horizontal, SGTheme.Space.small).padding(.vertical, SGTheme.Space.xSmall)
            .frame(minHeight: SGTheme.Size.minimumTap)
            .background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: SGTheme.Radius.field, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore).accessibilityLabel("View Recipe").accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the latest version of the linked Recipe").accessibilityIdentifier("post-recipe")
    }
}
