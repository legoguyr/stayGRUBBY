import Foundation
import Testing
import Supabase
@testable import StayGrubby

/// New-account setup decisions (Public MVP, November 16, 2026).
struct SocialOnboardingTests {
    private let unconfigured = SocialIdentity(displayName: "", username: nil, discoverable: false)
    private let configured = SocialIdentity(displayName: "Cook", username: "cook", discoverable: false)

    @Test func presentationRequiresNewAccountsOffersExistingOnceAndSkipsConfigured() {
        typealias P = SocialOnboardingPolicy
        #expect(P.presentation(identity: unconfigured, hasCooks: false, dismissed: false, resuming: false) == .required)
        #expect(P.presentation(identity: unconfigured, hasCooks: true, dismissed: false, resuming: false) == .offer)
        #expect(P.presentation(identity: unconfigured, hasCooks: true, dismissed: true, resuming: false) == .none)
        #expect(P.presentation(identity: configured, hasCooks: false, dismissed: false, resuming: false) == .none)
        #expect(P.presentation(identity: nil, hasCooks: false, dismissed: false, resuming: false) == .none, "Unknown identity never blocks the library")
        #expect(P.presentation(identity: configured, hasCooks: false, dismissed: false, resuming: true) == .required)
    }

    @Test func usernameGuidanceMatchesServerRules() {
        #expect(SocialOnboardingPolicy.usernameMessage("") == nil)
        #expect(SocialOnboardingPolicy.usernameMessage("ab") == "Use at least 3 characters.")
        #expect(SocialOnboardingPolicy.usernameMessage("Good_Cook") == nil, "Case folds to lowercase like the server")
        #expect(SocialOnboardingPolicy.usernameMessage("bad__name") != nil)
        #expect(SocialOnboardingPolicy.usernameMessage("staygrubby") == "That username is reserved.")
        #expect(SocialOnboardingPolicy.usernameMessage(String(repeating: "a", count: 25)) == "Use 24 characters or fewer.")
    }

    @Test func saveFailuresAreClassified() {
        #expect(SocialIdentitySaveFailure.classify(PostgrestError(code: "23505", message: "Username unavailable")) == .usernameTaken)
        #expect(SocialIdentitySaveFailure.classify(SocialUsernameUnavailable()) == .usernameTaken)
        #expect(SocialIdentitySaveFailure.classify(PostgrestError(code: "22023", message: "Invalid")) == .invalid)
        #expect(SocialIdentitySaveFailure.classify(URLError(.notConnectedToInternet)) == .connection)
    }

    @Test func draftResumesPerAccountAndCompletionIsPermanent() throws {
        let defaults = try #require(UserDefaults(suiteName: "onboarding-tests-\(UUID().uuidString)"))
        let a = "account.a", b = "account.b"
        var draft = SocialOnboardingDraft(); draft.step = .privacy; draft.username = "cook_a"
        draft.save(a, defaults: defaults)
        #expect(SocialOnboardingDraft.load(a, defaults: defaults) == draft)
        #expect(SocialOnboardingDraft.load(b, defaults: defaults) == nil, "Drafts are per account")
        SocialOnboardingDraft.complete(a, defaults: defaults)
        #expect(SocialOnboardingDraft.isComplete(a, defaults: defaults) && SocialOnboardingDraft.load(a, defaults: defaults) == nil)
        #expect(!SocialOnboardingDraft.isComplete(b, defaults: defaults))
        SocialOnboardingDraft.dismiss(b, defaults: defaults)
        #expect(SocialOnboardingDraft.isDismissed(b, defaults: defaults) && !SocialOnboardingDraft.isDismissed(a, defaults: defaults))
    }
}
