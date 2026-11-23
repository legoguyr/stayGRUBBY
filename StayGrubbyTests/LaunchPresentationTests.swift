import Foundation
import Testing
@testable import StayGrubby

/// Build 6 launch flash: every state a signed-in owner passes through while this launch restores the
/// session is the branded launch, never the sign-up story.
@MainActor struct LaunchPresentationTests {
    private func launch(_ state: AccountSessionState, finished: Bool = false, failed: Bool = false, setupFailed: Bool = false, signingOut: Bool = false) -> Bool {
        AuthenticationGateView.showsBrandedLaunch(state: state, launchRestorationFinished: finished, failed: failed, setupFailed: setupFailed, isSigningOut: signingOut)
    }

    @Test func restoringASavedSessionIsBrandedAtEveryStep() {
        let identity = AuthenticatedIdentity(userID: UUID())
        let account = ProvisionedAccount(formatVersion: 1, authUserID: identity.userID, accountID: UUID(), syncRevision: 0, libraryState: .initialized)
        #expect(launch(.guest), "First frames, before restore looks for a saved session")
        #expect(launch(.loadingSession))
        #expect(launch(.provisioning(identity)), "Build 6 flash: provisioning during launch restoration")
        #expect(launch(.resolved(account)), "Library opening")
        #expect(launch(.resolved(account), finished: true))
    }

    @Test func newAndFailedLaunchesReachTheGate() {
        let identity = AuthenticatedIdentity(userID: UUID())
        #expect(!launch(.guest, finished: true), "No saved session: the gate")
        #expect(!launch(.guest, failed: true))
        #expect(!launch(.provisioning(identity), finished: true), "Provisioning after an explicit sign-in keeps the gate")
        #expect(!launch(.provisioning(identity), failed: true))
        #expect(!launch(.retryRequired(.restoreSession, nil)))
        #expect(!launch(.signInFailed))
        #expect(!launch(.authorizingApple))
    }
}
