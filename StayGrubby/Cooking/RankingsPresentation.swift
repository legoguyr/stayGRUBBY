import Foundation

nonisolated enum RankingsDisplayMode: String, CaseIterable, Identifiable {
    // Persisted raw values; never shown. User-facing labels are "All Cooks" (FOOD_ARCHITECTURE §4.3).
    case topVersion = "Top Version", allVersions = "All Versions"
    var id: String { rawValue }
    static let preferenceKey = "StayGrubby.rankingsDisplayMode.v1"
}
/// A request to show Grub Rank in a given view (My Kitchen statistics): the view is applied, visible in
/// the All Cooks toggle, with search, filters and sort reset so the list matches the count tapped.
struct GrubRankRequest: Equatable {
    let id = UUID()
    let mode: RankingsDisplayMode
}
@MainActor enum RankingsDisplayPreferences {
    static var defaults: UserDefaults {
        #if DEBUG
        if let id = DebugReviewConfiguration.current.storeID,
           let isolated = UserDefaults(suiteName: "StayGrubby.review.display.\(id.uuidString)") { return isolated }
        #endif
        return .standard
    }
}
@MainActor enum RankingsPresentation {
    /// Filter/search first, then retain the highest globally ranked matching
    /// version of each Dish. Original global rank numbers are never renumbered.
    /// All Dishes numbering: each Dish's best cook → its position among Dishes (1-based), in global order.
    static func dishPositions(_ eligible: [CookingDiscovery.Entry]) -> [UUID: Int] {
        var seen = Set<UUID>(), positions: [UUID: Int] = [:]
        for entry in eligible.sorted(by: { $0.globalRank < $1.globalRank }) {
            guard let dish = entry.attempt.dish?.id, seen.insert(dish).inserted else { continue }
            positions[entry.attempt.id] = seen.count
        }
        return positions
    }
    static func entries(_ eligible: [CookingDiscovery.Entry], matching: [CookingDiscovery.Entry],
                        mode: RankingsDisplayMode) -> [CookingDiscovery.Entry] {
        let matches = Set(matching.map(\.id))
        var seen = Set<UUID>()
        return eligible.filter { entry in
            guard matches.contains(entry.id), let dish = entry.attempt.dish else { return false }
            return mode == .allVersions || seen.insert(dish.id).inserted
        }
    }
}

/// Grub Rank’s two views: every Dish (one row each) or Dish Variations (Smart Collections, gated).
nonisolated enum GrubRankSection: String, CaseIterable, Identifiable {
    case dishes, folders
    var id: String { rawValue }
    var title: String { switch self { case .dishes: "All Dishes"; case .folders: DishVariationCopy.plural } }
}
