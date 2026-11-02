import Foundation
import Testing
@testable import StayGrubby

@MainActor struct RecipeRegressionBudgetTests {
    private func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("recipe-budget-\(UUID())", isDirectory: true) }
    @Test func sixReservationsSurviveRelaunchAndSeventhNeverRuns() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        for n in 0..<6 { let budget = try RecipeRegressionBudget(directory: root); try budget.reserve("case-\(n)") }
        let restored = try RecipeRegressionBudget(directory: root)
        #expect(restored.state.attempts.count == 6)
        #expect(throws: (any Error).self) { try restored.reserve("seventh") }
        #expect(try RecipeRegressionBudget(directory: root).state.attempts.count == 6)
    }
    @Test func quotaHaltPersistsAndBlocksLaterProviderWork() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let budget = try RecipeRegressionBudget(directory: root); try budget.reserve("first"); try budget.halt()
        let restored = try RecipeRegressionBudget(directory: root)
        #expect(throws: (any Error).self) { try restored.reserve("after-quota") }
        #expect(restored.state.attempts.count == 1)
    }
    @Test func authenticationConfigurationAndProviderLimitsStopTheInvestigation() {
        for status in [400, 401, 403, 404, 405, 413, 429] {
            #expect(RecipeRegressionBudget.mustStop(status: status, code: nil, reason: nil, stage: nil))
        }
        for reason in ["invalid_key", "api_disabled", "model_unavailable", "region_unavailable", "provider_access", "request_format", "billing_required", "quota"] {
            #expect(RecipeRegressionBudget.mustStop(status: 503, code: "provider_unavailable", reason: reason, stage: "provider"))
        }
        #expect(RecipeRegressionBudget.mustStop(status: 503, code: "not_configured", reason: nil, stage: "configuration"))
        for stage in ["authentication", "configuration", "account_budget"] {
            #expect(RecipeRegressionBudget.mustStop(status: 503, code: "service_unavailable", reason: nil, stage: stage))
        }
        for (status, code, reason, stage) in [(503, "provider_unavailable", "provider_unavailable", "provider"), (504, "formatting_timeout", "", "provider"), (422, "invalid_recipe", "source_word", "validation")] {
            #expect(!RecipeRegressionBudget.mustStop(status: status, code: code, reason: reason, stage: stage))
        }
    }
    @Test func corruptOrDifferentApprovalStateFailsClosed() throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("budget.json")
        try Data("invalid".utf8).write(to: file)
        #expect(throws: (any Error).self) { _ = try RecipeRegressionBudget(directory: root) }
        var state = RecipeRegressionBudget.State(); state.approvalID = "unapproved"
        try JSONEncoder().encode(state).write(to: file)
        #expect(throws: (any Error).self) { _ = try RecipeRegressionBudget(directory: root) }
    }
}
