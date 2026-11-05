import Foundation
import Testing
@testable import StayGrubby

struct RecipeUnitsTests {
    private func row(_ quantity: String, _ unit: String) -> RecipeIngredient { .init(quantity: quantity, unit: unit, name: "ingredient", preparation: "chopped", note: "optional") }
    @Test func metricConversionsPreservePreparationRangesAndIdentity() {
        for (quantity, unit, expected, target) in [("1","cup","≈ 237","mL"),("1/2-1","cup","≈ 118–237","mL"),("1.5","tbsp","≈ 22","mL"),("1","lb","≈ 454","g")] {
            let original = row(quantity,unit), value = RecipeUnits.ingredient(original, mode: .metric, base: nil, servings: nil)
            #expect(value.quantity == expected && value.unit == target)
            #expect(value.id == original.id && value.name == original.name && value.preparation == original.preparation && value.note == original.note)
        }
    }
    @Test func servingAndUnitMathComposeWithoutDensityAssumptions() {
        let value = RecipeUnits.ingredient(row("1/2","cup"), mode: .metric, base: 2, servings: 4)
        #expect(value.quantity == "≈ 237" && value.unit == "mL")
        let approximate = RecipeUnits.ingredient(row("about 1/2","cup"), mode: .metric, base: 2, servings: 4)
        #expect(approximate.quantity == "≈ 237")
        let sameSystem = RecipeUnits.ingredient(row("1/2","cup"), mode: .us, base: 2, servings: 4)
        #expect(sameSystem.quantity == "1" && sameSystem.unit == "cup")
        let volume = RecipeUnits.ingredient(row("200","mL"), mode: .us, base: nil, servings: nil)
        #expect(volume.unit == "cup" && volume.quantity == "≈ 0.85")
        #expect(RecipeUnits.ingredient(row("1","kg"), mode: .us, base: nil, servings: nil).quantity == "≈ 2.2")
    }
    @Test func unsupportedAndSemanticAmountsRemainUntouched() {
        for value in [row("to taste","tsp"),row("a little","cup")] {
            #expect(RecipeUnits.ingredient(value, mode: .metric, base: 2, servings: 4) == value)
        }
        for unit in ["cloves","heaping cup","stick"] {
            let result = RecipeUnits.ingredient(row("1",unit), mode: .metric, base: 2, servings: 4)
            #expect(result.unit == unit && result.quantity == "2")
        }
        var perPerson = row("1","cup"); perPerson.note = "per person"
        #expect(RecipeUnits.ingredient(perPerson, mode: .metric, base: 2, servings: 4) == perPerson)
    }
    @Test func canonicalContentAndSnapshotNeverChangeOnModeSwitch() {
        var content = RecipeContent(title: "Source", description: "Keep this", yield: "Serves 2", photoID: UUID())
        content.components = [.init(ingredients: [row("1/2","cup")], steps: [.init(instruction: "Bake at 350°F for 10 minutes.")])]
        let before = content
        let metric = RecipeUnits.content(content, mode: .metric, servings: 4)
        #expect(content == before && metric.orderedComponents[0].steps == before.orderedComponents[0].steps)
        #expect(metric.photoID == before.photoID && metric.description == before.description)
        #expect(RecipeUnits.content(content, mode: .original, servings: nil).orderedComponents[0].ingredients[0].quantity == "1/2")
        #expect(RecipeUnits.content(content, mode: .metric, servings: 4) == metric)
    }
}
