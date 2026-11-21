import Foundation

nonisolated struct SocialPost: Codable, Identifiable, Sendable {
    let id: UUID
    let author: SocialPerson
    let title: String
    let versionTitle: String?
    let scoreText: String?
    let achievement: String?
    let createdAt: Double
    let photoPath: String?
    let published: Bool
    let isAuthor: Bool
    let moderationState: String
    /// Opaque server-authorized identity of this creator's source Dish.
    var dishKey: String? = nil
    var likeCount: Int? = nil
    var commentCount: Int? = nil
    var liked: Bool? = nil
    var provenance: SocialProvenance? = nil
    var recipeID: UUID? = nil
    var recipeRevision: Int? = nil
    var recipeAttachmentPresent: Bool? = nil
    var postDescription: String? = nil
    /// Exact private Cook ID, projected only for this post's author.
    var sourceAttemptID: UUID? = nil
    var metadata: SharedCookingMetadata? = nil
    var rankAtSharing: Int? = nil
    var rankedCountAtSharing: Int? = nil
    var sharedRankText: String? {
        guard scoreText != nil, let rankAtSharing, let rankedCountAtSharing,
              rankAtSharing > 0, rankAtSharing <= rankedCountAtSharing else { return nil }
        return "#\(rankAtSharing) of \(rankedCountAtSharing)"
    }
    var date: Date { Date(timeIntervalSince1970: createdAt) }
}
nonisolated struct SocialPostsPage: Codable, Sendable { var posts: [SocialPost] }
nonisolated struct SocialCleanupPage: Codable, Sendable {
    struct Item: Codable, Sendable { let postID: UUID; let path: String }
    let paths: [Item]
}
@MainActor enum SocialPhotoCleanup {
    /// Routine sweeps (feed loads, polls) run at most this often; a delete/cancel runs immediately.
    static let routineInterval: TimeInterval = 600
    private static var lastRoutineRun: Date?
    /// `cleanup` is a server write (it retires day-old drafts), so it must not ride every 30 s poll.
    static func run(request: SocialRequest, media: SocialMediaRequest?, afterRetirement: Bool = false, now: Date = .now) async {
        guard let media else { return }
        if !afterRetirement, let last = lastRoutineRun, now.timeIntervalSince(last) < routineInterval { return }
        lastRoutineRun = now
        do {
            let page = try JSONDecoder().decode(SocialCleanupPage.self, from: await request("social_content", "cleanup", .init()))
            for item in page.paths.prefix(25) {
                try Task.checkCancellation()
                _ = try await media(.remove(paths: [item.path]))
                _ = try await request("social_content", "cleaned", .init(postID: item.postID))
            }
        } catch { /* Retired bytes remain private and retry on a later social refresh. */ }
    }
}
