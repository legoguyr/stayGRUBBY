import Testing
import Foundation
import Supabase
@testable import StayGrubby

/// P0 incident, November 11 2026: deterministic conflicts now arrive as PT409 (40001 was retried forever
/// by PostgREST), and account failures are classified instead of all reading "check your connection".
struct IncidentHardeningTests {
    @Test func conflictCodesIncludeNonRetryablePT409AndLegacy40001() {
        #expect(StayGrubbyConflict.matches(PostgrestError(code: "PT409", message: "Wait for cooking sync")))
        #expect(StayGrubbyConflict.matches(PostgrestError(code: "40001", message: "legacy server")))
        #expect(!StayGrubbyConflict.matches(PostgrestError(code: "42501", message: "denied")))
        #expect(!StayGrubbyConflict.matches(URLError(.timedOut)))
    }

    @Test func readOnlyDatabaseIsAServiceProblemNotAConnectionProblem() {
        #expect(AccountFailureKind.classify(PostgrestError(code: "25006", message: "cannot execute UPDATE in a read-only transaction")) == .serviceUnavailable)
        let response = HTTPURLResponse(url: URL(string: "https://example.invalid/auth/v1/token")!, statusCode: 400, httpVersion: nil, headerFields: nil)!
        let readOnly = AuthError.api(message: "ERROR: cannot execute UPDATE in a read-only transaction (SQLSTATE 25006)", errorCode: .unknown, underlyingData: Data(), underlyingResponse: response)
        #expect(AccountFailureKind.classify(readOnly) == .serviceUnavailable)
        let outage = HTTPURLResponse(url: URL(string: "https://example.invalid/auth/v1/token")!, statusCode: 500, httpVersion: nil, headerFields: nil)!
        #expect(AccountFailureKind.classify(AuthError.api(message: "unexpected_failure", errorCode: .unknown, underlyingData: Data(), underlyingResponse: outage)) == .serviceUnavailable)
    }

    @Test func offlineAndRejectedFailuresStayDistinct() {
        #expect(AccountFailureKind.classify(URLError(.notConnectedToInternet)) == .offline)
        #expect(AccountFailureKind.classify(URLError(.timedOut)) == .offline)
        let response = HTTPURLResponse(url: URL(string: "https://example.invalid/auth/v1/token")!, statusCode: 400, httpVersion: nil, headerFields: nil)!
        #expect(AccountFailureKind.classify(AuthError.api(message: "Invalid id token", errorCode: .unknown, underlyingData: Data(), underlyingResponse: response)) == .rejected)
        #expect(AccountFailureKind.classify(PostgrestError(code: "42501", message: "denied")) == .rejected)
    }

    @Test func gateCopyNamesTheFailureWithoutServerText() {
        let service = AuthenticationGatePresentation(state: .signInFailed, setupFailed: false, isSigningOut: false, failure: .serviceUnavailable)
        #expect(service.message.contains("on our side") && service.message.contains("SG-SVC"))
        let restore = AuthenticationGatePresentation(state: .retryRequired(.restoreSession, nil), setupFailed: false, isSigningOut: false, failure: .offline)
        #expect(restore.title == "Couldn’t restore your account." && restore.message.contains("SG-NET"))
        let legacy = AuthenticationGatePresentation(state: .signInFailed, setupFailed: false, isSigningOut: false)
        #expect(legacy.message == "Check your connection, then use Sign in with Apple below.")
        #expect(!service.message.contains("SQLSTATE") && !service.message.contains("read-only"))
    }
}
