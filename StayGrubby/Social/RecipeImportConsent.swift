import Foundation

/// Acknowledgement, not a global AI preference. Isolated account/development scopes never share consent.
@MainActor enum RecipeImportConsent {
    static let version = 1
    static func key(_ scope: String?) -> String? {
        guard let scope, scope.hasPrefix("account.") || scope.hasPrefix("development.") else { return nil }
        return "staygrubby.recipe-paste-disclosure.v\(version).\(scope)"
    }
    static func acknowledged(scope: String?, defaults: UserDefaults = .standard) -> Bool {
        key(scope).map { defaults.bool(forKey: $0) } ?? false
    }
    static func acknowledge(scope: String?, defaults: UserDefaults = .standard) {
        if let key = key(scope) { defaults.set(true, forKey: key) }
    }
    static func clear(scope: String?, defaults: UserDefaults = .standard) {
        if let key = key(scope) { defaults.removeObject(forKey: key) }
    }
}

@MainActor enum RecipePasteRequest {
    static func format(_ raw: String, dishTitle: String, acknowledged: Bool, request: RecipeImportRequest?) async throws -> RecipeImportResult {
        guard acknowledged else { throw RecipeImportFailure.unavailable }
        return try await RecipeIntelligenceService.format(raw, dishTitle: dishTitle, apple: AppleRecipeIntelligenceProvider(), fallback: GeminiRecipeIntelligenceProvider(request: request), preferOnDevice: false)
    }
}
