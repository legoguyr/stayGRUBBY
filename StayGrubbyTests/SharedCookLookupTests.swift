import Foundation
import Testing
@testable import StayGrubby

@MainActor struct SharedCookLookupTests {
    private let author = SocialPerson(id: UUID(), displayName: "Alex", username: "alex", relationship: .friends)
    private func post(key: String? = "dish-a", title: String = "Soup", score: String? = nil, time: Double = 1000) -> SocialPost {
        SocialPost(id: UUID(), author: author, title: title, versionTitle: nil, scoreText: score, achievement: nil,
                   createdAt: time, photoPath: nil, published: true, isAuthor: false, moderationState: "active", dishKey: key)
    }
    private func encoded(_ posts: [SocialPost]) throws -> Data { try JSONEncoder().encode(SocialPostsPage(posts: posts)) }

    @Test func oldCardsDecodeAndDoNotGuessOrRequestSiblings() async throws {
        let legacy = post(key: nil)
        let object = try JSONSerialization.jsonObject(with: encoded([legacy])) as! [String: Any]
        let decoded = try JSONDecoder().decode(SocialPostsPage.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.posts[0].dishKey == nil)
        var calls = 0
        let request: SocialRequest = { _, _, _ in calls += 1; return try encoded([]) }
        let page = try await SharedCookLookup.page(for: legacy, order: .recent, request: request, cache: nil)
        #expect(page.posts.isEmpty && !page.hasMore && calls == 0)
    }

    @Test func exactEndpointUsesServerOrderAndRawCursorWithLockedScores() async throws {
        let source = post()
        let rows = (0..<25).map { post(title: "Renamed soup", time: Double(900 - $0)) }
        var payloads: [SocialPayload] = []
        let request: SocialRequest = { endpoint, action, payload in
            #expect(endpoint == "social_feed" && action == "dish")
            payloads.append(payload)
            return try encoded(payload.beforeID == nil ? rows : [])
        }
        let page = try await SharedCookLookup.page(for: source, order: .highestRated, request: request, cache: nil)
        #expect(page.posts.count == 25 && page.hasMore)
        _ = try await SharedCookLookup.page(for: source, order: .highestRated, after: page.cursor, request: request, cache: nil)
        #expect(payloads[1].postID == source.id && payloads[1].order == "highestRated")
        #expect(payloads[1].beforeID == rows.last?.id && payloads[1].beforeTime == rows.last?.createdAt)
        #expect(payloads[1].beforeScore == -1 && rows.allSatisfy { $0.scoreText == nil })
    }

    @Test func pagesAppendWithoutDuplicatesAndChangingSortStartsAtTheFirstPage() async throws {
        let source = post(), model = SharedCooksModel()
        let rows = (0..<25).map { post(score: "7.0", time: Double(900 - $0)) }
        let tail = post(time: 800)
        var payloads: [SocialPayload] = []
        let request: SocialRequest = { _, _, payload in
            payloads.append(payload)
            return try encoded(payload.beforeID == nil ? rows : [rows.last!, tail])
        }
        await model.load(for: source, order: .recent, request: request, cache: nil)
        await model.load(for: source, order: .recent, more: true, request: request, cache: nil)
        #expect(model.posts?.count == 26 && !model.hasMore && !model.failed)
        await model.load(for: source, order: .highestRated, request: request, cache: nil)
        #expect(payloads.last?.beforeID == nil && payloads.last?.order == "highestRated")
        #expect(model.posts?.count == 25)
    }

    @Test func firstPageCachesAreScopedBoundedAndInvalidated() async throws {
        let cache = AccountContentCache(mediaDirectory: nil), source = post(), model = SharedCooksModel()
        var calls = 0
        let request: SocialRequest = { _, _, _ in calls += 1; return try encoded([post()]) }
        await model.load(for: source, order: .recent, request: request, cache: cache)
        await model.load(for: source, order: .recent, request: request, cache: cache)
        #expect(calls == 1)
        await model.load(for: source, order: .highestRated, request: request, cache: cache)
        #expect(calls == 2)
        NotificationCenter.default.post(name: .socialContentChanged, object: nil)
        await model.load(for: source, order: .recent, request: request, cache: cache)
        #expect(calls == 3)
        let key = try #require(SharedCookLookup.key(for: source, order: .recent))
        #expect(AccountContentCache(mediaDirectory: nil).sharedCooks(key) == nil)
        let now = Date()
        cache.storeSharedCooks(SharedCookPage(), for: key, now: now)
        for n in 1...AccountContentCache.sharedCookPagesLimit {
            let other = SharedCookCacheKey(postID: UUID(), authorID: author.id, dishKey: "dish", order: .recent)
            cache.storeSharedCooks(SharedCookPage(), for: other, now: now.addingTimeInterval(Double(n)))
        }
        #expect(cache.sharedCooks(key) == nil)
    }

    @Test func staleFirstPageStaysVisibleDuringTheBackgroundRefresh() async throws {
        let cache = AccountContentCache(mediaDirectory: nil), source = post(), model = SharedCooksModel()
        let old = post(), next = post(time: 1100)
        let key = try #require(SharedCookLookup.key(for: source, order: .recent))
        cache.storeSharedCooks(SharedCookPage(rows: [old], source: source, order: .recent), for: key,
                              now: Date(timeIntervalSinceNow: -AccountContentCache.maximumAge - 1))
        let request: SocialRequest = { _, _, _ in
            #expect(model.posts?.map(\.id) == [old.id] && model.loading)
            return try encoded([next])
        }
        await model.load(for: source, order: .recent, request: request, cache: cache)
        #expect(model.posts?.map(\.id) == [next.id] && !model.loading)
    }

    @Test func failedRefreshRemovesStaleResultsAndRetryRecovers() async throws {
        let cache = AccountContentCache(mediaDirectory: nil), source = post(), model = SharedCooksModel()
        let good: SocialRequest = { _, _, _ in try encoded([post()]) }
        await model.load(for: source, order: .recent, request: good, cache: cache)
        let denied: SocialRequest = { _, _, _ in throw URLError(.userAuthenticationRequired) }
        await model.load(for: source, order: .recent, force: true, request: denied, cache: cache)
        #expect(model.posts == nil && model.failed && !model.hasMore)
        let key = try #require(SharedCookLookup.key(for: source, order: .recent))
        #expect(cache.sharedCooks(key) == nil)
        await model.load(for: source, order: .recent, force: true, request: good, cache: cache)
        #expect(model.posts?.count == 1 && !model.failed)
    }

    @Test func supersededRequestCannotReplaceTheNewSort() async throws {
        let source = post(), model = SharedCooksModel()
        let old = post(score: "5.0"), new = post(score: "9.0")
        let request: SocialRequest = { _, _, payload in
            if payload.order == "recent" { try await Task.sleep(for: .milliseconds(80)); return try encoded([old]) }
            return try encoded([new])
        }
        let first = Task { await model.load(for: source, order: .recent, request: request, cache: nil) }
        await Task.yield()
        await model.load(for: source, order: .highestRated, request: request, cache: nil)
        await first.value
        #expect(model.posts?.map(\.id) == [new.id] && !model.loading)
    }
}
