#if DEBUG
import SwiftUI
import FoundationModels

@MainActor @Observable final class RecipeIntelligenceDiagnostics {
    static let shared = RecipeIntelligenceDiagnostics()
    var cloudAllowed = false
    var sessionValid: Bool?
    var configured: Bool?
    var provider = "None"
    var stage = "Not attempted"
    var result = "Not attempted"
    var httpStatus: Int?
    var providerStatus: Int?
    var timestamp: Date?
    func response(status: Int, data: Data? = nil, configured: Bool? = nil) {
        httpStatus = status; timestamp = Date()
        if status == 401 || status == 403 { sessionValid = false }
        if let configured { self.configured = configured }
        guard let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String:Any] else { return }
        if let value = object["stage"] as? String, ["request","authentication","configuration","account_budget","provider","provider_response","validation","complete"].contains(value) { stage = value; if ["provider","provider_response","validation","complete"].contains(value) { self.configured = true; sessionValid = true } }
        if let value = object["code"] as? String, value.range(of: #"^[a-z_]{1,48}$"#, options: .regularExpression) != nil { result = value }
        if let value = object["reason"] as? String, ["invalid_key","api_disabled","model_unavailable","region_unavailable","billing_required","provider_access","request_format","quota","provider_unavailable","structured_json","incomplete_output","object_fields","field_type","field_empty","field_length","component_count","row_count","component_empty","total_ingredients","total_steps","total_rows","source_empty","source_number","source_word","quantity_unit_pair","metadata_phrase","ingredient_phrase","invalid_quantity"].contains(value) { result += " · " + value }
        providerStatus = object["providerStatus"] as? Int
        if object["code"] as? String == "not_configured" { self.configured = false }
    }
}
struct RecipeIntelligenceDiagnosticsView: View {
    @Environment(\.recipeImportRequest) private var request
    @State private var diagnostics = RecipeIntelligenceDiagnostics.shared
    var body: some View {
        Form {
            Section("Recipe Intelligence · Debug") {
                LabeledContent("Apple Foundation Models", value: String(describing: SystemLanguageModel.default.availability))
                LabeledContent("Gemini", value: diagnostics.configured.map { $0 ? "Configured (last response)" : "Not configured" } ?? "Not checked")
                LabeledContent("Cloud permission", value: diagnostics.cloudAllowed ? "Allowed for last import" : "Not allowed")
                LabeledContent("Supabase session", value: diagnostics.sessionValid.map { $0 ? "Valid at last request" : "Invalid" } ?? (request == nil ? "No account connection" : "Not checked"))
                LabeledContent("Last provider", value: diagnostics.provider)
                LabeledContent("Last stage", value: diagnostics.stage)
                LabeledContent("Last result", value: diagnostics.result)
                if let status = diagnostics.httpStatus { LabeledContent("Function HTTP status", value: String(status)) }
                if let status = diagnostics.providerStatus { LabeledContent("Provider HTTP status", value: String(status)) }
                if let timestamp = diagnostics.timestamp { LabeledContent("Last update", value: timestamp.formatted()) }
            }
            Text("No keys, tokens or recipe text are collected here. Configuration/session status reflects the last request, not a new provider call.").font(.footnote)
        }.navigationTitle("Recipe Intelligence")
    }
}
#endif
