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

/// A strict least-recently-used memory store: total cost never exceeds `limit` after an insert, and
/// an item larger than the whole limit is never kept.
@MainActor final class MemoryLRU<Value> {
    let limit: Int
    private var entries: [String: (value: Value, cost: Int, tick: UInt64)] = [:]
    private var tick: UInt64 = 0
    private(set) var totalCost = 0
    var count: Int { entries.count }
    init(limit: Int) { self.limit = limit }
    func value(_ key: String) -> Value? {
        guard var entry = entries[key] else { return nil }
        tick += 1; entry.tick = tick; entries[key] = entry
        return entry.value
    }
    func insert(_ value: Value, key: String, cost: Int) {
        remove(key)
        guard cost >= 0, cost <= limit else { return }
        tick += 1; entries[key] = (value, cost, tick); totalCost += cost
        while totalCost > limit, let oldest = entries.min(by: { $0.value.tick < $1.value.tick })?.key { remove(oldest) }
    }
    func remove(_ key: String) { if let old = entries.removeValue(forKey: key) { totalCost -= old.cost } }
    func removeAll() { entries.removeAll(); totalCost = 0 }
}

/// Where remote media caches live: `Library/Caches/StayGrubbyRemoteMedia/<account>/`. Caches is excluded
/// from backup and iOS may reclaim it under storage pressure; everything here is regenerable from
/// Storage. Only directories this type created (a UUID name inside its own folder) are ever removed.
/// Original photos (`StayGrubbyMedia`), sync journals and outboxes live in the account root and are never touched.
nonisolated enum RemoteMediaCacheLocation {
    static let folder = "StayGrubbyRemoteMedia"
    static func root(base: URL? = nil) -> URL? {
        (base ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first)?.appendingPathComponent(folder, isDirectory: true)
    }
    static func directory(for account: UUID, base: URL? = nil) -> URL? {
        root(base: base)?.appendingPathComponent(account.uuidString.lowercased(), isDirectory: true)
    }
    /// Account switch (`keep` = the new account) or sign-out (`keep` = nil): other accounts' caches go.
    static func removeAll(except keep: UUID?, base: URL? = nil) {
        guard let root = root(base: base), let children = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        for child in children {
            guard let id = UUID(uuidString: child.lastPathComponent), id != keep else { continue }
            try? FileManager.default.removeItem(at: child)
        }
    }
    /// Account deletion.
    static func remove(_ account: UUID, base: URL? = nil) {
        guard let directory = directory(for: account, base: base) else { return }
        try? FileManager.default.removeItem(at: directory)
    }
    /// The November 16 development build kept this cache inside the account root; it is regenerable.
    static func removeLegacy(accountRoot: URL?) {
        guard let legacy = accountRoot?.appendingPathComponent("RemoteMediaCache", isDirectory: true),
              legacy.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent == "StayGrubbyAccounts" else { return }
        try? FileManager.default.removeItem(at: legacy)
    }
}

/// Bounded cache of immutable remote media: decoded images in memory, verified bytes on disk.
/// Both limits are hard (enforced before an insert completes), eviction is least-recently-used,
/// entries unused for `expiry` and files the cache did not write are removed at startup, and the disk
/// budget shrinks when the device is low on storage.
@MainActor final class RemoteMediaCache {
    static let memoryLimit = 48 * 1_024 * 1_024
    static let diskLimit = 120 * 1_024 * 1_024
    /// The disk budget when the volume has less than `lowStorageThreshold` available.
    static let lowStorageDiskLimit = 24 * 1_024 * 1_024
    static let lowStorageThreshold: Int64 = 1_024 * 1_024 * 1_024
    static let expiry: TimeInterval = 30 * 24 * 3_600
    /// `order` is a monotonic recency counter (no clock ties); file dates carry recency across launches.
    private struct DiskEntry { var size: Int; var order: UInt64 }
    private var clock: UInt64 = 0
    private let directory: URL?
    let diskBudget: Int
    private let images: MemoryLRU<UIImage>
    private var index: [String: DiskEntry] = [:]
    private(set) var diskUsage = 0
    private var inFlight: [String: Task<Data, Error>] = [:]
    private var memoryObserver: NSObjectProtocol?
    var memoryUsage: Int { images.totalCost }
    var diskEntryCount: Int { index.count }

    init(directory: URL?, memoryLimit: Int = RemoteMediaCache.memoryLimit, diskLimit: Int? = nil, now: Date = .now) {
        self.directory = directory
        images = MemoryLRU(limit: memoryLimit)
        diskBudget = diskLimit ?? Self.adaptiveDiskLimit(for: directory)
        memoryObserver = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.images.removeAll() }
        }
        guard let directory else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        var url = directory; try? url.setResourceValues(values)
        rebuildIndex(now: now)
    }
    deinit { if let memoryObserver { NotificationCenter.default.removeObserver(memoryObserver) } }

    /// 120 MB normally; 24 MB when the device is low on space.
    nonisolated static func adaptiveDiskLimit(for directory: URL?) -> Int {
        guard let directory, let available = try? directory.deletingLastPathComponent()
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage,
              available > 0 else { return diskLimit }
        return available < lowStorageThreshold ? lowStorageDiskLimit : diskLimit
    }

    /// Indexes the directory: drops files the cache did not write (orphans, interrupted temp files)
    /// and entries unused for `expiry`, then enforces the budget.
    private func rebuildIndex(now: Date) {
        guard let directory, let files = try? FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey], options: []) else { return }
        index = [:]; diskUsage = 0
        var found: [(String, Int, Date)] = []
        for url in files {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey])
            let name = url.lastPathComponent
            let date = values?.contentModificationDate ?? .distantPast
            guard values?.isRegularFile == true, Self.isCacheName(name), now.timeIntervalSince(date) < Self.expiry else {
                try? FileManager.default.removeItem(at: url); continue
            }
            found.append((name, values?.fileSize ?? 0, date))
        }
        for (name, size, _) in found.sorted(by: { $0.2 < $1.2 }) {
            clock += 1; index[name] = DiskEntry(size: size, order: clock); diskUsage += size
        }
        evict(toFit: 0)
    }
    nonisolated static func isCacheName(_ name: String) -> Bool {
        name.count == 64 && name.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    /// Cached bytes for `key` from disk.
    func data(_ key: String) -> Data? {
        guard let (name, file) = location(key), index[name] != nil else { return nil }
        guard let data = try? Data(contentsOf: file) else { index[name].map { diskUsage -= $0.size }; index[name] = nil; return nil }
        clock += 1; index[name]?.order = clock
        try? FileManager.default.setAttributes([.modificationDate: Date.now], ofItemAtPath: file.path) // Recency survives relaunch.
        return data
    }
    /// A decoded image already in memory (synchronous: lets a view render without a placeholder flash).
    func image(_ key: String) -> UIImage? { images.value(key) }
    func storeImage(_ image: UIImage, key: String) {
        images.insert(image, key: key, cost: Int(image.size.width * image.scale * image.size.height * image.scale * 4))
    }
    func store(_ data: Data, key: String) {
        guard let (name, file) = location(key) else { return }
        removeEntry(name, file: file)
        guard data.count <= diskBudget else { return }
        evict(toFit: data.count)
        do {
            try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            clock += 1; index[name] = DiskEntry(size: data.count, order: clock); diskUsage += data.count
        } catch { try? FileManager.default.removeItem(at: file) }
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
        images.remove(key)
        if let (name, file) = location(key) { removeEntry(name, file: file) }
    }
    /// Least-recently-used eviction until `incoming` more bytes fit within the budget.
    private func evict(toFit incoming: Int) {
        guard let directory else { return }
        while diskUsage + incoming > diskBudget, let oldest = index.min(by: { $0.value.order < $1.value.order })?.key {
            removeEntry(oldest, file: directory.appendingPathComponent(oldest, isDirectory: false))
        }
    }
    private func removeEntry(_ name: String, file: URL) {
        if let entry = index.removeValue(forKey: name) { diskUsage -= entry.size }
        try? FileManager.default.removeItem(at: file)
    }
    private func location(_ key: String) -> (String, URL)? {
        guard let directory else { return nil }
        let name = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return (name, directory.appendingPathComponent(name, isDirectory: false))
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

/// Keeps one cache per signed-in account for the lifetime of the account tree. Opening an account
/// removes every other account's media cache (account switch) and the legacy in-root location.
@MainActor final class AccountContentCacheRegistry {
    private var account: UUID?
    private var current: AccountContentCache?
    func cache(for account: UUID, root: URL?) -> AccountContentCache {
        if let current, self.account == account { return current }
        RemoteMediaCacheLocation.removeAll(except: account)
        RemoteMediaCacheLocation.removeLegacy(accountRoot: root)
        let next = AccountContentCache(mediaDirectory: RemoteMediaCacheLocation.directory(for: account))
        self.account = account; current = next
        return next
    }
    /// The account tree closed (sign-out, deletion or restore); disk caches stay until sign-out/switch.
    func reset() { account = nil; current = nil }
}
