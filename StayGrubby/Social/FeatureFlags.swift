import SwiftUI

/// Server-managed feature flags (`api.feature_flags`). Every flag is off unless the server turns it
/// on for this account; offline, older servers and errors all mean off. A flag never makes an
/// unfinished feature shippable: the feature must be complete and accepted before it is enabled.
nonisolated enum FeatureFlag: String, CaseIterable, Sendable {
    /// Future (not built): shared Recipe/Dish pages show an aggregate score and how many people
    /// have made it (FOOD_ARCHITECTURE §10). Reserved so the key is never reused for something else.
    case dishAggregateScores = "dish_aggregate_scores"
    /// Future (backend dependency): public accounts are followed immediately; private accounts are searchable
    /// but show `SGLockedKitchenNotice` until a follow request is approved. Off until the server contract,
    /// RLS and the client follow flow are complete (STAYGRUBBY_DEVELOPMENT_ROADMAP.md).
    case accountPrivacyFollows = "account_privacy_follows"
    /// Smart Collections (Dish organization labels). Needs `20261118160100_dish_collections` on the hosted
    /// project: without the column the server drops labels, so they would never sync. Enable only after
    /// that migration is deployed and verified (STAYGRUBBY_DEVELOPMENT_ROADMAP.md §1).
    case dishCollections = "dish_collections"
}

nonisolated struct FeatureFlags: Equatable, Sendable {
    var enabled: Set<String> = []
    static let off = FeatureFlags()
    func isOn(_ flag: FeatureFlag) -> Bool {
        if enabled.contains(flag.rawValue) { return true }
        #if DEBUG
        // Isolated UI-test/review stores only (`--feature-flag <key>`); compiled out of Release.
        return DebugReviewConfiguration.current.featureFlags.contains(flag.rawValue)
        #else
        return false
        #endif
    }
}

@MainActor enum FeatureFlagService {
    static func load(_ request: @MainActor () async throws -> Data) async -> FeatureFlags {
        struct Response: Decodable { var enabled: [String] }
        do { return FeatureFlags(enabled: Set(try JSONDecoder().decode(Response.self, from: await request()).enabled)) }
        catch { return .off }
    }
}

private struct FeatureFlagsKey: EnvironmentKey { static let defaultValue = FeatureFlags.off }
extension EnvironmentValues {
    var featureFlags: FeatureFlags { get { self[FeatureFlagsKey.self] } set { self[FeatureFlagsKey.self] = newValue } }
}
