import Foundation
import Testing
@testable import StayGrubby

@MainActor struct RecipeNaturalInputTests {
    private final class ResourceAnchor: NSObject {}
    private struct Pair: Decodable { var text: String; var kind: String; var valid: Bool }
    private struct Case: Decodable { var raw: String; var extraction: RecipeExtraction }
    private struct Fixture: Decodable {
        var raw: String
        var extraction: RecipeExtraction
        var pairs: [Pair]
        var otherCases: [Case]?
    }
    private func fixture(_ name: String = "RecipeFrenchToastAcceptance") throws -> Fixture {
        let bundle = Bundle(for: ResourceAnchor.self)
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") ?? bundle.url(forResource: name, withExtension: "json")
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: #require(url)))
    }
    @Test func exactOwnerSourceAndSafeUnsafePhraseParity() throws {
        let f = try fixture()
        #expect(f.raw.hasPrefix("French toast recipe. Use day or so old challah"))
        #expect(f.raw.contains("Wisk 4 egg yolks"))
        #expect(f.raw.contains("out.\\\nHeat heavy 1 cup cream"))
        for p in f.pairs {
            #expect(RecipeSourceEvidence.grounded(p.text, raw: f.raw, kind: p.kind == "ingredient" ? .ingredient : .step, polished: true) == p.valid, "\(p.text)")
        }
    }
    @Test func actualHandlerOutputsDecodeAndReachEditableDraftWithoutChangingSource() throws {
        let f = try fixture(), original = f.raw
        for prefix in ["", "Challah French Toast\nServes 4\n"] {
            let decoded = try RecipeImportValidation.decode(JSONEncoder().encode(f.extraction))
            let result = try RecipeImportValidation.review(decoded, raw: prefix + f.raw, dishTitle: "", provider: "Gemini synthetic fixture")
            #expect(result.draft.isValidDraft)
            #expect(result.draft.yield == (prefix.isEmpty ? nil : "4"))
            let ingredients = result.draft.orderedComponents.flatMap(\.ingredients)
            #expect(ingredients.contains { $0.quantity == "1" && $0.unit == "cup" && $0.name == "heavy cream" })
            #expect(ingredients.contains { $0.quantity == "2" && $0.unit == "cup" && $0.name == "whole milk" })
            #expect(ingredients.contains { $0.name == "butter" && $0.quantity.isEmpty })
            #expect(result.draft.steps.contains { $0.contains("15 seconds per side") })
            #expect(!result.draft.steps.joined().contains("°F"))
            #expect(try JSONDecoder().decode(RecipeContent.self, from: JSONEncoder().encode(result.draft)) == result.draft)
        }
        #expect(f.raw == original)
    }
    @Test func otherNaturalRecipesPassTheSameClientGuard() throws {
        for c in try fixture().otherCases ?? [] {
            let result = try RecipeImportValidation.review(c.extraction, raw: c.raw, dishTitle: "", provider: "Synthetic contract")
            #expect(result.draft.isValidDraft)
        }
    }
    @Test func independentShakshukaHandlerOutputRetainsServingsQuantitiesAndProceduralTimes() throws {
        let f = try fixture("RecipeShakshukaAcceptance")
        for p in f.pairs { #expect(RecipeSourceEvidence.grounded(p.text, raw: f.raw, kind: p.kind == "ingredient" ? .ingredient : .step, polished: true) == p.valid, "\(p.text)") }
        let decoded = try RecipeImportValidation.decode(JSONEncoder().encode(f.extraction))
        let result = try RecipeImportValidation.review(decoded, raw: f.raw, dishTitle: "", provider: "Synthetic Shakshuka contract")
        #expect(result.draft.yield == "4" && result.draft.metadataOrigins?["yield"] == "provided")
        let rows = result.draft.orderedComponents.flatMap(\.ingredients)
        #expect(rows.contains { $0.quantity == "8" && $0.name == "eggs" })
        #expect(rows.contains { $0.quantity == "1" && $0.unit == "tsp" && $0.name == "paprika" })
        #expect(rows.contains { $0.name == "olive oil" && $0.quantity.isEmpty })
        let method = result.draft.steps.joined(separator: " ")
        #expect(method.contains("5 to 10 minutes") && method.contains("about 3 minutes") && method.contains("Alternatively, turn on the broiler"))
        #expect(result.draft.isValidDraft)
    }
    @Test func singularMeasuresAndContextualBroilerDoNotLicenseNewFacts() throws {
        let f = try fixture("RecipeShakshukaAcceptance")
        for (raw,text,kind) in [
            ("Crack an egg into a cup.","1 cup egg",RecipeSourceEvidence.Kind.ingredient),
            ("Boil the eggs.","Broil the eggs.",.step),
            ("Turn on the boiler to heat water.","Turn on the broiler.",.step),
            (f.raw,"Cook the eggs under the broiler.",.step)
        ] { #expect(!RecipeSourceEvidence.grounded(text, raw: raw, kind: kind, polished: true)) }
        #expect(RecipeCreatorValidation.explicit("Rice for four. Cook rice.", key: "yield") == 4)
        for raw in ["Cook for 4 minutes.","Simmer sauce for 4.","Soup for 4 minutes."] { #expect(RecipeCreatorValidation.explicit(raw, key: "yield") == nil) }
    }
    @Test func quantitiesCannotCrossClausesOrBorrowAnotherIngredientDescriptor() {
        for (raw,line,valid) in [
            ("Use dry 1/2 cup white wine.","1/2 cup dry white wine",true),
            ("Use chopped 2 cups carrots.","2 cups chopped carrots",true),
            ("Use egg 4 yolks.","4 egg yolks",true),
            ("Use cream and 1 cup milk.","1 cup cream milk",false),
            ("Use cream with 1 cup milk.","1 cup cream milk",false),
            ("Use cream. Add 1 cup milk.","1 cup cream milk",false),
            ("Use heavy 1 cup cream and 2 cups whole milk.","2 cups heavy cream",false),
            ("Use fresh parsley and 2 cups carrots.","2 cups fresh carrots",false)
        ] { #expect(RecipeSourceEvidence.grounded(line, raw: raw, kind: .ingredient, polished: true) == valid) }
    }
    @Test func approximateAgeIsNotAnIngredientChoiceButRealAlternativesRemainRequired() {
        func value(_ steps: [String]) -> RecipeExtraction { .init(editorialVersion: 3, components: [.init(ingredients: ["bread"], steps: steps)]) }
        #expect(RecipeEditorialEvidence.preserve(value(["Use bread that is a day or so old."]), raw: "Use day or so old bread.") != nil)
        #expect(RecipeEditorialEvidence.preserve(value(["Use bread."]), raw: "Use bread or rice.") == nil)
        #expect(RecipeEditorialEvidence.preserve(value(["Use day-old bread."]), raw: "Use bread a day or so old, or rice.") == nil)
    }
}
