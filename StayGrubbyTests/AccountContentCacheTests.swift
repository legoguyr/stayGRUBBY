import Foundation
import Testing
@testable import StayGrubby

/// Read caching (MVP stabilization, November 16, 2026): freshness, invalidation, bounds and coalescing.
@MainActor struct AccountContentCacheTests {
    private func scratch() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cache-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func freshnessExpiresAndInvalidationKeepsTheValueForDisplay() {
        var read = CachedRead<[Int]>()
        #expect(!read.hasValue && !read.isFresh())
        let now = Date()
        read.store([1, 2], now: now)
        #expect(read.isFresh(now: now.addingTimeInterval(30)))
        #expect(!read.isFresh(now: now.addingTimeInterval(AccountContentCache.maximumAge + 1)))
        read.invalidate()
        #expect(read.value == [1, 2] && read.hasValue && !read.isFresh(now: now))
    }

    @Test func contentChangeNotificationsWithdrawFreshness() {
        let cache = AccountContentCache(mediaDirectory: nil)
        let dish = UUID()
        cache.cookbook.store([]); cache.pass.store(PassSnapshot(posts: [], cursor: nil, hasMore: false,
            identity: SocialIdentity(displayName: "Cook", username: nil, discoverable: false), friendCount: 0))
        cache.storeDishRecipe(nil, for: dish)
        #expect(cache.cookbook.isFresh() && cache.pass.isFresh() && cache.dishRecipe(dish)?.isFresh() == true)
        NotificationCenter.default.post(name: .socialContentChanged, object: nil)
        #expect(!cache.cookbook.isFresh() && !cache.pass.isFresh() && cache.dishRecipe(dish)?.isFresh() == false)
        #expect(cache.dishRecipe(dish)?.hasValue == true, "Known-no-Recipe stays known for display")
        cache.savedRecipes.store([])
        NotificationCenter.default.post(name: .recipeSavesChanged, object: nil)
        #expect(!cache.savedRecipes.isFresh())
    }

    @Test func dishRecipeCacheIsBounded() {
        let cache = AccountContentCache(mediaDirectory: nil)
        let start = Date()
        let first = UUID()
        cache.storeDishRecipe(nil, for: first, now: start)
        for index in 1...AccountContentCache.dishRecipeLimit { cache.storeDishRecipe(nil, for: UUID(), now: start.addingTimeInterval(Double(index))) }
        #expect(cache.dishRecipe(first) == nil, "Oldest entry evicted at the bound")
    }

    @Test func mediaBytesPersistPerAccountDirectoryAndSurviveMemoryLoss() throws {
        let root = try scratch(); defer { try? FileManager.default.removeItem(at: root) }
        let bytes = Data(repeating: 7, count: 1_000)
        RemoteMediaCache(directory: root).store(bytes, key: "social-photos/a/b.jpg")
        let reopened = RemoteMediaCache(directory: root)
        #expect(reopened.data("social-photos/a/b.jpg") == bytes)
        #expect((try? root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup) == true)
        reopened.remove("social-photos/a/b.jpg")
        #expect(RemoteMediaCache(directory: root).data("social-photos/a/b.jpg") == nil)
        #expect(RemoteMediaCache(directory: nil).data("social-photos/a/b.jpg") == nil, "No disk tier without an account root")
    }

    @Test func diskTrimRemovesLeastRecentlyUsedFirst() throws {
        let root = try scratch(); defer { try? FileManager.default.removeItem(at: root) }
        let cache = RemoteMediaCache(directory: root)
        for index in 0..<10 { cache.store(Data(repeating: UInt8(index), count: 1_000), key: "k\(index)") }
        // Age every file, then touch k9 so it is the most recent.
        for file in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -3_600)], ofItemAtPath: file.path)
        }
        let fresh = RemoteMediaCache(directory: root)
        _ = fresh.data("k9")
        fresh.trimDisk(limit: 5_000)
        let remaining = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).count
        #expect(remaining <= 4)
        #expect(RemoteMediaCache(directory: root).data("k9") != nil, "Most recently used survives")
    }

    @Test func concurrentLoadsOfOneKeyShareOneFetch() async throws {
        let cache = RemoteMediaCache(directory: nil)
        var fetches = 0
        let fetch: @MainActor () async throws -> Data = { fetches += 1; try await Task.sleep(for: .milliseconds(50)); return Data([1]) }
        async let first = cache.load("p", fetch: fetch)
        async let second = cache.load("p", fetch: fetch)
        let values = try await [first, second]
        #expect(values == [Data([1]), Data([1])])
        #expect(fetches == 1)
        _ = try await cache.load("p", fetch: fetch)
        #expect(fetches == 1, "Later loads are served from the cache")
    }
}
