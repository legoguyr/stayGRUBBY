import Foundation
import Supabase

nonisolated enum CookingSyncError: Error, Equatable {
    case conflict, rejected, authenticationRequired, unavailable, rankingUpdateRequired
    var diagnosticCode: String {
        switch self {
        case .rankingUpdateRequired: "ranking-update-required"
        case .conflict: "revision-conflict"
        case .rejected: "operation-rejected"
        case .authenticationRequired: "authentication-required"
        case .unavailable: "network-unavailable"
        }
    }
}

@MainActor protocol AccountSyncBackend: AccountLibraryBackend {
    func applyCookingOperation(_ envelope: SyncEnvelope) async throws -> SyncReceipt
}

nonisolated struct CookingOperationReceipt: Codable, Sendable {
    let operationID: UUID
    let storeID: UUID
    let accountID: UUID
    let payloadHash: String
    let revision: Int
    func validated(for envelope: SyncEnvelope) throws -> SyncReceipt {
        guard operationID == envelope.operationID, storeID == envelope.storeID,
              accountID == envelope.accountID, payloadHash == envelope.payloadHash, revision > envelope.expectedRevision
        else { throw SyncFoundationError.invalidReceipt }
        return SyncReceipt(operationID: operationID, revision: revision)
    }
}

/// SDK adds the current authenticated session. There is no service credential or media byte path.
extension SupabaseAccountBackend: AccountSyncBackend {
    func applyCookingOperation(_ envelope: SyncEnvelope) async throws -> SyncReceipt {
        guard let user = client.auth.currentSession?.user.id else { throw CookingSyncError.authenticationRequired }
        struct Parameters: Encodable { let envelope: SyncEnvelope }
        do {
            let response = try await client.schema("api").rpc("apply_cooking_operation", params: Parameters(envelope: envelope)).execute()
            try Task.checkCancellation()
            guard client.auth.currentSession?.user.id == user else { throw AccountFoundationError.identityChanged }
            return try JSONDecoder().decode(CookingOperationReceipt.self, from: response.data).validated(for: envelope)
        } catch let error as PostgrestError {
            // SQL errors can include user data: expose/persist only a fixed diagnostic code.
            switch error.code {
            case "0A000": throw CookingSyncError.rankingUpdateRequired
            case "40001", "PT409": throw CookingSyncError.conflict
            case "42501", "PGRST301", "PGRST302": throw CookingSyncError.authenticationRequired
            default: throw CookingSyncError.rejected
            }
        }
    }
}

nonisolated struct AuthorizedCookingTransport: SyncTransport {
    let sendOperation: @Sendable (SyncEnvelope) async throws -> SyncReceipt
    func send(_ envelope: SyncEnvelope) async throws -> SyncReceipt { try await sendOperation(envelope) }
}

/// A deterministic server conflict ("changed; reload", "Wait for cooking sync"). Functions raise
/// PT409 (HTTP 409); 40001 is accepted from servers deployed before November 11, 2026. 40001 is
/// never raised on purpose any more: PostgREST retries it without limit (P0 incident).
nonisolated enum StayGrubbyConflict {
    static let codes: Set<String> = ["PT409", "40001"]
    static func matches(_ error: Error) -> Bool { (error as? PostgrestError)?.code.map(codes.contains) ?? false }
}
