import Foundation
import Supabase

@MainActor protocol RecipeImportBackend: AccountBackend { func importRecipeText(_ raw: String) async throws -> Data }
extension SupabaseAccountBackend: RecipeImportBackend {
    func importRecipeText(_ raw: String) async throws -> Data {
        #if DEBUG
        RecipeIntelligenceDiagnostics.shared.sessionValid = client.auth.currentSession.map { !$0.isExpired }
        RecipeIntelligenceDiagnostics.shared.stage = "edge_function"
        #endif
        guard let user = client.auth.currentSession?.user.id else { throw RecipeImportFailure.session }
        struct Input: Encodable { let text: String; let cloudConsent: Bool }
        let result: Data
        do {
            result = try await client.functions.invoke("recipe-import", options: FunctionInvokeOptions(body: Input(text: raw, cloudConsent: true)), decode: { data, response in
                #if DEBUG
                let configured = response.value(forHTTPHeaderField: "x-recipe-configured").map { $0 == "true" }
                Task { @MainActor in RecipeIntelligenceDiagnostics.shared.response(status: response.statusCode, configured: configured) }
                #endif
                return data
            })
        } catch FunctionsError.httpError(let code, let data) {
            #if DEBUG
            RecipeIntelligenceDiagnostics.shared.response(status: code, data: data)
            #endif
            throw RecipeImportFailure.server(status: code, data: data)
        } catch is CancellationError { throw CancellationError() }
        catch {
            try Task.checkCancellation()
            #if DEBUG
            RecipeIntelligenceDiagnostics.shared.result = "network"
            #endif
            throw RecipeImportFailure.network
        }
        try Task.checkCancellation()
        guard client.auth.currentSession?.user.id == user else { throw AccountFoundationError.identityChanged }
        return result
    }
}
