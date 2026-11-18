import Foundation
import SwiftData

/// One Public Description per Dish (master UI milestone, November 18, 2026).
///
/// `Dish.publicDescription` is the canonical text; each of the owner's shared posts of that Dish shows it as
/// its caption on The Pass. The server still keeps a caption per post (`social_content editDescription`), so
/// an explicit save on either side updates the other. Runs only after an explicit owner Save — never when a
/// screen opens — and writes a post only when its caption actually differs.
///
/// Backend dependency (roadmap): a server-side caption derived from the Dish row would remove the per-post
/// copy and make cross-device edits atomic. Until then a failed post update is reported, never hidden.
@MainActor enum PublicDescriptionSync {
    struct Outcome: Equatable { var updated = 0; var failed = 0 }
    /// Upper bound on cooks checked for one Dish save (each check is one read).
    static let attemptLimit = 20

    /// After an explicit Dish description save: bring this owner's shared posts of the Dish in line.
    @discardableResult
    static func pushToPosts(of dish: Dish, request: @escaping SocialRequest) async -> Outcome {
        let description = dish.publicDescription ?? ""
        var outcome = Outcome()
        let attempts = dish.attempts.sorted { $0.createdAt > $1.createdAt }.prefix(attemptLimit)
        for attempt in attempts {
            do {
                guard let post = try await SocialPostPublisher.existing(attemptID: attempt.id, request: request),
                      post.isAuthor, needsUpdate(post, to: description) else { continue }
                _ = try await request("social_content", "editDescription", .init(postID: post.id, postDescription: description))
                outcome.updated += 1
            } catch is CancellationError { break } catch { outcome.failed += 1 }
        }
        if outcome.updated > 0 { NotificationCenter.default.post(name: .socialContentChanged, object: nil) }
        return outcome
    }

    /// The local Dish that owns one of the author's posts. The Dish name only narrows the candidates; the
    /// server's cook → post lookup confirms identity exactly, so equal titles never merge Dishes.
    static func dish(owning post: SocialPost, in context: ModelContext, request: @escaping SocialRequest) async -> Dish? {
        guard post.isAuthor else { return nil }
        let title = fold(post.title)
        let candidates = ((try? context.fetch(FetchDescriptor<Dish>())) ?? []).filter { fold($0.name) == title }
        for dish in candidates {
            for attempt in dish.attempts.prefix(attemptLimit) {
                if let found = try? await SocialPostPublisher.existing(attemptID: attempt.id, request: request), found.id == post.id { return dish }
            }
        }
        return nil
    }

    nonisolated static func needsUpdate(_ post: SocialPost, to description: String) -> Bool {
        trimmed(post.postDescription) != trimmed(description)
    }
    nonisolated static func trimmed(_ value: String?) -> String { (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
    nonisolated private static func fold(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
