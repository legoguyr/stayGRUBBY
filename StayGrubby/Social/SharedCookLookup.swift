import Foundation
import Observation

/// Cache keys include the excluded source post and server sort. Nothing is shared across accounts.
struct SharedCookCacheKey: Hashable {
    var postID: UUID
    var authorID: UUID
    var dishKey: String
    var order: SharedCookOrder
}

struct SharedCookPage {
    struct Cursor {
        var createdAt: Double
        var id: UUID
        var score: Double
    }
    static let size = 25
    var posts: [SocialPost] = []
    var cursor: Cursor?
    var hasMore = false

    init() {}
    init(rows: [SocialPost], source: SocialPost, order: SharedCookOrder) {
        posts = SharedCookOrder.otherCooks(of: source, among: rows, order: order)
        // Use the raw server page for progress, including any filtered item.
        cursor = rows.last.map { Cursor(createdAt: $0.createdAt, id: $0.id, score: SharedCookOrder.score($0) ?? -1) }
        hasMore = rows.count == Self.size
    }
}

/// The single exact-Dish integration point. Older cards without identity offer no inferred siblings.
@MainActor enum SharedCookLookup {
    static func key(for post: SocialPost, order: SharedCookOrder) -> SharedCookCacheKey? {
        guard let key = post.dishKey, !key.isEmpty else { return nil }
        return SharedCookCacheKey(postID: post.id, authorID: post.author.id, dishKey: key, order: order)
    }

    static func page(for post: SocialPost, order: SharedCookOrder, after cursor: SharedCookPage.Cursor? = nil,
                     request: @escaping SocialRequest, cache: AccountContentCache?) async throws -> SharedCookPage {
        guard let key = key(for: post, order: order) else { return SharedCookPage() }
        var payload = SocialPayload(postID: post.id)
        payload.order = order.rawValue
        payload.beforeTime = cursor?.createdAt
        payload.beforeID = cursor?.id
        if order == .highestRated { payload.beforeScore = cursor?.score }
        let parameters = payload
        let fetch: @MainActor () async throws -> Data = { try await request("social_feed", "dish", parameters) }
        let data: Data
        if let cache {
            let position = cursor.map { "\($0.createdAt)/\($0.id)/\($0.score)" } ?? "first"
            data = try await cache.coalesced("dish-cooks/\(key.postID)/\(key.dishKey)/\(order.rawValue)/\(position)", fetch)
        } else { data = try await fetch() }
        try Task.checkCancellation()
        let rows = try JSONDecoder().decode(SocialPostsPage.self, from: data).posts
        guard rows.count <= SharedCookPage.size else { throw URLError(.cannotParseResponse) }
        return SharedCookPage(rows: rows, source: post, order: order)
    }

    nonisolated static func sameDish(_ candidate: SocialPost, as post: SocialPost) -> Bool {
        guard candidate.author.id == post.author.id, let key = post.dishKey, !key.isEmpty else { return false }
        return candidate.dishKey == key
    }
}

/// Loaded pages belong to this screen. Only bounded first pages enter the account read cache.
@MainActor @Observable final class SharedCooksModel {
    private(set) var posts: [SocialPost]?
    private(set) var hasMore = false
    private(set) var loading = false
    private(set) var failed = false
    private var cursor: SharedCookPage.Cursor?
    private var generation = UUID()

    func load(for post: SocialPost, order: SharedCookOrder, more: Bool = false, force: Bool = false,
              request: @escaping SocialRequest, cache: AccountContentCache?) async {
        if more, loading || !hasMore { return }
        let token = UUID()
        generation = token
        let key = SharedCookLookup.key(for: post, order: order)
        if !more {
            posts = nil
            cursor = nil
            hasMore = false
            if !force, let key, let hit = cache?.sharedCooks(key), let page = hit.value {
                apply(page, more: false)
                if hit.isFresh() {
                    failed = false
                    loading = false
                    return
                }
            }
        }
        loading = true
        failed = false
        defer { if generation == token { loading = false } }
        do {
            let page = try await SharedCookLookup.page(for: post, order: order, after: more ? cursor : nil,
                                                       request: request, cache: cache)
            guard !Task.isCancelled, generation == token else { return }
            apply(page, more: more)
            if !more, let key { cache?.storeSharedCooks(page, for: key) }
        } catch is CancellationError {
        } catch {
            guard generation == token, !Task.isCancelled else { return }
            // Revoked access and failed refreshes cannot leave an apparently current sibling list.
            posts = nil
            hasMore = false
            failed = true
            if let key { cache?.removeSharedCooks(key) }
        }
    }

    private func apply(_ page: SharedCookPage, more: Bool) {
        var seen = Set((more ? posts ?? [] : []).map(\.id))
        let added = page.posts.filter { seen.insert($0.id).inserted }
        posts = (more ? posts ?? [] : []) + added
        hasMore = page.hasMore
        cursor = page.cursor
    }
}
