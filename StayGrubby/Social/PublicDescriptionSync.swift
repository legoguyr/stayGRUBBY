import Foundation
import SwiftData

/// Compatibility seam while Claude binds the presentation to exact Cooks.
/// Canonical descriptions sync through CookingStore + the existing journal, never post fanout.
@MainActor enum PublicDescriptionSync {
    struct Outcome: Equatable { var updated = 0; var failed = 0 }
    @discardableResult
    static func pushToPosts(of dish: Dish, request: @escaping SocialRequest) async -> Outcome { Outcome() }

    /// A Dish never identifies a Cook description. Retired to prevent old UI from editing the parent.
    static func dish(owning post: SocialPost, in context: ModelContext, request: @escaping SocialRequest) async -> Dish? { nil }

    static func attempt(owning post: SocialPost, in context: ModelContext) throws -> CookingAttempt? {
        guard post.isAuthor, let id = post.sourceAttemptID else { return nil }
        return try context.fetch(FetchDescriptor<CookingAttempt>(predicate: #Predicate { $0.id == id })).first
    }
    nonisolated static func needsUpdate(_ post: SocialPost, to description: String) -> Bool { trimmed(post.postDescription) != trimmed(description) }
    nonisolated static func trimmed(_ value: String?) -> String { (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
}
