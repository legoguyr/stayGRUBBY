import Foundation
import Supabase

/// Dish Recipe calls used by Dish Detail. Dish and Recipe are one Dish: a Dish has at most one
/// owned Recipe (`recipes.dish_id`, FOOD_ARCHITECTURE §3). The D1 multi-Recipe/Main actions remain
/// on the server as transitional structures and are not used by the app.
@MainActor enum DishRecipeService {
    /// The exact Recipe revision this cook was made from, if any (`recipe_cooks`).
    static func usedRecipe(for attemptID: UUID, dishID: UUID, request: SocialRequest) async throws -> RecipeCookSnapshot? {
        struct Response: Decodable { var usedRecipe: RecipeCookSnapshot? }
        var payload = SocialPayload(); payload.dishID = dishID; payload.attemptID = attemptID
        return try JSONDecoder().decode(Response.self, from: await request("recipes", "cook", payload)).usedRecipe
    }
    static func message(for error: Error) -> String {
        if error is URLError { return "Recipes need a connection. Try again when you’re online." }
        switch (error as? PostgrestError)?.code {
        case "40001": return "This Dish changed or is still syncing. Try again."
        case "42501": return "This Recipe is unavailable."
        default: return "Couldn’t load the Recipe. Try again."
        }
    }
}
