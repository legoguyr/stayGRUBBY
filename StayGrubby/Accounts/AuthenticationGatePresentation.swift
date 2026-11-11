import Foundation

/// Copy and available recovery actions only; never decides account readiness or routing.
nonisolated struct AuthenticationGatePresentation {
    nonisolated enum Retry: Equatable { case account, library }
    let title: String
    let message: String
    var isWorking = false
    var isError = false
    var retry: Retry?
    var signOutTitle: String?

    init(state: AccountSessionState, setupFailed: Bool, isSigningOut: Bool, failure: AccountFailureKind? = nil) {
        if isSigningOut {
            title = "Signing out…"
            message = "Finishing up on this device."
            isWorking = true
            return
        }
        switch state {
        case .guest:
            title = "Make it your cooking library."
            message = "Sign in with Apple to get started or return to your account."
        case .signInFailed:
            title = "Let’s try signing in again."
            message = Self.failureMessage(failure, fallback: "Check your connection, then use Sign in with Apple below.")
            isError = true
        case .authorizingApple:
            title = "Continue with Apple…"
            message = "Finish signing in with Apple to continue."
            isWorking = true
        case .authenticating:
            title = "Signing you in…"
            message = "Getting your cooking library ready."
            isWorking = true
            signOutTitle = "Cancel sign-in"
        case .loadingSession:
            title = "Welcome back."
            message = "Restoring your account…"
            isWorking = true
            signOutTitle = "Sign out"
        case .provisioning:
            title = "Getting things ready…"
            message = "Setting up your StayGrubby account."
            isWorking = true
            signOutTitle = "Sign out"
        case .deletionRequired:
            title = "Finish deleting your account."
            message = "Verify with the linked Apple account to safely finish the pending deletion."
            isError = true
        case .retryRequired(let step, _):
            title = step == .restoreSession ? "Couldn’t restore your account." : "Couldn’t finish account setup."
            message = Self.failureMessage(failure, fallback: "Check your connection and try again. Your cooking library stays protected.")
            isError = true
            retry = .account
            signOutTitle = "Sign out"
        case .resolved:
            if setupFailed {
                title = "Couldn’t open your cooking library."
                message = "Try again. Your saved dishes haven’t been reset."
                isError = true
                retry = .library
            } else {
                title = "Your cooking awaits."
                message = "Opening your personal library…"
                isWorking = true
            }
            signOutTitle = "Sign out"
        }
    }

    /// Distinguishes no connection from a StayGrubby service problem; the short code helps support.
    static func failureMessage(_ failure: AccountFailureKind?, fallback: String) -> String {
        switch failure {
        case .offline?: "You’re offline or the connection dropped. Reconnect and try again. Your cooking library stays protected. (\(AccountFailureKind.offline.supportCode))"
        case .serviceUnavailable?: "StayGrubby is having trouble on our side. Nothing on your phone was changed. Try again in a few minutes. (\(AccountFailureKind.serviceUnavailable.supportCode))"
        case .rejected?: "Apple sign-in couldn’t be confirmed. Use Sign in with Apple again. Your cooking library stays protected. (\(AccountFailureKind.rejected.supportCode))"
        case .unknown?: fallback + " (\(AccountFailureKind.unknown.supportCode))"
        case nil: fallback
        }
    }
}
