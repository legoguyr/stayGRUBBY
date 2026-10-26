import Foundation
import Supabase

@MainActor protocol RecipeImportBackend: AccountBackend { func importRecipeText(_ raw: String) async throws -> Data }
extension SupabaseAccountBackend: RecipeImportBackend {
    func importRecipeText(_ raw: String) async throws -> Data {
        guard let user = client.auth.currentSession?.user.id else { throw RecipeImportFailure.unavailable }
        struct Input: Encodable { let text: String; let cloudConsent: Bool }
        let result: Data
        do {
            result = try await client.functions.invoke("recipe-import", options: FunctionInvokeOptions(body: Input(text: raw, cloudConsent: true)), decode: { data, _ in data })
        } catch FunctionsError.httpError(let code, _) {
            switch code {
            case 413: throw RecipeImportFailure.tooLong
            case 429: throw RecipeImportFailure.rateLimited
            case 504: throw RecipeImportFailure.timeout
            case 422: throw RecipeImportFailure.invalid
            default: throw RecipeImportFailure.unavailable
            }
        }
        try Task.checkCancellation()
        guard client.auth.currentSession?.user.id == user else { throw AccountFoundationError.identityChanged }
        return result
    }
}
