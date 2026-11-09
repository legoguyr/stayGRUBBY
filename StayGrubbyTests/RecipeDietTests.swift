import Foundation
import Testing
@testable import StayGrubby

/// Recipe Diet as written vs cook as made (FOOD_ARCHITECTURE §5).
@MainActor struct RecipeDietTests {
    @Test func recipeDietIsDietOnlyAndSorted() {
        var content = RecipeContent(title: "Stew")
        content.dietTags = [.vegan, .halal, .glutenFree]
        #expect(content.dietary == ["glutenFree", "vegan"], "Certification never stored on a Recipe")
        content.dietary = ["vegan", "kosher", "nonsense"]
        #expect(content.dietTags == [.vegan])
        content.dietTags = []
        #expect(content.dietary == nil)
    }

    @Test func cookingFromARecipePrefillsDietAndContainsForConfirmation() {
        var snapshot = RecipeContent(title: "Bean stew")
        snapshot.dietary = ["vegan"]
        snapshot.allergens = RecipeAllergenAssessment(contains: ["soy"], possible: ["wheat"])
        let claim = SocialCookingClaim(id: UUID(), itemID: UUID(), kind: "recipe", completed: false,
                                       metadata: .init(title: "Bean stew"), recipeOriginID: UUID(), recipeSnapshot: snapshot)
        let draft = claim.draft()
        #expect(draft.dietary == [.vegan] && draft.contains == [.soy] && draft.prefilledFromRecipe)
        #expect(!draft.contains.contains(.wheat), "Possible is never prefilled")
        let plain = SocialCookingClaim(id: UUID(), itemID: UUID(), kind: "recipe", completed: false,
                                       metadata: .init(title: "Toast"), recipeOriginID: UUID(), recipeSnapshot: RecipeContent(title: "Toast"))
        #expect(!plain.draft().prefilledFromRecipe && plain.draft().dietary.isEmpty)
    }

    @Test func foodBibleDietFilterMatchesAnySelectedDiet() {
        var vegan = CookbookEntry(recipeID: UUID(), dishTitle: "A", recipeTitle: "A", revision: 1); vegan.dietary = ["vegan"]
        var gf = CookbookEntry(recipeID: UUID(), dishTitle: "B", recipeTitle: "B", revision: 1); gf.dietary = ["glutenFree"]
        let none = CookbookEntry(recipeID: UUID(), dishTitle: "C", recipeTitle: "C", revision: 1)
        var filters = RecipeFilters(); filters.diets = ["vegan"]
        #expect(filters.count(.diet) == 1)
        #expect(filters.entries([vegan, gf, none], query: "", sort: .alphabetical).map(\.id) == [vegan.id])
        filters.diets = ["vegan", "glutenFree"]
        #expect(filters.entries([vegan, gf, none], query: "", sort: .alphabetical).count == 2)
    }
}
