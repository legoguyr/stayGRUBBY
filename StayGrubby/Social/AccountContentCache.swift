import SwiftUI
import UIKit
import ImageIO
import CryptoKit

/// Account-scoped read caches (MVP stabilization, November 16, 2026; STAYGRUBBY_ARCHITECTURE "Read caching").
///
/// - Screens show the last good result immediately and refresh in the background, without a loading
///   screen, only when the result is older than `maximumAge` or something actually changed
///   (pull to refresh, a local write's notification, Retry). Tab switches and back navigation
///   never clear or refetch fresh data.
/// - Identical concurrent reads share one request (`coalesced`).
/// - Remote media bytes (Sous Chef post photos, avatars, Recipe photos) are immutable per path or asset
///   identity, so they are cached by that key in a bounded memory tier and a bounded disk tier inside the
///   account's own root (excluded from backup, removed with the account; never shared across accounts).
/// - Nothing here is canonical: the cloud and the local SwiftData library stay the source of truth.
///   Caches are a convenience that may be dropped at any time.
@MainActor final class AccountContentCache {
    static let maximumAge: TimeInterval = 120
    let media: RemoteMediaCache
    var cookbook = CachedRead<[CookbookEntry]>()
    var savedRecipes = CachedRead<[RecipeTicket]>()
    var pass = CachedRead<PassSnapshot>()
    /// The Dish's own Recipe (nil = known to have none), keyed by Dish identity. Bounded.
    private var dishRecipes: [UUID: CachedRead<Recipe?>] = [:]
    private var inFlight: [String: Task<Data, Error>] = [:]
    static let dishRecipeLimit = 200

    private var observers: [NSObjectProtocol] = []

    init(mediaDirectory: URL?) {
        media = RemoteMediaCache(directory: mediaDirectory)
        // Any content write anywhere in the app withdraws freshness (values stay for display), so the
        // next appearance of an affected screen refreshes even if that screen never saw the notification.
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: .socialContentChanged, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.invalidateRecipes(); self?.pass.invalidate() }
            },
            center.addObserver(forName: .recipeSavesChanged, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.savedRecipes.invalidate() }
            },
            center.addObserver(forName: .socialEngagementChanged, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.pass.invalidate() }
            },
        ]
    }
    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }

    func dishRecipe(_ dishID: UUID) -> CachedRead<Recipe?>? { dishRecipes[dishID] }
    func storeDishRecipe(_ recipe: Recipe?, for dishID: UUID, now: Date = .now) {
        if dishRecipes[dishID] == nil, dishRecipes.count >= Self.dishRecipeLimit,
           let oldest = dishRecipes.min(by: { ($0.value.fetchedAt ?? .distantPast) < ($1.value.fetchedAt ?? .distantPast) })?.key {
            dishRecipes.removeValue(forKey: oldest)
        }
        dishRecipes[dishID] = CachedRead(value: recipe, fetchedAt: now)
    }
    /// A content change (create/edit/delete/link/save) makes every cached Recipe read stale; the next
    /// appearance refreshes in the background while still showing what it had.
    func invalidateRecipes() {
        cookbook.invalidate(); savedRecipes.invalidate()
        for key in dishRecipes.keys { dishRecipes[key]?.invalidate() }
    }

    /// One in-flight request per key: a second identical read waits for the first.
    func coalesced(_ key: String, _ work: @escaping @MainActor () async throws -> Data) async throws -> Data {
        if let running = inFlight[key] { return try await running.value }
        let task = Task { @MainActor in try await work() }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        return try await task.value
    }
}

/// The last good value of a read and when it was fetched.
struct CachedRead<Value> {
    var value: Value?
    var fetchedAt: Date?
    var hasValue: Bool { fetchedAt != nil }
    func isFresh(now: Date = .now, maximumAge: TimeInterval = AccountContentCache.maximumAge) -> Bool {
        guard let fetchedAt else { return false }
        let age = now.timeIntervalSince(fetchedAt)
        return age >= 0 && age < maximumAge
    }
    mutating func store(_ next: Value, now: Date = .now) { value = next; fetchedAt = now }
    /// Keeps the value for display; only its freshness is withdrawn.
    mutating func invalidate() { if fetchedAt != nil { fetchedAt = .distantPast } }
}

/// The Pass's first page and the viewer context it was loaded with.
struct PassSnapshot {
    var posts: [SocialPost]
    var cursor: PassPage.Cursor?
    var hasMore: Bool
    var identity: SocialIdentity
    var friendCount: Int
}

/// Bounded two-tier cache of immutable remote media bytes plus decoded images.
@MainActor final class RemoteMediaCache {
    static let memoryLimit = 48 * 1_024 * 1_024
    static let diskLimit = 120 * 1_024 * 1_024
    private let directory: URL?
    private let bytes = NSCache<NSString, NSData>()
    private let images = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<Data, Error>] = [:]
    private var diskWrites = 0

    init(directory: URL?) {
        self.directory = directory
        bytes.totalCostLimit = Self.memoryLimit
        images.totalCostLimit = Self.memoryLimit
        if let directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            var url = directory; try? url.setResourceValues(values)
        }
    }

    /// Cached bytes for `key`, from memory or disk.
    func data(_ key: String) -> Data? {
        if let hit = bytes.object(forKey: key as NSString) { return hit as Data }
        guard let file = file(key), let data = try? Data(contentsOf: file) else { return nil }
        // Recency for least-recently-used trimming.
        try? FileManager.default.setAttributes([.modificationDate: Date.now], ofItemAtPath: file.path)
        bytes.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        return data
    }
    /// A decoded image already in memory (synchronous: lets a view render without a placeholder flash).
    func image(_ key: String) -> UIImage? { images.object(forKey: key as NSString) }
    func storeImage(_ image: UIImage, key: String) {
        let cost = Int(image.size.width * image.scale * image.size.height * image.scale * 4)
        images.setObject(image, forKey: key as NSString, cost: cost)
    }
    func store(_ data: Data, key: String) {
        bytes.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        guard let file = file(key) else { return }
        try? data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        diskWrites += 1
        if diskWrites % 20 == 1 { trimDisk() }
    }
    /// Cached bytes, else one shared fetch whose result is cached.
    func load(_ key: String, fetch: @escaping @MainActor () async throws -> Data) async throws -> Data {
        if let hit = data(key) { return hit }
        if let running = inFlight[key] { return try await running.value }
        let task = Task { @MainActor in try await fetch() }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let result = try await task.value
        store(result, key: key)
        return result
    }
    func remove(_ key: String) {
        bytes.removeObject(forKey: key as NSString); images.removeObject(forKey: key as NSString)
        if let file = file(key) { try? FileManager.default.removeItem(at: file) }
    }
    /// Least-recently-used trimming down to 80% of the disk limit.
    func trimDisk(limit: Int = RemoteMediaCache.diskLimit) {
        guard let directory, let files = try? FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else { return }
        let entries = files.compactMap { url -> (URL, Int, Date)? in
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }
        var total = entries.reduce(0) { $0 + $1.1 }
        guard total > limit else { return }
        for (url, size, _) in entries.sorted(by: { $0.2 < $1.2 }) where total > limit * 4 / 5 {
            try? FileManager.default.removeItem(at: url); total -= size
        }
    }
    private func file(_ key: String) -> URL? {
        guard let directory else { return nil }
        let name = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name, isDirectory: false)
    }
    /// Decodes bounded-size JPEG bytes once; callers cache the result with `storeImage`.
    nonisolated static func decode(_ data: Data, maximumPixels: Int = 2_048) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixels, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary)
        else { return nil }
        return UIImage(cgImage: image)
    }
}

private struct AccountContentCacheKey: EnvironmentKey { static let defaultValue: AccountContentCache? = nil }
extension EnvironmentValues {
    var accountContentCache: AccountContentCache? {
        get { self[AccountContentCacheKey.self] } set { self[AccountContentCacheKey.self] = newValue }
    }
}

/// Keeps one cache per signed-in account for the lifetime of the account tree.
@MainActor final class AccountContentCacheRegistry {
    private var account: UUID?
    private var current: AccountContentCache?
    func cache(for account: UUID, root: URL?) -> AccountContentCache {
        if let current, self.account == account { return current }
        let next = AccountContentCache(mediaDirectory: root?.appendingPathComponent("RemoteMediaCache", isDirectory: true))
        self.account = account; current = next
        return next
    }
    func reset() { account = nil; current = nil }
}
