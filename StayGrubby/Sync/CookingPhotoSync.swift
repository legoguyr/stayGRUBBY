import Foundation
import SwiftData

/// Derived durable work: local active media + cloud manifests/tombstones, checkpointed
/// in the account root before suspension. This never stages structured mutations.
@MainActor enum CookingPhotoSync {
    static func run(store: LocalStoreSession, account: ProvisionedAccount, transport: any CookingPhotoTransport,
        forceRetry: Bool = false, allowDownloads: Bool = true, current: () throws -> Void) async throws -> Bool {
        guard store.scope == .account(account.accountID), let root = store.mediaRoot,
              root.lastPathComponent == account.accountID.uuidString.lowercased(),
              try SyncJournal.binding(store.container.mainContext)?.accountID == account.accountID,
              try SyncJournal.binding(store.container.mainContext)?.enabled == true
        else { throw SyncFoundationError.wrongAccount }
        var journal = try CookingPhotoJournal.load(owner: account.accountID, root: root)
        try current()
        // Settled: same accepted revision as the last clean pass and every photo still on disk. Photo
        // metadata only changes with a revision (structured sync), so there is nothing to list or move.
        let acceptedRevision = try SyncJournal.binding(store.container.mainContext)?.acceptedRevision
        if !forceRetry, let acceptedRevision, journal.settledRevision == acceptedRevision, !journal.hasOutstandingWork,
           try CookingGraphExport.snapshot(context: store.container.mainContext).media.allSatisfy({ media in
               try [false, true].allSatisfy { FileManager.default.fileExists(atPath: try CookingPhotoFiles.url(media: media, thumbnail: $0, root: root).path) }
           }) { return true }
        journal.settledRevision = nil
        let catalogKey = "00000000-0000-0000-0000-000000000000"
        if !forceRetry, let deadline = journal.entries[catalogKey]?.retryAt, deadline > .now { return false }
        var discovery = journal.entries[catalogKey] ?? .init()
        discovery.phase = "discovering"; discovery.attempts += 1
        journal.entries[catalogKey] = discovery; try journal.save(root: root)
        let catalog: CookingPhotoCatalog
        do {
            catalog = try await transport.catalog(action: "list", manifest: nil)
            try current(); try catalog.validate(owner: account.accountID)
            journal.entries.removeValue(forKey: catalogKey); try journal.save(root: root)
        } catch {
            discovery.diagnostic = (error as? CookingPhotoError)?.diagnostic ?? "photo-network"
            discovery.retryAt = SyncRetryPolicy.nextAttempt(after: error, attempt: discovery.attempts)
            journal.entries[catalogKey] = discovery; try journal.save(root: root); throw error
        }
        var complete = true
        // Server keeps paths after structured retirement, so cleanup is discoverable
        // even on another device or after an ambiguous deletion/restart.
        for retired in catalog.backups where retired.state == "deleted" {
            if !forceRetry, let deadline = journal.entries[retired.mediaID.uuidString]?.retryAt, deadline > .now { complete = false; continue }
            try await checkpoint(retired, root: root, journal: &journal) { _, _ in
                try current()
                try await transport.remove(paths: [retired.displayKey, retired.thumbnailKey])
                try current()
                let result = try await transport.catalog(action: "cleaned", manifest: retired)
                try current(); try result.validate(owner: account.accountID)
                guard !result.backups.contains(where: { $0.mediaID == retired.mediaID }) else { throw CookingPhotoError.pending }
            }
        }
        let accepted = Dictionary(uniqueKeysWithValues: catalog.backups.map { ($0.mediaID, $0) })
        let graph = try CookingGraphExport.snapshot(context: store.container.mainContext)
        for media in graph.media {
            try current()
            if !forceRetry, let entry = journal.entries[media.id.uuidString] {
                if ["photo-integrity", "photo-rejected", "photo-authentication"].contains(entry.diagnostic ?? "") {
                    throw entry.diagnostic == "photo-authentication" ? CookingPhotoError.authenticationRequired : CookingPhotoError.integrity
                }
                if let deadline = entry.retryAt, deadline > .now { complete = false; continue }
            }
            var manifest = accepted[media.id]
            let display = try CookingPhotoFiles.read(media: media, thumbnail: false, root: root)
            let thumbnail = try CookingPhotoFiles.read(media: media, thumbnail: true, root: root)
            if manifest == nil, let display, let thumbnail {
                manifest = try CookingPhotoManifest.make(owner: account.accountID, media: media, display: display, thumbnail: thumbnail)
            }
            guard let descriptor = manifest, descriptor.state != "deleted" else {
                // Another device may have metadata before the creator backed bytes up.
                complete = false
                var entry = journal.entries[media.id.uuidString] ?? .init()
                entry.diagnostic = "photo-pending"; entry.retryAt = .now.addingTimeInterval(30)
                journal.entries[media.id.uuidString] = entry; try journal.save(root: root)
                continue
            }
            try descriptor.validate(owner: account.accountID)
            try await checkpoint(descriptor, root: root, journal: &journal) { verified, markVerified in
                @MainActor func stillLive() throws {
                    try current()
                    guard try CookingGraphExport.snapshot(context: store.container.mainContext).media.contains(media) else { throw CookingPhotoError.obsolete }
                }
                try stillLive()
                if descriptor.state != "ready" {
                    guard let display, let thumbnail else { throw CookingPhotoError.pending }
                    try CookingPhotoFiles.validate(display, manifest: descriptor, media: media, thumbnail: false)
                    try CookingPhotoFiles.validate(thumbnail, manifest: descriptor, media: media, thumbnail: true)
                    let registered = try await transport.catalog(action: "register", manifest: descriptor)
                    try stillLive(); try registered.validate(owner: account.accountID)
                    guard let receipt = registered.backups.first(where: { $0.mediaID == media.id }),
                          descriptor.sameContent(as: receipt), receipt.state != "deleted" else { throw CookingPhotoError.integrity }
                    for (path, bytes) in [(descriptor.displayKey, display), (descriptor.thumbnailKey, thumbnail)] where !verified.contains(path) {
                        try stillLive()
                        // Reconcile an ambiguous earlier attempt before retransmitting: content-addressed paths
                        // only ever hold this manifest's bytes, so a same-size object needs verification, not upload.
                        if try await transport.storedSize(path: path) != bytes.count {
                            try stillLive(); try await transport.upload(path: path, bytes: bytes)
                        }
                        try stillLive()
                        // A Storage success response alone is not a content receipt.
                        let recovered = try await transport.download(path: path); try stillLive()
                        guard recovered == bytes else { throw CookingPhotoError.integrity }
                        try markVerified(path)
                    }
                    let finished = try await transport.catalog(action: "complete", manifest: descriptor)
                    try stillLive(); try finished.validate(owner: account.accountID)
                    guard let receipt = finished.backups.first(where: { $0.mediaID == media.id }),
                          receipt.state == "ready", descriptor.sameContent(as: receipt) else { throw CookingPhotoError.integrity }
                } else {
                    let localValid = display.map { (try? CookingPhotoFiles.validate($0, manifest: descriptor, media: media, thumbnail: false)) != nil } == true &&
                        thumbnail.map { (try? CookingPhotoFiles.validate($0, manifest: descriptor, media: media, thumbnail: true)) != nil } == true
                    if !localValid {
                        guard allowDownloads else { throw CookingPhotoError.pending }
                        let restoredDisplay = try await transport.download(path: descriptor.displayKey); try stillLive()
                        let restoredThumbnail = try await transport.download(path: descriptor.thumbnailKey); try stillLive()
                        try CookingPhotoFiles.install(display: restoredDisplay, thumbnail: restoredThumbnail,
                            manifest: descriptor, media: media, root: root)
                        NotificationCenter.default.post(name: .cookingPhotoFilesRestored, object: root, userInfo: ["mediaID": media.id])
                    }
                }
            }
        }
        let liveIDs = Set(graph.media.map { $0.id.uuidString })
        let cleanupIDs = Set(catalog.backups.filter { $0.state == "deleted" }.map { $0.mediaID.uuidString })
        journal.entries = journal.entries.filter { liveIDs.contains($0.key) || (cleanupIDs.contains($0.key) && $0.value.phase != "cleaned") }
        if complete, !journal.hasOutstandingWork { journal.settledRevision = acceptedRevision }
        try journal.save(root: root)
        return complete
    }
    private static func checkpoint(_ manifest: CookingPhotoManifest, root: URL, journal: inout CookingPhotoJournal,
        action: (_ verified: Set<String>, _ markVerified: (String) throws -> Void) async throws -> Void) async throws {
        let key = manifest.mediaID.uuidString
        var entry = journal.entries[key] ?? .init()
        if let known = entry.manifest, !known.sameContent(as: manifest) { throw CookingPhotoError.integrity }
        entry.manifest = manifest; entry.phase = "transferring"; entry.attempts += 1
        journal.entries[key] = entry; try journal.save(root: root)
        // Durable per-path progress: a crash or lost reply after one object never repeats it.
        func markVerified(_ path: String) throws {
            entry.verifiedPaths = Array(Set(entry.verifiedPaths ?? []).union([path])).sorted()
            journal.entries[key] = entry; try journal.save(root: root)
        }
        do {
            try await action(Set(entry.verifiedPaths ?? []), markVerified)
            entry.phase = manifest.state == "deleted" ? "cleaned" : "verified"
            entry.diagnostic = nil; entry.retryAt = nil
            journal.entries[key] = entry; try journal.save(root: root)
        } catch {
            entry.diagnostic = (error as? CookingPhotoError)?.diagnostic ?? (error is CancellationError ? "cancelled" : "photo-network")
            entry.retryAt = SyncRetryPolicy.nextAttempt(after: error, attempt: entry.attempts)
            journal.entries[key] = entry; try journal.save(root: root)
            throw error
        }
    }

    /// Read-only byte recovery for scratch verification; no register/upload/cleanup.
    static func restoreOnly(graph: CookingGraph, root: URL, owner: UUID, transport: any CookingPhotoTransport) async throws -> Int {
        guard graph.accountID == owner, root.lastPathComponent == owner.uuidString.lowercased() else { throw SyncFoundationError.wrongAccount }
        let catalog = try await transport.catalog(action: "list", manifest: nil)
        try Task.checkCancellation(); try catalog.validate(owner: owner)
        for media in graph.media {
            guard let manifest = catalog.backups.first(where: { $0.mediaID == media.id }), manifest.state == "ready" else { throw CookingPhotoError.pending }
            let display = try await transport.download(path: manifest.displayKey); try Task.checkCancellation()
            let thumbnail = try await transport.download(path: manifest.thumbnailKey); try Task.checkCancellation()
            try CookingPhotoFiles.install(display: display, thumbnail: thumbnail, manifest: manifest, media: media, root: root)
            guard try CookingPhotoFiles.read(media: media, thumbnail: false, root: root) == display,
                  try CookingPhotoFiles.read(media: media, thumbnail: true, root: root) == thumbnail else { throw CookingPhotoError.integrity }
        }
        return graph.media.count
    }
}
