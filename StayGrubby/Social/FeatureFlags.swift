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
    /// Smart Collections (Dish organization labels). Needs `20261120150047_dish_collections` on the hosted
    /// project (deployed and enabled November 20, 2026): without the column the server drops labels, so
    /// never enable it on a server that lacks the migration (STAYGRUBBY_DEVELOPMENT_ROADMAP.md §1).
    case dishCollections = "dish_collections"
    /// Recipe Unlink and Recently Deleted (deployed and enabled November 20, 2026). Needs
    /// `20261121023911_recipe_unlink_and_recently_deleted` (`api.recipe_library`) on the hosted project;
    /// never enable it on a server without it: Unlink and Recently Deleted would fail, and Delete must not
    /// promise recovery.
    case recipeRecovery = "recipe_recovery"
    /// Terms of Use and Community Guidelines links (Settings, and the agreement line in kitchen setup;
    /// App Review 1.2). Built ahead: enable only after the owner approves the text and
    /// `LegalDocuments` URLs are live on staygrubby.com (V1_RELEASE_GATE.md).
    case legalTerms = "legal_terms"
    /// Settings → Moderation for staff (PUBLIC_MVP_MODERATION.md). Needs `20261123225337_moderation_staff_roles`
    /// and `api.staff_status` on the hosted project. The flag only allows the one staff-status read; the row
    /// appears only for a current admin or moderator, and the server checks every moderation action.
    case staffModeration = "staff_moderation"
}

/// Approved legal documents on staygrubby.com. Shown only with `FeatureFlag.legalTerms`; the text itself is
/// the owner's (never drafted into the app).
nonisolated enum LegalDocuments {
    static let termsOfUse = URL(string: "https://staygrubby.com/terms")!
    static let communityGuidelines = URL(string: "https://staygrubby.com/community-guidelines")!
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
