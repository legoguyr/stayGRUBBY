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
        #expect(Set(cases.map(\.phase)) == Set(0...7))
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
    @Test func quantityUnitAliasesAreEquivalentWithoutMathOrInference() {
        for (a,b) in [("quarter cup olive oil","0.25 cup olive oil"),("half cup stock","1/2 cup stock"),("two cloves garlic","2 cloves garlic"),("one tablespoon butter","1 tbsp butter"),("180 degrees Fahrenheit","180 °F"),("180 degrees Celsius","180 °C"),("2 ounces flour","2 oz flour"),("1 pound rice","1 lb rice")] {
            #expect(RecipeSourceEvidence.tokens(a) == RecipeSourceEvidence.tokens(b))
        }
        #expect(RecipeSourceEvidence.tokens("180 °F") != RecipeSourceEvidence.tokens("180 °C"))
    }
}
