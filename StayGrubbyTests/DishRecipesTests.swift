import Foundation
import Testing
@testable import StayGrubby

/// D1: Dish Recipe read model and association rules (FOOD_ARCHITECTURE §3).
struct DishRecipesTests {
    private let dish = UUID(), other = UUID()

    @Test func explicitStartsAssociateAutomatically() {
        #expect(RecipeAssociation.resolve(.dish(dish)) == .automatic(dishID: dish))
        #expect(RecipeAssociation.resolve(.cookAgain(dish)) == .automatic(dishID: dish))
    }

    @Test func looseMatchesAreSuggestedOrAskedNeverMerged() {
        #expect(RecipeAssociation.resolve(.rankMyVersion(relatedDishIDs: [])) == .newDish)
        #expect(RecipeAssociation.resolve(.rankMyVersion(relatedDishIDs: [dish, dish])) == .suggest(dishID: dish))
        let asked = RecipeAssociation.resolve(.rankMyVersion(relatedDishIDs: [other, dish]))
        guard case .ask(let ids) = asked else { Issue.record("Several Dishes must be asked"); return }
        #expect(Set(ids) == [dish, other] && ids.count == 2)
    }

    @Test func decodesServerSetAndOffersMainFirstWithoutPreselecting() throws {
        let main = UUID(), older = UUID(), cook = UUID()
        func card(_ id: UUID, _ title: String) -> String {
            #"{"id":"\#(id)","isOwner":true,"content":{"title":"\#(title)","ingredients":[],"steps":[],"dietary":["vegan"]},"visibility":"private","revision":1,"createdAt":1,"updatedAt":1,"saved":false}"#
        }
        let json = """
        {"dishID":"\(dish)","mainRecipeID":"\(main)","chosenMainRecipeID":"\(main)","recipes":[
         {"recipe":\(card(older, "Old")),"dishLinked":true,"legacy":true,"linkedAttemptIDs":[],"usedByAttemptIDs":["\(cook)"]},
         {"recipe":\(card(main, "Main")),"dishLinked":true,"legacy":false,"linkedAttemptIDs":["\(cook)"],"usedByAttemptIDs":[]}]}
        """
        let set = try JSONDecoder().decode(DishRecipeSet.self, from: Data(json.utf8))
        #expect(set.main?.recipe.id == main && set.others.map(\.recipe.id) == [older])
        #expect(set.main?.recipe.content.dietary == ["vegan"])
        #expect(RecipeAssociation.cookAgainChoices(set) == [main, older])
        #expect(RecipeAssociation.cookAgainChoices(nil).isEmpty)
        // Main is a preference; only usedByAttemptIDs means "cooked from this Recipe".
        #expect(set.main?.usedByAttemptIDs.isEmpty == true && set.others.first?.usedByAttemptIDs == [cook])
    }
}
