import SwiftUI

/// Server-managed feature flags (`api.feature_flags`). Every flag is off unless the server turns it
/// on for this account; offline, older servers and errors all mean off. A flag never makes an
/// unfinished feature shippable: the feature must be complete and accepted before it is enabled.
nonisolated enum FeatureFlag: String, CaseIterable, Sendable {
    /// Future (not built): shared Recipe/Dish pages show an aggregate score and how many people
    /// have made it (FOOD_ARCHITECTURE §10). Reserved so the key is never reused for something else.
    case dishAggregateScores = "dish_aggregate_scores"
}

nonisolated struct FeatureFlags: Equatable, Sendable {
    var enabled: Set<String> = []
    static let off = FeatureFlags()
    func isOn(_ flag: FeatureFlag) -> Bool { enabled.contains(flag.rawValue) }
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
