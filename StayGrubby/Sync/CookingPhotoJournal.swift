import Foundation

/// A separate account-root transfer checkpoint. No SwiftData/domain schema changes.
/// Remote immutable manifests and tombstones also make the work reconstructible.
nonisolated struct CookingPhotoJournal: Codable {
    struct Entry: Codable {
        var manifest: CookingPhotoManifest?
        var phase = "pending"
        var attempts = 0
        var diagnostic: String?
        var retryAt: Date?
        /// Object paths whose bytes are already stored and verified for this manifest. A retry after an
        /// ambiguous failure resumes only the missing work (optional: older journals decode as nil).
        var verifiedPaths: [String]?
    }
    let accountID: UUID
    var entries: [String: Entry] = [:]
    /// The accepted cloud revision at the last photo pass that finished with nothing outstanding.
    /// While the revision is unchanged and every photo is on disk, the pass needs no network.
    var settledRevision: Int?
    static func url(root: URL) -> URL { root.appendingPathComponent("CookingPhotoTransfers.json") }
    static func load(owner: UUID, root: URL) throws -> Self {
        let file = url(root: root)
        guard (try? file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else { throw CookingPhotoError.integrity }
        guard FileManager.default.fileExists(atPath: file.path) else { return Self(accountID: owner) }
        let value = try JSONDecoder().decode(Self.self, from: Data(contentsOf: file))
        guard value.accountID == owner else { throw SyncFoundationError.wrongAccount }
        for (key, entry) in value.entries {
            guard UUID(uuidString: key) != nil else { throw CookingPhotoError.integrity }
            if let manifest = entry.manifest { try manifest.validate(owner: owner); guard manifest.mediaID == UUID(uuidString: key) else { throw CookingPhotoError.integrity } }
        }
        return value
    }
    func save(root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: Self.url(root: root), options: .atomic)
    }
    var retryAt: Date? { entries.values.compactMap(\.retryAt).min() }
    /// Anything not yet verified/cleaned, or waiting on a retry.
    var hasOutstandingWork: Bool {
        entries.values.contains { !["verified", "cleaned"].contains($0.phase) || $0.retryAt != nil || $0.diagnostic != nil }
    }
}
