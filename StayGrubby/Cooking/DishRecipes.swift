import Foundation

/// D1 Unified Dish read model for one Dish's Recipe side (FOOD_ARCHITECTURE §3).
/// Decoded from `recipes` actions `dish_recipes`, `link_dish_recipe`,
/// `unlink_dish_recipe` and `set_main_recipe`. The server computes the related-Recipe
/// union and the deterministic Main, so every client shows the same Main.
nonisolated struct DishRecipeSet: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Sendable {
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

extension Recipe: Equatable {
    static func == (lhs: Recipe, rhs: Recipe) -> Bool {
        lhs.id == rhs.id && lhs.revision == rhs.revision && lhs.updatedAt == rhs.updatedAt
            && lhs.isOwner == rhs.isOwner && lhs.visibility == rhs.visibility && lhs.content == rhs.content
    }
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
