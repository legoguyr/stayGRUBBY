#if DEBUG
import Foundation

/// One owner-approved investigation, not a product allowance or provider setting.
/// Persist before invocation; an interrupted attempt is consumed, never retried.
@MainActor final class RecipeRegressionBudget {
    static let approvalID = "77dd8c13-six-approved-calls"
    struct Attempt: Codable { var caseID: String; var startedAt: Date }
    struct State: Codable { var approvalID = RecipeRegressionBudget.approvalID; var attempts: [Attempt] = []; var halted = false }
    enum Failure: Error { case invalid, exhausted, halted }
    static func mustStop(status: Int, code: String?, reason: String?, stage: String?) -> Bool {
        [400, 401, 403, 404, 405, 413, 429].contains(status)
            || ["not_configured", "provider_quota", "formatting_limit"].contains(code ?? "")
            || ["invalid_key", "api_disabled", "model_unavailable", "region_unavailable", "provider_access", "request_format", "billing_required", "quota"].contains(reason ?? "")
            || ["authentication", "configuration", "account_budget"].contains(stage ?? "")
    }
    private let file: URL
    private(set) var state: State
    init(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        file = directory.appendingPathComponent("budget.json")
        if FileManager.default.fileExists(atPath: file.path) {
            state = try JSONDecoder().decode(State.self, from: Data(contentsOf: file))
            guard state.approvalID == Self.approvalID, state.attempts.count <= 6 else { throw Failure.invalid }
        } else { state = State() }
    }
    func reserve(_ caseID: String) throws {
        guard !state.halted else { throw Failure.halted }
        guard state.attempts.count < 6 else { throw Failure.exhausted }
        state.attempts.append(.init(caseID: caseID, startedAt: Date()))
        try persist()
    }
    func halt() throws { state.halted = true; try persist() }
    private func persist() throws { try JSONEncoder().encode(state).write(to: file, options: .atomic) }
}
#endif
