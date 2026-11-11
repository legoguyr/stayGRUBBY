import Foundation
import Supabase

/// Why sign-in, account restoration or setup failed, so the gate can tell a dead connection apart from a
/// StayGrubby service outage (P0 incident, November 11 2026: a read-only database made every failure read
/// "check your connection"). Only a fixed category and short support code are shown or kept; server text
/// can contain request data and is never surfaced.
nonisolated enum AccountFailureKind: Equatable, Sendable {
    /// The phone could not reach the service (offline, DNS, timeout, lost connection).
    case offline
    /// The service answered but could not complete the request (5xx, read-only/maintenance database).
    case serviceUnavailable
    /// The service refused the credential or session (expired/invalid sign-in).
    case rejected
    case unknown

    var supportCode: String {
        switch self {
        case .offline: "SG-NET"
        case .serviceUnavailable: "SG-SVC"
        case .rejected: "SG-AUTH"
        case .unknown: "SG-ERR"
        }
    }

    static func classify(_ error: Error) -> AccountFailureKind {
        if isOfflineConnectionError(error) { return .offline }
        if let error = error as? PostgrestError {
            // 25006 read-only transaction, 53xxx resources, 57xxx operator intervention, 08xxx connection.
            let code = error.code ?? ""
            if code == "25006" || code.hasPrefix("53") || code.hasPrefix("57") || code.hasPrefix("08") { return .serviceUnavailable }
            if code == "42501" || code.hasPrefix("PGRST3") { return .rejected }
            return .unknown
        }
        if let error = error as? AuthError {
            if case let .api(message, _, _, response) = error {
                if response.statusCode >= 500 || message.localizedCaseInsensitiveContains("read-only transaction") { return .serviceUnavailable }
                if [400, 401, 403, 422].contains(response.statusCode) { return .rejected }
            }
            if case .sessionMissing = error { return .rejected }
            return .unknown
        }
        return .unknown
    }
}
