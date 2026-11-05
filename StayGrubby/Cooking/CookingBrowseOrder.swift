import Foundation

nonisolated enum CookingBrowseSort: String, CaseIterable, Identifiable {
    case grubRank = "Grub Rank", score = "Highest Score", lowestScore = "Lowest Score", recentlyCooked = "Newest Cooked", oldest = "Oldest Cooked", alphabetical = "A–Z", reverseAlphabetical = "Z–A"
    var id: String { rawValue }
    var needsScores: Bool { self == .score || self == .lowestScore }
}

@MainActor enum CookingBrowseOrder {
    /// Read-only projection after filtering/version selection. Rank numbers retain their global meaning.
    static func entries(_ entries: [CookingDiscovery.Entry], order: CookingBrowseSort, scores: ScoreUnlockState) -> [CookingDiscovery.Entry] {
        let effective = order.needsScores && !scores.isUnlocked ? .grubRank : order
        return entries.sorted { a, b in
            switch effective {
            case .grubRank: break
            case .score, .lowestScore:
                let x = a.attempt.rankedItem.flatMap { scores.scoreText($0.score) }.flatMap(Double.init)
                let y = b.attempt.rankedItem.flatMap { scores.scoreText($0.score) }.flatMap(Double.init)
                if x != y { guard let x else { return false }; guard let y else { return true }; return effective == .score ? x > y : x < y }
            case .recentlyCooked, .oldest:
                let x = a.attempt.cookedAt, y = b.attempt.cookedAt
                if x != y {
                    guard let x else { return false }; guard let y else { return true }
                    return effective == .recentlyCooked ? x > y : x < y
                }
            case .alphabetical, .reverseAlphabetical:
                let comparison = (a.attempt.dish?.name ?? a.attempt.displayName).localizedStandardCompare(b.attempt.dish?.name ?? b.attempt.displayName)
                if comparison != .orderedSame { return comparison == (effective == .alphabetical ? .orderedAscending : .orderedDescending) }
            }
            return a.globalRank < b.globalRank
        }
    }
}
