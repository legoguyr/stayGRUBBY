import Foundation
import Testing
@testable import StayGrubby

struct RecipeScalingTests {
    @Test func usableYieldOnly() {
        for text in ["4", "Serves 4", "4 servings", "Makes 4 servings", "servings: 4", "4 portions"] { #expect(RecipeScaling.canonicalServings(text) == 4) }
        for text in ["1 loaf", "About 4", "4–6 servings", "", "Makes 4", "200 servings"] { #expect(RecipeScaling.canonicalServings(text) == nil) }
        #expect(RecipeScaling.canonicalServings(nil) == nil)
    }
    @Test func exactNumbersAndUnits() {
        for (input,expected) in [("2","3"),("1/2","3/4"),("1 1/2","2 1/4"),("0.25","3/8"),("1-2","1 1/2-3"),("½","3/4")] {
            for unit in ["", "g", "mL", "cup", "clove"] {
                let row = RecipeIngredient(quantity: input, unit: unit, name: "ingredient")
                let scaled = RecipeScaling.ingredient(row, from: 4, to: 6)
                #expect(scaled.quantity == expected); #expect(scaled.unit == unit); #expect(scaled.id == row.id)
            }
        }
    }
    @Test func uncertaintyAndBoundsRemain() {
        for quantity in ["", "to taste", "a little", "about 2", "as needed", "1 (400 g)", "999999999999"] {
            let row = RecipeIngredient(quantity: quantity, name: "salt")
            #expect(RecipeScaling.ingredient(row, from: 4, to: 8) == row)
        }
        let perPerson = RecipeIngredient(quantity: "2", name: "kale", note: "per person")
        #expect(RecipeScaling.ingredient(perPerson, from: 4, to: 8) == perPerson)
        #expect(RecipeScaling.scaled(.parse("1")!, from: 0, to: 4) == nil)
        #expect(RecipeScaling.scaled(.parse("1")!, from: 4, to: 101) == nil)
    }
    @Test func projectionDoesNotMutateRecipe() {
        let original = RecipeContent(title: "Soup", components: [.init(ingredients: [.init(quantity: "1/2", unit: "L", name: "water")])], yield: "Serves 4")
        let data = try! JSONEncoder().encode(original)
        let projection = RecipeScaling.content(original, servings: 2)
        #expect(projection.orderedComponents[0].ingredients[0].quantity == "1/4")
        #expect(try! JSONEncoder().encode(original).count == data.count)
        #expect(original.yield == "Serves 4"); #expect(original.orderedComponents[0].ingredients[0].quantity == "1/2")
        #expect(RecipeScaling.content(original, servings: 4) == original)
    }
}
