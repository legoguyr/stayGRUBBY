import Foundation
import SwiftData

/// Read-only Profile presentation, independent of the Rankings display preference.
/// Only policy-approved score text reaches the Profile's food rows.
@MainActor struct ProfileSnapshot {
    struct Food: Identifiable {
        let attempt: CookingAttempt
        let rank: Int
        let scoreText: String?
        var id: UUID { attempt.id }
        var title: String { attempt.dish?.name ?? attempt.displayName }
        var accessibilityLabel: String {
            let score = scoreText.map { "score \($0)" } ?? "score locked"
            return ["Rank \(rank)", title, attempt.meaningfulVersionLabel, attempt.category.label, score].compactMap { $0 }.joined(separator: ", ")
        }
    }

    let rankedEntryCount: Int
    let dishCount: Int
    let lastCookedAt: Date?
    let scores: ScoreUnlockState
    let topFoods: [Food]
    /// The most recent ranked cooks (cooking history), newest first.
    let recentCooks: [Food]
    /// Smart Collections, derived from Dishes (nil while the `dish_collections` gate is off).
    let collections: [DishCollectionSummary]?

    init(context: ModelContext, list: RankingList?, includesCollections: Bool = false) {
        let entries = ScoreUnlockPolicy.entries(in: context, list: list)
        let state = ScoreUnlockPolicy.state(in: context, list: list)
        scores = state
        rankedEntryCount = state.rankedEntryCount
        dishCount = Set(entries.compactMap { $0.attempt.dish?.id }).count
        lastCookedAt = entries.compactMap { $0.attempt.cookedAt }.max()
        topFoods = entries.prefix(3).map { entry in
            Food(attempt: entry.attempt, rank: entry.globalRank,
                 scoreText: entry.attempt.rankedItem.flatMap { state.scoreText($0.score) })
        }
        collections = includesCollections
            ? DishCollectionSummary.all(dishes: (try? context.fetch(FetchDescriptor<Dish>())) ?? [], entries: entries, scores: state) : nil
        recentCooks = entries.sorted {
            ($0.attempt.cookedAt ?? $0.attempt.createdAt, $0.attempt.createdAt) > ($1.attempt.cookedAt ?? $1.attempt.createdAt, $1.attempt.createdAt)
        }.prefix(3).map { entry in
            Food(attempt: entry.attempt, rank: entry.globalRank,
                 scoreText: entry.attempt.rankedItem.flatMap { state.scoreText($0.score) })
        }
    }
}
