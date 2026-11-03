import Foundation
import SwiftData

/// Bounded per actual cook/version, retaining the established media ownership and transports.
nonisolated enum CookingPhotoPolicy {
    static let maximumPerCook = 6
    static func ordered(_ values: [CookingMedia]) -> [CookingMedia] {
        values.filter { $0.kindCode == CookingMediaKind.image.rawValue }.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
extension Dish {
    /// Stable version grouping; no media is copied or moved out of its historical cook.
    var photoVersions: [CookingAttempt] {
        attempts.sorted {
            if $0.sequenceNumber != $1.sequenceNumber { return $0.sequenceNumber > $1.sequenceNumber }
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }.filter { !$0.orderedImages.isEmpty }
    }
}
@MainActor enum CookingPhotoCollection {
    enum PhotoError: LocalizedError, Equatable {
        case limit, unavailable, invalidOrder
        var errorDescription: String? {
            switch self {
            case .limit: "You can keep up to six photos for each cook."
            case .unavailable: "This cook or photo is no longer available."
            case .invalidOrder: "The photo selection changed. Open it again and retry."
            }
        }
    }
    @discardableResult static func append(_ photo: PreparedCookingPhoto, to attempt: CookingAttempt, context: ModelContext, root: URL) throws -> CookingMedia {
        guard attempt.rankedItem != nil, attempt.dish != nil else { throw PhotoError.unavailable }
        guard attempt.orderedImages.count < CookingPhotoPolicy.maximumPerCook else { throw PhotoError.limit }
        try CookingStore.requireNewPhoto(photo.id, context: context)
        let baseline = try SyncJournal.begin(context); var written: CookingMedia?
        do {
            let order = attempt.orderedImages
            for (index, value) in order.enumerated() { value.sortOrder = index }
            let media = try LocalPhotoStore.write(photo, rootURL: root); written = media
            media.sortOrder = order.count; context.insert(media); attempt.media.append(media)
            attempt.updatedAt = .now
            try SyncJournal.stage(baseline, kind: "editCook", context: context)
            try context.save(); SyncJournal.didCommit(context); return media
        } catch {
            if let written { LocalPhotoStore.deleteFiles(for: written, rootURL: root) }
            context.rollback(); throw error
        }
    }
    static func reorder(_ ids: [UUID], in attempt: CookingAttempt, context: ModelContext) throws {
        let photos = attempt.orderedImages
        guard attempt.rankedItem != nil, Set(ids).count == ids.count, Set(ids) == Set(photos.map(\.id)) else { throw PhotoError.invalidOrder }
        let baseline = try SyncJournal.begin(context)
        do {
            let lookup = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
            for (index, id) in ids.enumerated() { lookup[id]?.sortOrder = index }
            attempt.updatedAt = .now
            try SyncJournal.stage(baseline, kind: "editCook", context: context)
            try context.save(); SyncJournal.didCommit(context)
        } catch { context.rollback(); throw error }
    }
    static func setCover(_ media: CookingMedia, in attempt: CookingAttempt, context: ModelContext) throws {
        guard attempt.orderedImages.contains(where: { $0.id == media.id }) else { throw PhotoError.unavailable }
        try reorder([media.id] + attempt.orderedImages.filter { $0.id != media.id }.map(\.id), in: attempt, context: context)
    }
    static func remove(_ media: CookingMedia, from attempt: CookingAttempt, context: ModelContext, root: URL) throws {
        guard attempt.rankedItem != nil, attempt.media.contains(where: { $0.id == media.id }), media.attempt?.id == attempt.id else { throw PhotoError.unavailable }
        let files = (media.displayFilename, media.thumbnailFilename)
        let baseline = try SyncJournal.begin(context)
        do {
            attempt.media.removeAll { $0.id == media.id }; context.delete(media)
            for (index, value) in attempt.orderedImages.enumerated() { value.sortOrder = index }
            attempt.updatedAt = .now
            try SyncJournal.stage(baseline, kind: "editCook", context: context)
            try context.save(); SyncJournal.didCommit(context)
            LocalPhotoStore.deleteFiles(displayFilename: files.0, thumbnailFilename: files.1, rootURL: root)
        } catch { context.rollback(); throw error }
    }
}
