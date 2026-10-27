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
        var expectedYield: String?
        var expectedPrep: Int?
        var expectedCook: Int?
        var expectedTotal: Int?
        var expectedCuisine: String?
        var allergenKnown: [String]?
        var allergenPossible: [String]?
        var allergenNot: [String]?
        var unknownMetadata: Bool?
        var ingredientCount: Int?
        var maximumComponents: Int?
        var expectedFirstStep: String?
        var expectedLastStep: String?
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
        #expect(Set(cases.map(\.phase)) == Set(0...10))
        for c in cases {
            let wire = try JSONEncoder().encode(c.extraction)
            let decoded = try RecipeImportValidation.decode(wire)
            let result = try RecipeImportValidation.review(decoded, raw: c.raw, dishTitle: "Existing cooked Dish", provider: "Gemini fixture")
            #expect(result.draft.isValidDraft, "\(c.id): invalid editor draft")
            let saved = try JSONEncoder().encode(result.draft)
            #expect(saved.count <= 40_000)
            #expect(try JSONDecoder().decode(RecipeContent.self, from: saved) == result.draft)
            if c.phase < 9 { #expect(result.draft.prepMinutes == nil && result.draft.cookMinutes == nil) }
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
    @Test func creatorConstructionMetadataAndAllergensSurviveEditorAndSave() throws {
        for c in try cases().filter({ $0.phase >= 9 }) {
            let result = try RecipeImportValidation.review(c.extraction, raw: c.raw, dishTitle: "Existing Dish", provider: "Shared Creator")
            let d = result.draft
            if let v = c.checks.expectedYield { #expect(d.yield == v, "\(c.id): yield") }
            if let v = c.checks.expectedPrep { #expect(d.prepMinutes == v, "\(c.id): prep") }
            if let v = c.checks.expectedCook { #expect(d.cookMinutes == v, "\(c.id): cook") }
            if let v = c.checks.expectedTotal { #expect(d.totalMinutes == v, "\(c.id): total") }
            if let v = c.checks.expectedCuisine { #expect(d.cuisine == v, "\(c.id): cuisine") }
            if let n = c.checks.ingredientCount { #expect(d.components!.flatMap(\.ingredients).count == n) }
            if let n = c.checks.maximumComponents { #expect(d.components!.count <= n) }
            if let first = c.checks.expectedFirstStep { #expect(d.steps.first == first) }
            if let last = c.checks.expectedLastStep { #expect(d.steps.last == last) }
            for code in c.checks.allergenKnown ?? [] { #expect(d.allergens!.contains.contains(code), "\(c.id): missing known \(code)") }
            for code in c.checks.allergenPossible ?? [] { #expect(d.allergens!.possible.contains(code), "\(c.id): missing possible \(code)") }
            for code in c.checks.allergenNot ?? [] { #expect(!d.allergens!.contains.contains(code) && !d.allergens!.possible.contains(code), "\(c.id): unsupported \(code)") }
            #expect(try JSONDecoder().decode(RecipeContent.self, from: JSONEncoder().encode(d)) == d)
            #expect(d.metadataOrigins?["yield"] == c.extraction.metadata!.yield.origin.rawValue)
        }
    }
    @Test func cookbookEstimatesWithoutLiteralQuotationReachEditorWhileProvidedClaimsStayStrict() throws {
        let raw = "Boil pasta and blend spinach with olive oil."
        let m = RecipeCreatorMetadata(yield: .init(value: "2", origin: .estimated), prepMinutes: .init(value: 10, origin: .estimated), cookMinutes: .init(value: 15, origin: .estimated), totalMinutes: .init(value: 20, origin: .estimated))
        #expect(RecipeCreatorValidation.normalize(m, raw: raw).yield.value == nil) // reproduces v2 loss
        let fixed = RecipeCreatorValidation.normalize(m, raw: raw, polished: true)
        #expect(fixed.yield.value == "2" && fixed.prepMinutes.value == 10 && fixed.cookMinutes.value == 15 && fixed.totalMinutes.value == 20)
        #expect(fixed.yield.origin == .estimated && fixed.totalMinutes.origin == .estimated)
        let unsupported = RecipeCreatorValidation.normalize(.init(yield: .init(value: "8", origin: .provided, evidence: raw)), raw: raw, polished: true)
        #expect(unsupported.yield.origin == .unknown)
    }
    @Test func cookbookPolicyRetainsEveryExistingUnsafeFactRejection() throws {
        struct Pair: Decodable { var id: String; var raw: String; var unsafe: String; var kind: String }
        struct Pairs: Decodable { var cases: [Pair] }
        for c in try JSONDecoder().decode(Pairs.self, from: data("RecipeEditorialPairs")).cases {
            #expect(!RecipeSourceEvidence.grounded(c.unsafe, raw: c.raw, kind: c.kind == "ingredient" ? .ingredient : .step, polished: true), "\(c.id): unsafe fact accepted")
        }
    }
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
    @Test func creatorProvenanceDistinguishesExplicitAndEstimatedAndHonorsHours() {
        let raw = "Serves 4. Prep time 10 minutes. Cook time 1 hour. Boil rice."
        let m = RecipeCreatorValidation.normalize(.init(yield: .init(value: "8", origin: .estimated, evidence: raw), prepMinutes: .init(), cookMinutes: .init(value: 20, origin: .estimated, evidence: raw)), raw: raw)
        #expect(m.yield.value == "4" && m.yield.origin == .provided)
        #expect(m.prepMinutes.value == 10 && m.cookMinutes.value == 60)
        let loaf = RecipeCreatorValidation.normalize(.init(), raw: "Makes 1 loaf.")
        #expect(loaf.yield.value == "1 loaf" && loaf.yield.origin == .provided)
        let fractional = RecipeCreatorValidation.normalize(.init(), raw: "Prep time 1.5 minutes.")
        #expect(fractional.prepMinutes.value == 2 && fractional.prepMinutes.origin == .derived)
        let estimate = RecipeCreatorValidation.normalize(.init(yield: .init(value: "2", origin: .estimated, evidence: "Boil pasta")), raw: "Boil pasta")
        #expect(estimate.yield.origin == .estimated && estimate.yield.value == "2")
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
    @Test func quantityUnitAliasesAreEquivalentWithoutMathOrInference() {
        for (a,b) in [("quarter cup olive oil","0.25 cup olive oil"),("half cup stock","1/2 cup stock"),("two cloves garlic","2 cloves garlic"),("one tablespoon butter","1 tbsp butter"),("180 degrees Fahrenheit","180 °F"),("180 degrees Celsius","180 °C"),("2 ounces flour","2 oz flour"),("1 pound rice","1 lb rice")] {
            #expect(RecipeSourceEvidence.tokens(a) == RecipeSourceEvidence.tokens(b))
        }
        #expect(RecipeSourceEvidence.tokens("180 °F") != RecipeSourceEvidence.tokens("180 °C"))
    }
}
