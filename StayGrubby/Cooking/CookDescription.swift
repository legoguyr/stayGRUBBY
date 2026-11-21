import Foundation
import SwiftData

nonisolated enum CookDescriptionPolicy {
    static let maximum = 2_000
    static func normalized(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
    static func valid(_ value: String?) -> Bool {
        guard let value else { return true }
        return value.unicodeScalars.count <= maximum && !value.unicodeScalars.contains {
            $0.properties.generalCategory == .control && $0 != "\n" && $0 != "\r" && $0 != "\t"
        }
    }
}
extension CookingStore {
    /// Explicit owner edit, persisted through the existing atomic cooking journal.
    static func editCookDescription(_ attempt: CookingAttempt, publicDescription: String, context: ModelContext) throws {
        let text = CookDescriptionPolicy.normalized(publicDescription)
        guard CookDescriptionPolicy.valid(text), attempt.dish != nil, attempt.rankedItem != nil else { throw StoreError.invalidDraft }
        guard attempt.publicDescription != text else { return }
        let baseline = try SyncJournal.begin(context)
        do {
            attempt.publicDescription = text; attempt.updatedAt = .now
            try SyncJournal.stage(baseline, kind: "editCookDescription", context: context)
            try context.save(); SyncJournal.didCommit(context)
        } catch { context.rollback(); throw error }
    }
}

nonisolated struct CookDescriptionContext: Decodable, Sendable {
    struct LegacyPost: Decodable, Sendable {
        var postID: UUID
        var postDescription: String?
        var retired: Bool
    }
    var attemptID: UUID
    var publicDescription: String?
    var effectiveDescription: String?
    var legacyDishDescription: String?
    var legacyPosts: [LegacyPost]
    var hasMoreLegacyPosts: Bool
    var needsReview: Bool
}
@MainActor enum CookDescriptionService {
    static func load(_ attemptID: UUID, request: SocialRequest) async throws -> CookDescriptionContext {
        let value = try JSONDecoder().decode(CookDescriptionContext.self, from: await request("cook_description", "get", .init(attemptID: attemptID)))
        guard value.attemptID == attemptID else { throw AccountFoundationError.invalidResolution }
        return value
    }
}

/// Older servers silently ignore unknown sync fields. Pause, never acknowledge lost text.
nonisolated enum CookDescriptionSyncSupport {
    static func requiresSupport(_ payload: Data) throws -> Bool {
        let changes = try JSONDecoder().decode(SyncChanges.self, from: payload)
        for record in changes.upserts where record.reference.entity == .attempt {
            let value = try JSONSerialization.jsonObject(with: record.data) as? [String: Any]
            if let description = value?["publicDescription"], !(description is NSNull) { return true }
        }
        return false
    }
}
