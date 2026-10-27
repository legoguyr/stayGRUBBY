import Foundation
import Testing
@testable import StayGrubby

@MainActor struct RecipeEngineAcceptanceTests {
    private final class ResourceAnchor: NSObject {}
    private struct Suite: Decodable { var cases: [Case] }
    private struct Case: Decodable {
        var id: String
        var phase: Int
        var raw: String
        var extraction: RecipeExtraction
        var checks: Checks
    }
    private struct Checks: Decodable {
        var unknownQuantity: Bool?
        var quantities: [String]?
        var minimumComponents: Int?
        var preserve: String?
        var forbid: String?
    }
    private func data(_ name: String) throws -> Data {
        let bundle = Bundle(for: ResourceAnchor.self)
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") ?? bundle.url(forResource: name, withExtension: "json")
        return try Data(contentsOf: #require(url))
    }
    private func cases() throws -> [Case] { try JSONDecoder().decode(Suite.self, from: data("RecipeEngineServerOutputs")).cases }
    @Test func allServerPhasesDecodeNormalizeAndRemainEditorCompatible() throws {
        let cases = try cases()
        #expect(Set(cases.map(\.phase)) == Set(0...8))
        for c in cases {
            let wire = try JSONEncoder().encode(c.extraction)
            let decoded = try RecipeImportValidation.decode(wire)
            let result = try RecipeImportValidation.review(decoded, raw: c.raw, dishTitle: "Existing cooked Dish", provider: "Gemini fixture")
            #expect(result.draft.isValidDraft, "\(c.id): invalid editor draft")
            let saved = try JSONEncoder().encode(result.draft)
            #expect(saved.count <= 40_000)
            #expect(try JSONDecoder().decode(RecipeContent.self, from: saved) == result.draft)
            #expect(result.draft.prepMinutes == nil && result.draft.cookMinutes == nil)
            if let minimum = c.checks.minimumComponents { #expect(result.draft.components!.count >= minimum) }
            if c.checks.unknownQuantity == true { #expect(result.draft.components!.flatMap(\.ingredients).contains { $0.quantity.isEmpty }) }
            if let amounts = c.checks.quantities {
                let actual = result.draft.components!.flatMap(\.ingredients).compactMap { IngredientQuantity.parse($0.quantity) }
                #expect(actual == amounts.compactMap(IngredientQuantity.parse))
            }
            let text = String(decoding: saved, as: UTF8.self)
            if let word = c.checks.preserve { #expect(text.contains(word)) }
            if let word = c.checks.forbid { #expect(!text.contains(word)) }
            #expect(!result.warnings.isEmpty)
        }
    }
    @Test func exactKaleContractPreservesMissingValuesAndOriginalUncertainty() throws {
        let c = try #require(cases().first { $0.id == "canonical-v10-rule-shape" })
        let r = try RecipeImportValidation.review(c.extraction, raw: c.raw, dishTitle: "Existing Dish", provider: "Fixture")
        let ingredients = r.draft.components!.flatMap(\.ingredients)
        #expect(ingredients.first { $0.name.lowercased() == "pasta" }?.quantity == "")
        #expect(ingredients.contains { $0.name.contains("per person") && $0.quantity == "2" })
        #expect(ingredients.contains { $0.name.contains("clabbering") && $0.quantity.isEmpty })
        #expect(r.draft.yield == nil && r.draft.prepMinutes == nil && r.draft.cookMinutes == nil)
        #expect(r.draft.steps.joined().contains("five minutes"))
        #expect(!r.draft.steps.joined().contains("400"))
    }
    @Test func unsupportedFactsRemainRejectedOnClient() throws {
        struct Negative: Decodable { var raw: String; var provider: RecipeExtraction }
        struct Negatives: Decodable { var cases: [Negative] }
        for c in try JSONDecoder().decode(Negatives.self, from: data("RecipeEngineNegative")).cases {
            #expect(throws: RecipeImportFailure.invalid) { try RecipeImportValidation.review(c.provider, raw: c.raw, dishTitle: "Dish", provider: "Negative") }
        }
    }
    @Test func editorialPairsProtectFactsWithoutRequiringLiteralProse() throws {
        struct Pair: Decodable { var id: String; var raw: String; var safe: String; var unsafe: String; var kind: String }
        struct Pairs: Decodable { var cases: [Pair] }
        for c in try JSONDecoder().decode(Pairs.self, from: data("RecipeEditorialPairs")).cases {
            let kind: RecipeSourceEvidence.Kind = c.kind == "ingredient" ? .ingredient : .step
            #expect(RecipeSourceEvidence.grounded(c.safe, raw: c.raw, kind: kind), "\(c.id): safe rewrite rejected")
            #expect(!RecipeSourceEvidence.grounded(c.unsafe, raw: c.raw, kind: kind), "\(c.id): invented fact accepted")
        }
    }
    @Test func editorialServerProseSurvivesNativeReviewAndPersistence() throws {
        for c in try cases().filter({ $0.phase == 8 }) {
            let result = try RecipeImportValidation.review(c.extraction, raw: c.raw, dishTitle: "Dish", provider: "Provider contract")
            #expect(result.draft.components!.flatMap(\.steps).map(\.instruction) == c.extraction.components.flatMap(\.steps), "\(c.id): polished prose changed on client")
            let saved = try JSONEncoder().encode(result.draft)
            #expect(try JSONDecoder().decode(RecipeContent.self, from: saved) == result.draft)
        }
    }
    @Test func sourceQualificationsAreRestoredWithoutDowngradingSteps() throws {
        let raw = "cook rice about five minutes add a little olive oil and salt to taste"
        let value = RecipeExtraction(components: [.init(ingredients: ["rice", "olive oil", "salt"], steps: ["Cook rice for 5 minutes.", "Add olive oil and salt."])])
        let result = try RecipeImportValidation.review(value, raw: raw, dishTitle: "Rice", provider: "Apple contract")
        #expect(result.draft.steps == ["Cook rice for about 5 minutes.", "Add olive oil and salt."])
        #expect(result.draft.components![0].ingredients.contains { $0.name.contains("a little") })
        #expect(result.draft.components![0].ingredients.contains { $0.name == "salt" && $0.note == "to taste" })
        #expect(value.components[0].steps[0] == "Cook rice for 5 minutes.")
    }
    @Test func factLockRejectsDroppedNumbersPreparationAndAlternatives() {
        #expect(RecipeEditorialEvidence.preserve(RecipeExtraction(components: [.init(ingredients: ["some salt"], steps: [])]), raw: String(repeating: "some salt, ", count: 201)) == nil)
        for (raw, value) in [
            ("2 cloves garlic. Blend garlic.", RecipeExtraction(components: [.init(ingredients: ["garlic"], steps: ["Blend garlic."])])),
            ("Add cold cubed butter.", RecipeExtraction(components: [.init(ingredients: ["butter"], steps: ["Add butter."])])),
            ("Add oil or uncertain chilies or pepper.", RecipeExtraction(components: [.init(ingredients: ["oil", "pepper"], steps: ["Add oil and pepper."])]))
        ] { #expect(RecipeEditorialEvidence.preserve(value, raw: raw) == nil) }
    }
    @Test func quantityUnitAliasesAreEquivalentWithoutMathOrInference() {
        for (a,b) in [("quarter cup olive oil","0.25 cup olive oil"),("half cup stock","1/2 cup stock"),("two cloves garlic","2 cloves garlic"),("one tablespoon butter","1 tbsp butter"),("180 degrees Fahrenheit","180 °F"),("180 degrees Celsius","180 °C"),("2 ounces flour","2 oz flour"),("1 pound rice","1 lb rice")] {
            #expect(RecipeSourceEvidence.tokens(a) == RecipeSourceEvidence.tokens(b))
        }
        #expect(RecipeSourceEvidence.tokens("180 °F") != RecipeSourceEvidence.tokens("180 °C"))
    }
}
