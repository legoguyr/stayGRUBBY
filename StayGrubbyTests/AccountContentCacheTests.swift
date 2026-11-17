import Foundation
import UIKit
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
        #expect(reopened.data("social-photos/a/b.jpg") == bytes && reopened.diskUsage == 1_000)
        #expect((try? root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup) == true)
        reopened.remove("social-photos/a/b.jpg")
        #expect(reopened.diskUsage == 0)
        #expect(RemoteMediaCache(directory: root).data("social-photos/a/b.jpg") == nil)
        #expect(RemoteMediaCache(directory: nil).data("social-photos/a/b.jpg") == nil, "No disk tier without an account directory")
    }

    @Test func diskLimitIsHardAndEvictsLeastRecentlyUsedFirst() throws {
        let root = try scratch(); defer { try? FileManager.default.removeItem(at: root) }
        let cache = RemoteMediaCache(directory: root, diskLimit: 5_000)
        for index in 0..<5 { cache.store(Data(repeating: UInt8(index), count: 1_000), key: "k\(index)") }
        _ = cache.data("k0") // k0 becomes the most recent; k1 is now the oldest.
        for index in 5..<12 {
            cache.store(Data(repeating: UInt8(index), count: 1_000), key: "k\(index)")
            #expect(cache.diskUsage <= 5_000, "Never above the budget, even between writes")
        }
        #expect(cache.diskEntryCount == 5)
        #expect(cache.data("k11") != nil && cache.data("k1") == nil)
        let onDisk = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey])
            .reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        #expect(onDisk <= 5_000, "The files themselves respect the budget")
        cache.store(Data(count: 6_000), key: "too-big")
        #expect(cache.data("too-big") == nil && cache.diskUsage <= 5_000, "An item larger than the budget is never kept")
    }

    @Test func memoryLimitIsHardAndLeastRecentlyUsed() {
        let lru = MemoryLRU<Int>(limit: 100)
        lru.insert(1, key: "a", cost: 40); lru.insert(2, key: "b", cost: 40)
        _ = lru.value("a")
        lru.insert(3, key: "c", cost: 40)
        #expect(lru.totalCost <= 100 && lru.value("b") == nil && lru.value("a") == 1 && lru.value("c") == 3)
        lru.insert(4, key: "huge", cost: 101)
        #expect(lru.value("huge") == nil && lru.totalCost <= 100)
        let cache = RemoteMediaCache(directory: nil, memoryLimit: 1_000)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10), format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()).image { _ in }
        for index in 0..<10 { cache.storeImage(image, key: "i\(index)") } // 400 bytes each
        #expect(cache.memoryUsage <= 1_000)
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        #expect(cache.memoryUsage == 0, "Memory pressure releases decoded images")
    }

    @Test func startupRemovesExpiredAndOrphanedFiles() throws {
        let root = try scratch(); defer { try? FileManager.default.removeItem(at: root) }
        let cache = RemoteMediaCache(directory: root)
        cache.store(Data(repeating: 1, count: 100), key: "fresh"); cache.store(Data(repeating: 2, count: 100), key: "old")
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        let old = try #require(files.first { (try? Data(contentsOf: $0)) == Data(repeating: 2, count: 100) })
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -RemoteMediaCache.expiry - 60)], ofItemAtPath: old.path)
        try Data("partial".utf8).write(to: root.appendingPathComponent(".tmp-interrupted"))
        try Data("x".utf8).write(to: root.appendingPathComponent("not-a-cache-file.jpg"))
        let reopened = RemoteMediaCache(directory: root)
        #expect(reopened.data("fresh") != nil && reopened.data("old") == nil)
        #expect(try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).count == 1)
        #expect(reopened.diskUsage == 100)
    }

    @Test func accountCachesAreIsolatedAndRemovedOnSwitchSignOutAndDeletion() throws {
        let base = try scratch(); defer { try? FileManager.default.removeItem(at: base) }
        let a = UUID(), b = UUID()
        let dirA = try #require(RemoteMediaCacheLocation.directory(for: a, base: base))
        let dirB = try #require(RemoteMediaCacheLocation.directory(for: b, base: base))
        #expect(dirA != dirB)
        RemoteMediaCache(directory: dirA).store(Data([1]), key: "p"); RemoteMediaCache(directory: dirB).store(Data([2]), key: "p")
        #expect(RemoteMediaCache(directory: dirA).data("p") == Data([1]), "One account never reads another's entry")
        // A foreign item in the cache folder is never touched.
        let foreign = try #require(RemoteMediaCacheLocation.root(base: base)).appendingPathComponent("keep-me")
        try Data([9]).write(to: foreign)
        RemoteMediaCacheLocation.removeAll(except: b, base: base) // switch to B
        #expect(!FileManager.default.fileExists(atPath: dirA.path) && FileManager.default.fileExists(atPath: dirB.path))
        RemoteMediaCacheLocation.removeAll(except: nil, base: base) // sign-out
        #expect(!FileManager.default.fileExists(atPath: dirB.path) && FileManager.default.fileExists(atPath: foreign.path))
        RemoteMediaCache(directory: dirA).store(Data([1]), key: "p")
        RemoteMediaCacheLocation.remove(a, base: base) // account deletion
        #expect(!FileManager.default.fileExists(atPath: dirA.path))
    }

    @Test func accountDeletionAndLegacyCleanupNeverTouchOriginalPhotosOrJournals() throws {
        let base = try scratch(); defer { try? FileManager.default.removeItem(at: base) }
        let account = UUID()
        let accountRoot = LocalAccountDataDeletion.directory(for: account, root: base)
        let originals = accountRoot.appendingPathComponent("StayGrubbyMedia", isDirectory: true)
        try FileManager.default.createDirectory(at: originals, withIntermediateDirectories: true)
        try Data([1]).write(to: originals.appendingPathComponent("photo-display.jpg"))
        try Data("{}".utf8).write(to: accountRoot.appendingPathComponent("CookingPhotoTransfers.json"))
        let legacy = accountRoot.appendingPathComponent("RemoteMediaCache", isDirectory: true)
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        RemoteMediaCacheLocation.removeLegacy(accountRoot: accountRoot)
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
        #expect(FileManager.default.fileExists(atPath: originals.appendingPathComponent("photo-display.jpg").path))
        #expect(FileManager.default.fileExists(atPath: accountRoot.appendingPathComponent("CookingPhotoTransfers.json").path))
        RemoteMediaCacheLocation.removeLegacy(accountRoot: base) // Not an account root: refused.
        #expect(FileManager.default.fileExists(atPath: base.path))
        let cacheDir = try #require(RemoteMediaCacheLocation.directory(for: account, base: base))
        RemoteMediaCache(directory: cacheDir).store(Data([1]), key: "p")
        try LocalAccountDataDeletion.remove(account, root: base)
        #expect(!FileManager.default.fileExists(atPath: cacheDir.path), "Deleting the account removes its cache")
    }

    @Test func concurrentLoadsOfOneKeyShareOneFetch() async throws {
        let root = try scratch(); defer { try? FileManager.default.removeItem(at: root) }
        let cache = RemoteMediaCache(directory: root)
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
