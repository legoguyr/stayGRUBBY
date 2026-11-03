import Foundation
import Testing
@testable import StayGrubby

// Source-word/fact-lock expectations were superseded by the explicit Gemini-first decision.
@MainActor struct RecipeEngineAcceptanceTests {
    @Test func ingredientAndStepMovesRetainIdentityAndSerializeCanonicalOrder() throws {
        let a = RecipeComponent(title: "Sauce", ingredients: [.init(name: "tomatoes"),.init(name: "salt"),.init(name: "oil")], steps: [.init(instruction: "Heat oil."),.init(instruction: "Add tomatoes.")])
        let b = RecipeComponent(title: "Assembly", steps: [.init(instruction: "Serve sauce.")])
        var d = RecipeContent(title: "Fixture", components: [a,b])
        let ids = Set(d.orderedComponents.flatMap(\.ingredients).map(\.id))
        d.moveRecipeRow(a.ingredients[2].id, from: a.id, to: a.id, ingredient: true, at: 0)
        #expect(d.components![0].ingredients.map(\.name) == ["oil","tomatoes","salt"])
        d.moveRecipeRow(a.ingredients[1].id, from: a.id, to: b.id, ingredient: true, at: 0)
        d.moveRecipeRow(a.steps[1].id, from: a.id, to: a.id, ingredient: false, at: 0)
        #expect(d.components![0].steps[0].instruction == "Add tomatoes.")
        d.moveRecipeRow(b.steps[0].id, from: b.id, to: a.id, ingredient: false, at: 1)
        let saved = d.preparedForSave()
        let restored = try JSONDecoder().decode(RecipeContent.self, from: JSONEncoder().encode(saved))
        #expect(restored == saved && Set(restored.orderedComponents.flatMap(\.ingredients).map(\.id)) == ids)
        #expect(restored.orderedComponents.flatMap(\.ingredients).count == ids.count)
        for p in restored.orderedComponents { #expect(p.steps.map(\.order) == Array(p.steps.indices)); #expect(p.ingredients.map(\.order) == Array(p.ingredients.indices)) }
    }
    @Test func deterministicAllergensNeverMakeReligiousOrFreeOfClaims() {
        let a = RecipeAllergenAssessment.derive(["Parmesan", "tahini", "mayonnaise", "pasta", "peanuts or cashews (optional)", "stock"], hints: ["fish", "kosher"])
        #expect(Set(a.contains) == Set(["milk","sesame","egg"]))
        #expect(Set(a.possible) == Set(["wheat","peanuts","treeNuts"]))
        #expect(a.reviewIngredients.contains("stock"))
        #expect(!RecipeAllergenAssessment.safetyText.contains("safe for"))
    }
    @Test func onDeviceSuitabilityUsesObservedCapabilityAndCloudCooldownIsFriendly() {
        #expect(RecipeCreatorContract.onDeviceSuitable("Scramble 2 eggs in butter."))
        #expect(!RecipeCreatorContract.onDeviceSuitable(String(repeating: "Cook rice. ", count: 50)))
        #expect(!RecipeCreatorContract.onDeviceSuitable("Prepare a crisp separately, then top rice with the crisp."))
        #expect(RecipeImportFailure.quota.message.contains("cooldown"))
        for word in ["Gemini","Google","API","quota"] { #expect(!RecipeImportFailure.quota.message.contains(word)) }
        #expect(RecipeImportFailure.server(status: 429, data: Data(#"{"code":"provider_quota"}"#.utf8)) == .quota)
    }
}
