import Foundation
import Supabase

/// D1 Unified Dish read model for one Dish's Recipe side (FOOD_ARCHITECTURE §3).
/// Decoded from `recipes` actions `dish_recipes`, `link_dish_recipe`,
/// `unlink_dish_recipe` and `set_main_recipe`. The server computes the related-Recipe
/// union and the deterministic Main, so every client shows the same Main.
nonisolated struct DishRecipeSet: Codable, Sendable {
    // Not Equatable: `Recipe` has no value equality, and a partial one would hide link changes
    // from SwiftUI state updates.
    struct Entry: Codable, Sendable {
        var recipe: Recipe
        /// A Dish-level association (Dish Recipe), including mirrored legacy links.
        var dishLinked: Bool
        /// The pre-V2 family link for this Dish.
        var legacy: Bool
        /// Active cooks of this Dish currently exact-linked to this Recipe.
        var linkedAttemptIDs: [UUID]
        /// Active cooks of this Dish recorded as made from this Recipe (`recipe_cooks`).
        var usedByAttemptIDs: [UUID]
    }
    var dishID: UUID
    /// Effective Main: chosen, else legacy family link, else oldest related Recipe.
    var mainRecipeID: UUID?
    /// The user's explicit choice, used as the compare-and-swap value for Set as Main.
    var chosenMainRecipeID: UUID?
    var recipes: [Entry]

    var main: Entry? { recipes.first { $0.recipe.id == mainRecipeID } }
    var others: [Entry] { recipes.filter { $0.recipe.id != mainRecipeID } }
}

/// How a Recipe becomes related to a Dish (FOOD_ARCHITECTURE §3.3). Explicit provenance
/// associates automatically; loose matches are only suggested; several Dishes are asked.
/// Never infers use from a title, photo or fuzzy match, and never moves a cook.
nonisolated enum RecipeAssociation: Equatable, Sendable {
    /// Associate without asking (the user's own explicit act or exact provenance).
    case automatic(dishID: UUID)
    /// Offer a highlighted default the user confirms; dismissing keeps records separate.
    case suggest(dishID: UUID)
    /// Several Dishes relate to the Recipe: the user picks one (or a new Dish).
    case ask(dishIDs: [UUID])
    /// No related Dish: the cook starts a new Dish prefilled from the Recipe.
    case newDish

    enum Start: Equatable, Sendable {
        /// Add Recipe / Link Existing started on this Dish or one of its cooks.
        case dish(UUID)
        /// Cook Again on this Dish, choosing one of its Recipes.
        case cookAgain(UUID)
        /// Rank My Version on a Recipe, with the Dishes it relates to.
        case rankMyVersion(relatedDishIDs: [UUID])
    }

    static func resolve(_ start: Start) -> RecipeAssociation {
        switch start {
        case .dish(let id), .cookAgain(let id):
            return .automatic(dishID: id)
        case .rankMyVersion(let related):
            let unique = Array(Set(related)).sorted { $0.uuidString < $1.uuidString }
            switch unique.count {
            case 0: return .newDish
            case 1: return .suggest(dishID: unique[0])
            default: return .ask(dishIDs: unique)
            }
        }
    }

    /// Cook Again never preselects a Recipe; the Main is offered first when one exists.
    static func cookAgainChoices(_ set: DishRecipeSet?) -> [UUID] {
        guard let set else { return [] }
        return (set.main.map { [$0] } ?? []).map(\.recipe.id) + set.others.map(\.recipe.id)
    }
}

/// Calls for the D1 `recipes` Dish Recipe actions. Every result is the Dish's full set.
@MainActor enum DishRecipeService {
    static func load(_ dishID: UUID, request: SocialRequest) async throws -> DishRecipeSet {
        var payload = SocialPayload(); payload.dishID = dishID
        return try JSONDecoder().decode(DishRecipeSet.self, from: await request("recipes", "dish_recipes", payload))
    }
    static func mutate(_ action: String, dishID: UUID, recipeID: UUID, request: SocialRequest) async throws -> DishRecipeSet {
        precondition(["link_dish_recipe", "unlink_dish_recipe"].contains(action))
        var payload = SocialPayload(); payload.dishID = dishID; payload.recipeID = recipeID
        return try JSONDecoder().decode(DishRecipeSet.self, from: await request("recipes", action, payload))
    }
    /// Compare-and-swap on the user's previous explicit choice (nil when none was chosen).
    static func setMain(_ recipeID: UUID?, dishID: UUID, expected: UUID?, request: SocialRequest) async throws -> DishRecipeSet {
        var payload = SocialPayload(); payload.dishID = dishID; payload.recipeID = recipeID; payload.expectedMainID = expected
        return try JSONDecoder().decode(DishRecipeSet.self, from: await request("recipes", "set_main_recipe", payload))
    }
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
        default: return "Couldn’t load Recipes. Try again."
        }
    }
}
