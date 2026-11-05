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
    @Test func ingredientSpecificMassVolumeConversionAndScaling() {
        for (name, grams) in [("Arborio rice",180),("risotto rice",180),("all-purpose flour",120),("granulated sugar",198),("butter",227),("honey",336),("cocoa powder",84)] {
            let source = RecipeIngredient(quantity: String(grams), unit: "g", name: name)
            let us = RecipeUnits.ingredient(source, mode: .us, base: nil, servings: nil)
            #expect(us.quantity == "≈ 1" && us.unit == "cup")
            let metric = RecipeUnits.ingredient(.init(quantity: "1/2",unit:"cup",name:name),mode:.metric,base:2,servings:4)
            #expect(metric.quantity == "≈ " + String(grams) && metric.unit == "g")
        }
        let rice = RecipeIngredient(quantity:"400",unit:"g",name:"Arborio/risotto rice",preparation:"rinsed")
        let us = RecipeUnits.ingredient(rice,mode:.us,base:nil,servings:nil)
        #expect(us.quantity == "≈ 2.22" && us.unit == "cup" && us.preparation == "rinsed" && us.id == rice.id)
        let range = RecipeUnits.ingredient(.init(quantity:"90-180",unit:"g",name:"dry Arborio rice"),mode:.us,base:2,servings:4)
        #expect(range.quantity == "≈ 1–2" && range.unit == "cup")
        #expect(RecipeUnits.ingredient(.init(quantity:"90",unit:"g",name:"Arborio rice"),mode:.us,base:nil,servings:nil).quantity == "≈ ½")
    }
    @Test func legacyMeasuredLinesConvertWithoutCanonicalWritesOrDensityGuesses() {
        for source in [RecipeIngredient(name:"400 g Arborio rice"), .init(quantity:"400 g",name:"Arborio rice"), .init(name:"400g Arborio rice")] {
            let value = RecipeUnits.ingredient(source,mode:.us,base:nil,servings:nil)
            #expect(value.quantity == "≈ 2.22" && value.unit == "cup" && value.name == "Arborio rice")
            #expect(RecipeUnits.ingredient(source,mode:.original,base:nil,servings:nil) == source)
        }
        for source in [RecipeIngredient(quantity:"400",unit:"g",name:"cooked Arborio rice"), .init(quantity:"400",unit:"g",name:"rice"), .init(quantity:"400",unit:"g",name:"rice flour")] {
            #expect(RecipeUnits.ingredient(source,mode:.us,base:nil,servings:nil).unit == "oz")
        }
        let ambiguous = RecipeIngredient(quantity:"to taste",unit:"",name:"honey")
        #expect(RecipeUnits.ingredient(ambiguous,mode:.metric,base:2,servings:4) == ambiguous)
        var source = RecipeContent(title:"Rice",ingredients:["400g Arborio rice"],steps:["Cook as written."])
        source.yield = "4 servings"; let before = source
        #expect(RecipeUnits.content(source,mode:.us,servings:8).orderedComponents[0].ingredients[0].quantity == "≈ 4.44")
        #expect(source == before && RecipeUnits.content(source,mode:.original,servings:nil).ingredients == before.ingredients)
    }

}
