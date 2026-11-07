import SwiftUI

nonisolated struct SocialComment: Codable, Identifiable, Sendable {
    let id: UUID
    let author: SocialPerson
    let body: String
    let createdAt: Double
    let canDelete: Bool
    let isAuthor: Bool
    var date: Date { Date(timeIntervalSince1970: createdAt) }
}
nonisolated struct SocialCommentsPage: Codable, Sendable { let comments: [SocialComment] }

struct SocialEngagementView: View {
    let post: SocialPost
    @Environment(\.socialRequest) private var request
    @State private var latest: SocialPost?
    @State private var busy = false
    @State private var failed = false
    @State private var showingComments = false
    @Environment(\.sgReduceMotion) private var reduceMotion
    @State private var reactionFeedback = 0
    private var current: SocialPost { latest ?? post }
    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 24) {
                Button { Task { await update(current.liked == true ? "unlike" : "like") } } label: {
                    HStack(spacing: 6) {
                        Text("🙌").scaleEffect(current.liked == true && !reduceMotion ? 1.12 : 1)
                        Text(current.liked == true || (current.likeCount ?? 0) > 0 ? "\(current.likeCount ?? 0) Hands" : "Give Hands")
                    }.font(SGTheme.TypeRole.body.weight(.semibold)).frame(minHeight: 44)
                }.accessibilityLabel(current.liked == true ? "Remove Hands, unlike post" : "Give Hands, like this cook")
                    .accessibilityValue("\(current.likeCount ?? 0) Hands").accessibilityIdentifier("social-like-\(post.id)")
                Button { showingComments = true } label: { Label("\(current.commentCount ?? 0)", systemImage: "bubble").frame(minHeight: 44) }
                    .accessibilityLabel("Comments").accessibilityValue("\(current.commentCount ?? 0) comments").accessibilityIdentifier("social-comments-\(post.id)")
            }.disabled(busy || failed).frame(minHeight: 44)
            if failed { Text("Post unavailable or connection interrupted.").font(.footnote); Button("Refresh post") { Task { await update(nil) } } }
        }
        .onChange(of: post.commentCount) { _, _ in latest = nil }
        .onChange(of: post.likeCount) { _, _ in latest = nil }
        .onChange(of: post.liked) { _, _ in latest = nil }
        .sensoryFeedback(.selection, trigger: reactionFeedback)
        .animation(reduceMotion ? nil : SGTheme.Motion.quick, value: current.liked)
        .sheet(isPresented: $showingComments, onDismiss: { Task { await update(nil) } }) { SocialCommentsView(postID: post.id) }
    }
    private func update(_ action: String?) async {
        guard let request else { return }; busy = true
        defer { busy = false }
        do {
            let response = try await request(action == nil ? "social_feed" : "social_interactions", action ?? "post", .init(postID: post.id))
            guard !Task.isCancelled else { return }
            guard let next = try JSONDecoder().decode(SocialPostsPage.self, from: response).posts.first else { failed = true; latest = nil; NotificationCenter.default.post(name: .socialContentChanged, object: nil); return }
            if action != nil { reactionFeedback += 1 }; latest = next; failed = false
            if action != nil { NotificationCenter.default.post(name: .socialEngagementChanged, object: nil) }
        } catch is CancellationError { } catch { failed = true }
    }
}

struct SocialCommentsView: View {
    let postID: UUID
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var comments: [SocialComment] = []
    @State private var post: SocialPost?
    @State private var text = ""
    @FocusState private var writingComment: Bool
    @State private var commentID = UUID()
    @State private var loading = false
    @State private var busy = false
    @State private var failed = false
    @State private var hasMore = false
    @State private var generation = UUID()
    @State private var person: SocialPerson?
    @State private var deleting: SocialComment?
    @State private var confirmingDelete = false
    @State private var deletionRequest: SocialComment?
    @State private var reporting: SocialComment?
    @State private var deliveryFailed = false
    @Environment(\.dynamicTypeSize) private var textSize
    var body: some View {
        NavigationStack {
            SGEditorialList {
                if let post { Text(post.title).font(.headline) }
                if loading && comments.isEmpty { ProgressView("Loading comments") }
                if failed {
                    Text("Comments unavailable. The post or your access may have changed, or your connection was interrupted.")
                    Button("Retry") { Task { await load() } }.accessibilityIdentifier("comments-retry")
                } else if !loading && comments.isEmpty { Text("No comments yet. Start a conversation.") }
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                        HStack(alignment: .top) {
                            if comment.isAuthor { SocialPersonLabel(person: comment.author, size: 36) }
                            else { Button { person = comment.author } label: { SocialPersonLabel(person: comment.author, size: 36) }.buttonStyle(.plain) }
                            if comment.canDelete {
                                Button { deleting = comment; confirmingDelete = true } label: {
                                    Image(systemName: "trash").frame(width: 44, height: 44)
                                }.accessibilityLabel("86 Comment (Delete)").accessibilityIdentifier("comment-delete-\(comment.id)")
                            }
                            if !comment.isAuthor {
                                Button { reporting = comment } label: {
                                    Image(systemName: "flag").frame(width: 44, height: 44)
                                }.accessibilityLabel("Report comment").accessibilityIdentifier("social-report-comment")
                            }
                        }
                        Text(comment.body).font(SGTheme.TypeRole.body).fixedSize(horizontal: false, vertical: true)
                        Text(SocialPostPresentation.timestamp(comment.date)).font(.caption).foregroundStyle(.secondary)
                    }.buttonStyle(.borderless).padding(.vertical, SGTheme.Space.small)
                        .accessibilityElement(children: .contain).accessibilityIdentifier("social-comment-\(comment.id)")
                }
                if hasMore { Button("Load more comments") { Task { await load(more: true) } }.disabled(loading || busy) }
            }.navigationTitle("Comments").navigationBarTitleDisplayMode(.inline)
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if post != nil && !failed { composer }
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { writingComment = false }.accessibilityIdentifier("comment-keyboard-done")
                    }
                }
                .refreshable { await load() }.task { await load() }
                .onSocialRefresh { if !busy && !writingComment { await load() } }
                .onChange(of: scenePhase) { _, phase in
                    generation = UUID(); comments = []; post = nil
                    if phase == .active { Task { await load() } }
                }
                .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
                .onDisappear { generation = UUID() }
                .sheet(item: $reporting) { comment in
                    SocialReportEditor(kind: "comment", targetID: comment.id) { reporting = nil }
                }
                .sheet(item: $person, onDismiss: { Task { await load() } }) { person in
                    NavigationStack {
                        FriendProfileView(person: person) { Task { await load() } }
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { self.person = nil } } }
                    }
                }
                .confirmationDialog("86 this Comment?", isPresented: $confirmingDelete, titleVisibility: .visible, presenting: deleting) { comment in
                    Button("86 Comment", role: .destructive) {
                        deletionRequest = comment
                    }
                } message: { _ in Text("This removes your comment and can’t be undone.") }
        }
        .presentationDetents(textSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible).presentationContentInteraction(.scrolls)
        .interactiveDismissDisabled(busy)
        // Keep async deletion on the mounted screen, rather than the dismissing dialog's captured view.
        .task(id: deletionRequest?.id) {
            guard let comment = deletionRequest else { return }
            await remove(comment)
            deletionRequest = nil
        }
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            if deliveryFailed { Text("Couldn’t send. Your comment is still here.").font(.footnote).foregroundStyle(SGTheme.ColorToken.destructive).accessibilityIdentifier("comment-send-error") }
            HStack(alignment: .bottom, spacing: SGTheme.Space.small) {
                TextField("Write a comment", text: $text, axis: .vertical).lineLimit(1...4)
                    .focused($writingComment).accessibilityIdentifier("comment-body").sgField()
                    .onChange(of: text) { _, _ in if !busy { commentID = UUID(); deliveryFailed = false } }
                Button { Task { await send() } } label: {
                    if busy { ProgressView().frame(width: 44, height: 44) }
                    else { Image(systemName: "arrow.up.circle.fill").font(.title2).frame(width: 44, height: 44) }
                }.accessibilityLabel("Send comment").accessibilityIdentifier("comment-send")
                    .disabled(busy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.unicodeScalars.count > 1000)
            }.disabled(busy)
            if text.unicodeScalars.count > 900 { Text("\(text.unicodeScalars.count) / 1000").font(.caption).foregroundStyle(.secondary) }
        }.padding(SGTheme.Space.small).background(SGTheme.ColorToken.background)
    }
    private func load(more: Bool = false) async {
        guard let request else { failed = true; return }
        let token = UUID(); generation = token; let cursor = more ? comments.last : nil
        loading = true; failed = false
        if !more { hasMore = false }
        defer { if generation == token { loading = false } }
        do {
            let snapshot = try JSONDecoder().decode(SocialPostsPage.self, from: await request("social_feed", "post", .init(postID: postID)))
            let page = try JSONDecoder().decode(SocialCommentsPage.self, from: await request("social_interactions", "comments", .init(postID: postID, beforeTime: cursor?.createdAt, beforeID: cursor?.id)))
            guard !Task.isCancelled, generation == token else { return }
            guard let latest = snapshot.posts.first else { post = nil; comments = []; failed = true; return }
            post = latest
            if more { let ids = Set(comments.map(\.id)); comments += page.comments.filter { !ids.contains($0.id) } }
            else { comments = page.comments }
            hasMore = page.comments.count == 25
        } catch is CancellationError { } catch {
            guard generation == token else { return }; post = nil; comments = []; failed = true
        }
    }
    private func send() async {
        guard let request else { return }; let token = generation; busy = true; deliveryFailed = false
        defer { busy = false }
        do {
            _ = try await request("social_interactions", "comment", .init(postID: postID, commentID: commentID, body: text))
            guard !Task.isCancelled, generation == token else { return }; writingComment = false; text = ""; commentID = UUID(); await load(); NotificationCenter.default.post(name: .socialEngagementChanged, object: nil)
        } catch is CancellationError { } catch { if generation == token { deliveryFailed = true } }
    }
    private func remove(_ comment: SocialComment) async {
        guard let request else { return }; busy = true
        defer { busy = false }
        do { _ = try await request("social_interactions", "deleteComment", .init(postID: postID, commentID: comment.id)); await load(); NotificationCenter.default.post(name: .socialEngagementChanged, object: nil) }
        catch is CancellationError { } catch { failed = true }
    }
}
