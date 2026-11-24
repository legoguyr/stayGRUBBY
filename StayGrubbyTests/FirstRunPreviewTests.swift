import Foundation
import Testing
@testable import StayGrubby

/// Internal first-run preview isolation (Build 7): the stand-in backend answers only profile setup,
/// refuses every other endpoint, and exiting leaves no setup state behind.
@MainActor struct FirstRunPreviewTests {
    @Test func previewAnswersSetupInMemoryAndRefusesEverythingElse() async throws {
        let backend = PreviewSocialBackend()
        var save = SocialPayload(); save.displayName = "Preview Cook"; save.username = "preview_cook"; save.discoverable = false
        let saved = try JSONDecoder().decode(SocialIdentity.self, from: await backend.request("social_identity", "save", save))
        #expect(saved.username == "preview_cook" && saved.isConfigured)
        _ = try await backend.request("social_avatar", "prepare", SocialPayload())
        _ = try await backend.media(.avatarUpload(path: "preview/avatar.jpg", bytes: Data()))
        // Library, Recipes, feed, flags, cooking sync and Storage reads are all unreachable.
        for endpoint in ["recipes", "recipe_library", "social_feed", "social_cooking", "social_content", "feature_flags", "cook_description", "profile_link"] {
            await #expect(throws: PreviewSocialBackend.Refused.self) { _ = try await backend.request(endpoint, "get", SocialPayload()) }
        }
        await #expect(throws: PreviewSocialBackend.Refused.self) { _ = try await backend.media(.avatarDownload(path: "x")) }
        await #expect(throws: PreviewSocialBackend.Refused.self) { _ = try await backend.media(.avatarRemove(paths: ["x"])) }
    }

    @Test func discardingThePreviewScopeLeavesNothingAndNeverTouchesAccountScopes() {
        let defaults = UserDefaults(suiteName: "preview-\(UUID().uuidString)")!
        let preview = "preview.\(UUID().uuidString)", account = "account.\(UUID().uuidString)"
        SocialOnboardingDraft.complete(account, defaults: defaults)
        FirstRunTutorial.complete(account, defaults: defaults)
        var draft = SocialOnboardingDraft(); draft.username = "preview_cook"; draft.save(preview, defaults: defaults)
        SocialOnboardingDraft.complete(preview, defaults: defaults); SocialOnboardingDraft.dismiss(preview, defaults: defaults)
        SocialOnboardingDraft.discard(preview, defaults: defaults)
        #expect(SocialOnboardingDraft.load(preview, defaults: defaults) == nil)
        #expect(!SocialOnboardingDraft.isComplete(preview, defaults: defaults) && !SocialOnboardingDraft.isDismissed(preview, defaults: defaults))
        #expect(SocialOnboardingDraft.isComplete(account, defaults: defaults), "The real account's setup is untouched")
        #expect(FirstRunTutorial.state(account, defaults: defaults) == .done, "The real account's tour completion is untouched")
    }
}
