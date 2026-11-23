import SwiftUI
import Supabase

@MainActor protocol SocialBackend: AccountBackend {
    func socialRequest(endpoint: String, action: String, payload: SocialPayload) async throws -> Data
}
extension SupabaseAccountBackend: SocialBackend {
    /// Every `api` RPC the app may call. A missing name fails on device before any request is sent
    /// (Build 6: `recipe_library` was absent, so Unlink and Recently Deleted failed while every fixture
    /// passed). `SocialEndpointAllowlistTests` keeps this in step with the endpoints the app uses.
    nonisolated static let socialEndpoints: Set<String> = [
        "social_identity", "social_people", "social_report", "social_content", "social_feed", "social_interactions",
        "social_avatar", "social_cooking", "social_notifications", "social_send", "recipes", "recipe_library",
        "profile_link", "feature_flags", "cook_description",
        "staff_status", "moderation_review",
    ]
    func socialRequest(endpoint: String, action: String, payload: SocialPayload) async throws -> Data {
        guard Self.socialEndpoints.contains(endpoint), let user = client.auth.currentSession?.user.id else { throw AccountFoundationError.accountNotResolved }
        struct Parameters: Encodable { let action: String; let payload: SocialPayload }
        let response = try await client.schema("api").rpc(endpoint, params: Parameters(action: action, payload: payload)).execute()
        try Task.checkCancellation()
        guard client.auth.currentSession?.user.id == user else { throw AccountFoundationError.identityChanged }
        return response.data
    }
}
typealias SocialRequest = @MainActor (String, String, SocialPayload) async throws -> Data
private struct SocialRequestKey: EnvironmentKey { static let defaultValue: SocialRequest? = nil }
extension EnvironmentValues {
    var socialRequest: SocialRequest? { get { self[SocialRequestKey.self] } set { self[SocialRequestKey.self] = newValue } }
}
