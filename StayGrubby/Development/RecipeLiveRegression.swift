#if DEBUG && RECIPE_LIVE_REGRESSION
import SwiftUI
import Supabase

/// Special diagnostic build only. Restores the existing SDK session without
/// provisioning, opening a cooking store, syncing, signing in, or saving Recipes.
struct RecipeLiveRegressionView: View {
    static var requested: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--recipe-live-regression") && args.contains(RecipeRegressionBudget.approvalID)
    }
    struct Case: Codable { var id: String; var raw: String }
    struct Plan: Codable { var approvalID: String; var cases: [Case] }
    struct Entry: Codable {
        var id: String
        var status: Int?
        var stage: String?
        var code: String?
        var reason: String?
        var requestID: String?
        var duration: Double
        var wire: Data?
        var draft: RecipeContent?
        var nativeFailure: String?
    }
    struct Report: Codable { var entries: [Entry] = []; var finished = false; var blocked: String? }
    struct Wire: Sendable { var data: Data; var status: Int; var requestID: String?; var stage: String? }
    @State private var message = "Preparing approved Recipe regression"
    @State private var started = false
    private static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RecipeLiveRegression/\(RecipeRegressionBudget.approvalID)", isDirectory: true)
    }
    var body: some View {
        VStack(spacing: 20) {
            Text("DEVELOPMENT · RECIPE REGRESSION").font(.caption.bold())
            Text(message)
            Text("No Recipes are saved. Normal cooking storage and sync are not opened.").font(.footnote)
        }.padding().task { guard !started else { return }; started = true; await run() }
    }
    private func run() async {
        var report = Report()
        let directory = Self.directory, reportURL = directory.appendingPathComponent("report.json")
        func write() throws { try JSONEncoder().encode(report).write(to: reportURL, options: .atomic) }
        do {
            let budget = try RecipeRegressionBudget(directory: directory)
            if FileManager.default.fileExists(atPath: reportURL.path) { report = try JSONDecoder().decode(Report.self, from: Data(contentsOf: reportURL)) }
            let planURL = FileManager.default.temporaryDirectory.appendingPathComponent("RecipeLiveRegression-77dd8c13.plan.json")
            let plan = try JSONDecoder().decode(Plan.self, from: Data(contentsOf: planURL))
            guard plan.approvalID == RecipeRegressionBudget.approvalID, (1...6).contains(plan.cases.count), Set(plan.cases.map(\.id)).count == plan.cases.count else { throw RecipeRegressionBudget.Failure.invalid }
            guard !budget.state.halted else { throw RecipeRegressionBudget.Failure.halted }
            report.finished = false
            report.blocked = nil
            let backend = SupabaseAccountBackend(configuration: try .load())
            guard let identity = try await backend.restoredIdentity() else { report.blocked = "existing_session_missing"; try write(); message = "Existing session unavailable; no provider call made."; return }
            let args = ProcessInfo.processInfo.arguments
            let diagnosticReview = args.contains("--recipe-regression-diagnostic-review")
            let position = args.firstIndex(of: "--recipe-regression-batch")
            let batch = position.flatMap { $0+1 < args.count ? Int(args[$0+1]) : nil } ?? 1
            // Inspect this request's result before explicitly launching another fixture.
            guard batch == 1 else { throw RecipeRegressionBudget.Failure.invalid }
            let startIndex = budget.state.attempts.count
            let end = min(startIndex + batch, plan.cases.count)
            guard startIndex < end else { message = "Approved plan completed; no additional calls."; return }
            for index in startIndex..<end {
                let item = plan.cases[index]
                try RecipeImportValidation.input(item.raw)
                if let previous = budget.state.attempts.last {
                    // Distinct fixtures, not retries. Keep below the existing 3/minute guard.
                    let wait = max(0, 22 - Date().timeIntervalSince(previous.startedAt))
                    if wait > 0 { try await Task.sleep(for: .seconds(wait)) }
                }
                guard backend.client.auth.currentSession?.user.id == identity.userID else { throw AccountFoundationError.identityChanged }
                try budget.reserve(item.id)
                message = "Approved call \(index+1) of at most 6 · \(item.id)"
                let began = Date()
                var entry = Entry(id: item.id, duration: 0)
                struct Input: Encodable { var text: String; let cloudConsent = true; let contractVersion = 3; var diagnosticReview: Bool? }
                do {
                    let wire: Wire = try await backend.client.functions.invoke("recipe-import", options: FunctionInvokeOptions(body: Input(text: item.raw, diagnosticReview: diagnosticReview ? true : nil)), decode: { data, response in
                        Wire(data: data, status: response.statusCode, requestID: response.value(forHTTPHeaderField: "x-recipe-request-id"), stage: response.value(forHTTPHeaderField: "x-recipe-stage"))
                    })
                    entry.status = wire.status; entry.requestID = wire.requestID; entry.stage = wire.stage
                    // Private diagnostic artifact, never stdout/production logging or Git.
                    entry.wire = wire.data
                    do {
                        let extraction = try RecipeImportValidation.decode(wire.data)
                        entry.draft = try RecipeImportValidation.review(extraction, raw: item.raw, dishTitle: "", provider: "Gemini live regression").draft
                    } catch { entry.nativeFailure = (error as? RecipeImportFailure)?.rawValue ?? "native_validation" }
                } catch FunctionsError.httpError(let status, let data) {
                    entry.status = status
                    let object = (try? JSONSerialization.jsonObject(with: data)) as? [String:Any]
                    // Private test artifact only; still rejected and never opened/saved as a Recipe.
                    if diagnosticReview, status == 422, object?["review"] is [String:Any] { entry.wire = data }
                    func safe(_ name: String) -> String? { guard let value = object?[name] as? String, value.range(of: #"^[a-z_]{1,48}$"#, options: .regularExpression) != nil else { return nil }; return value }
                    entry.stage = safe("stage"); entry.code = safe("code"); entry.reason = safe("reason")
                    entry.requestID = (object?["requestID"] as? String).flatMap { UUID(uuidString: $0)?.uuidString }
                    if RecipeRegressionBudget.mustStop(status: status, code: entry.code, reason: entry.reason, stage: entry.stage) { try budget.halt() }
                } catch { entry.nativeFailure = error is CancellationError ? "cancelled" : "network" }
                entry.duration = Date().timeIntervalSince(began)
                report.entries.append(entry); try write()
                if budget.state.halted { message = "Stopped on quota, billing, authentication or configuration signal."; return }
                if Task.isCancelled { return }
            }
            report.finished = true; try write(); message = "Batch complete: \(report.entries.count) attempts recorded. Nothing saved to Food Bible."
        } catch {
            report.blocked = "diagnostic_precondition_or_budget"; try? write()
            message = "Diagnostic stopped safely. No automatic retry."
        }
    }
}
#endif
