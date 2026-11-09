import Foundation
import Testing
@testable import StayGrubby

/// Import-time Diet suggestions from ingredient evidence (FOOD_ARCHITECTURE §5).
struct RecipeDietInferenceTests {
    @Test func plantOnlyRecipeIsVeganVegetarianAndDairyFree() {
        let tags = RecipeDietInference.derive(["2 cups chickpeas", "1 onion", "2 tbsp olive oil", "1 cup almond milk", "1 tsp cumin"])
        #expect(tags.isSuperset(of: [.vegan, .vegetarian, .dairyFree]))
        #expect(tags.contains(.glutenFree), "No gluten source and nothing unclear")
        #expect(!tags.contains(.kosher) && !tags.contains(.halal), "Certification is never inferred")
    }
    @Test func meatFreeWithDairyIsVegetarianOnly() {
        let tags = RecipeDietInference.derive(["2 eggs", "1 cup cheddar cheese", "1 cup flour", "1 tbsp butter"])
        #expect(tags == [.vegetarian], "Flour is not clearly gluten-free; butter is dairy")
    }
    @Test func meatAndUnclearIngredientsBlockClaims() {
        #expect(RecipeDietInference.derive(["1 lb chicken thighs", "1 cup rice"]).isDisjoint(with: [.vegetarian, .vegan]))
        let stock = RecipeDietInference.derive(["4 cups stock", "1 carrot"])
        #expect(!stock.contains(.vegetarian) && !stock.contains(.glutenFree), "Plain stock may be meat-based and contain gluten")
        #expect(RecipeDietInference.derive(["4 cups vegetable stock", "1 carrot"]).contains(.vegetarian))
        #expect(!RecipeDietInference.derive(["2 tbsp soy sauce", "tofu"]).contains(.glutenFree))
        #expect(RecipeDietInference.derive(["2 tbsp tamari", "tofu"]).contains(.glutenFree))
        #expect(!RecipeDietInference.derive(["1 tbsp honey", "oats"]).contains(.vegan))
        #expect(!RecipeDietInference.derive(["1/2 cup parmesan", "spinach"]).contains(.vegetarian), "Rennet cheeses are not clearly vegetarian")
        #expect(RecipeDietInference.derive([]).isEmpty)
    }
}
