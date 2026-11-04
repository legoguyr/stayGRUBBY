import Foundation

nonisolated enum CookingBrowseSort: String, CaseIterable, Identifiable {
    case grubRank = "Grub Rank", score = "Score", recentlyCooked = "Recently Cooked", oldest = "Oldest", alphabetical = "Alphabetical"
    var id: String { rawValue }
}

@MainActor enum CookingBrowseOrder {
    /// Read-only projection after filtering/version selection. Rank numbers retain their global meaning.
    static func entries(_ entries: [CookingDiscovery.Entry], order: CookingBrowseSort, scores: ScoreUnlockState) -> [CookingDiscovery.Entry] {
        let effective = order == .score && !scores.isUnlocked ? .grubRank : order
        return entries.sorted { a, b in
            switch effective {
            case .grubRank: break
            case .score:
                let x = a.attempt.rankedItem.flatMap { scores.scoreText($0.score) }.flatMap(Double.init) ?? -.infinity
                let y = b.attempt.rankedItem.flatMap { scores.scoreText($0.score) }.flatMap(Double.init) ?? -.infinity
                if x != y { return x > y }
            case .recentlyCooked, .oldest:
                let x = a.attempt.cookedAt, y = b.attempt.cookedAt
                if x != y {
                    guard let x else { return false }; guard let y else { return true }
                    return effective == .recentlyCooked ? x > y : x < y
                }
            case .alphabetical:
                let comparison = (a.attempt.dish?.name ?? a.attempt.displayName).localizedStandardCompare(b.attempt.dish?.name ?? b.attempt.displayName)
                if comparison != .orderedSame { return comparison == .orderedAscending }
            }
            return a.globalRank < b.globalRank
        }
    }
}
