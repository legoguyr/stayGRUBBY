import Foundation
import SwiftData
import Testing
@testable import StayGrubby

@MainActor struct FoodBibleTests {
    @Test func legacyRecipeHasStableSingleComponentWithoutGuessingQuantities() throws {
        let bytes = Data(#"{"title":"Soup","ingredients":["1 1/2 cups stock"],"steps":["Simmer"]}"#.utf8)
        let a = try JSONDecoder().decode(RecipeContent.self, from: bytes)
        let b = try JSONDecoder().decode(RecipeContent.self, from: bytes)
        #expect(a.orderedComponents == b.orderedComponents)
        #expect(a.orderedComponents.count == 1 && a.orderedComponents[0].title == nil)
        #expect(a.orderedComponents[0].ingredients[0].name == "1 1/2 cups stock")
        #expect(a.orderedComponents[0].ingredients[0].quantity.isEmpty)
        #expect(a.components == nil && a.isValidDraft)
    }
    @Test func structuredDraftRoundTripsAndReordersWithoutLosingIdentity() throws {
        let meat = RecipeComponent(title: "Short rib", ingredients: [.init(quantity: "1 1/2", unit: "lb", name: "short rib", preparation: "trimmed")], steps: [.init(instruction: "Braise at 300°F")])
        let sauce = RecipeComponent(title: "Sauce", ingredients: [.init(quantity: "250", unit: "mL", name: "wine")], steps: [.init(instruction: "Reduce")])
        var draft = RecipeDraft(title: "Braised ribs", components: [meat, sauce], yield: "4 servings", prepMinutes: 20, cookMinutes: 180)
        let row = draft.components![0].ingredients.removeFirst(); draft.components![1].ingredients.append(row)
        draft.components!.swapAt(0, 1)
        draft = draft.preparedForSave()
        let restored = try JSONDecoder().decode(RecipeContent.self, from: JSONEncoder().encode(draft))
        #expect(restored == draft && restored.totalMinutes == 200)
        #expect(restored.orderedComponents[0].id == sauce.id && restored.orderedComponents[0].order == 0)
        #expect(restored.orderedComponents[0].ingredients[1].id == row.id)
        #expect(restored.orderedComponents[0].ingredients[1].quantity == "1 1/2")
        #expect(restored.ingredients.contains("1 1/2 lb short rib, trimmed"))
    }
    @Test func optionalIngredientFieldsDecodeWithoutInventingValues() throws {
        let bytes = Data("{\"id\":\"\(UUID())\",\"name\":\"salt\"}".utf8)
        let ingredient = try JSONDecoder().decode(RecipeIngredient.self, from: bytes)
        #expect(ingredient.quantity.isEmpty && ingredient.unit.isEmpty && ingredient.note.isEmpty && ingredient.displayText == "salt")
    }
    @Test func emptyRowsAreNotSilentlyDroppedAndCancelKeepsSavedValue() {
        let original = RecipeContent(title: "Soup", ingredients: ["Stock"], steps: ["Simmer"])
        var draft = original
        draft.components = original.orderedComponents; draft.components![0].ingredients.append(.init())
        #expect(!draft.isValidDraft)
        #expect(original.components == nil && original.ingredients == ["Stock"])
    }
    @Test func recipeOperationsLeaveTheEntireCookingGraphUnchanged() async throws {
        let container = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        _ = try CookingStore.prepare(context: context)
        var draft = CookingDraft(); draft.dishName = "Soup"; draft.notes = "PRIVATE COOKING NOTES"
        let cook = try CookingStore.create(draft: draft, session: RankingEngine(itemID: UUID(), orderedIDs: [], reaction: .liked), context: context)
        let graph = try CookingGraphExport.snapshot(context: context)
        let review = SocialReview(); let id = UUID()
        var payload = SocialPayload(); payload.recipeID = id; payload.dishID = cook.dish!.id
        payload.recipe = .init(title: "My Soup", ingredients: ["stock"], steps: ["Simmer"]); payload.visibility = "private"
        _ = try await review.request("recipes", "save", payload)
        _ = try await review.request("recipes", "detach", payload)
        _ = try await review.request("recipes", "delete", payload)
        #expect(try CookingGraphExport.snapshot(context: context) == graph)
        let encoded = String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)
        #expect(!encoded.contains("PRIVATE COOKING NOTES"))
    }
}
