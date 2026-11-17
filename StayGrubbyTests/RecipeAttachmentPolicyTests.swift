import Foundation
import Testing
@testable import StayGrubby

/// Connected Recipe sharing decisions (November 16, 2026).
struct RecipeAttachmentPolicyTests {
    private func recipe(owner: Bool = true, visibility: String = "private") -> Recipe {
        Recipe(id: UUID(), isOwner: owner, content: RecipeContent(title: "Soup"), visibility: visibility, revision: 3, createdAt: 1, updatedAt: 1, saved: false)
    }
    @Test func cookSpecificRecipeWinsThenTheDishOwnRecipe() {
        let exact = recipe(), dish = recipe()
        #expect(RecipeAttachmentPolicy.resolve(shareOption: exact, dishRecipe: dish)?.id == exact.id)
        #expect(RecipeAttachmentPolicy.resolve(shareOption: nil, dishRecipe: dish)?.id == dish.id)
        #expect(RecipeAttachmentPolicy.resolve(shareOption: nil, dishRecipe: nil) == nil, "No Recipe, no attachment")
        #expect(RecipeAttachmentPolicy.resolve(shareOption: nil, dishRecipe: recipe(owner: false)) == nil, "Only the poster's own Recipe")
    }
    @Test func onlyAlreadySharedRecipesArePreselectedAndPrivateOnesNeedConsent() {
        #expect(RecipeAttachmentPolicy.selectedByDefault(recipe(visibility: "friends")))
        #expect(!RecipeAttachmentPolicy.selectedByDefault(recipe(visibility: "private")))
        #expect(!RecipeAttachmentPolicy.selectedByDefault(recipe(owner: false, visibility: "friends")))
        #expect(RecipeAttachmentPolicy.changesVisibility(recipe(visibility: "private")))
        #expect(!RecipeAttachmentPolicy.changesVisibility(recipe(visibility: "friends")))
    }
}
