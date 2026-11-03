import Foundation
import Testing
@testable import StayGrubby

@MainActor struct RecipeNaturalInputTests {
    private final class ResourceAnchor: NSObject {}
    private struct Case: Decodable { var id: String; var raw: String; var provider: RecipeExtraction; var extraction: RecipeExtraction? }
    private struct Cases: Decodable { var cases: [Case] }
    private func data(_ name: String) throws -> Data {
        let b=Bundle(for:ResourceAnchor.self)
        return try Data(contentsOf:#require(b.url(forResource:name,withExtension:"json",subdirectory:"Fixtures") ?? b.url(forResource:name,withExtension:"json")))
    }
    @Test func retainedRealFrenchToastShakshukaAndKaleReachEditorWithoutContentReconstruction() throws {
        for c in try JSONDecoder().decode(Cases.self,from:data("RecipeV25FinalVerification")).cases {
            let result=try RecipeImportValidation.review(c.provider,raw:c.raw,dishTitle:"",provider:"Retained real Gemini; offline")
            #expect(result.draft.isValidDraft)
            #expect(result.draft.orderedComponents.map(\.title)==c.provider.components.map(\.title))
            #expect(result.draft.steps==c.provider.components.flatMap(\.steps))
            #expect(result.draft.orderedComponents.map{ $0.ingredients.count }==c.provider.components.map{ $0.ingredients.count })
            #expect(try JSONDecoder().decode(RecipeContent.self,from:JSONEncoder().encode(result.draft))==result.draft)
            // We intentionally preserve the model's reviewable wording, not a
            // mechanical reconstruction of source facts or method ingredients.
            if c.id=="french" { #expect(result.draft.steps.contains{$0.contains("at first")}) }
            if c.id=="kale" { #expect(result.draft.steps.contains{$0.contains("separate pot")}) }
        }
    }
    @Test func optionalDescriptionAndEstimatedMetadataNeedNoSourceQuotation() throws {
        let json=#"{"title":"Golden kale pasta","description":"A velvety sauce with crisp toppings.","components":[{"title":"Sauce","ingredients":["pasta","a quarter cup olive oil","two cloves garlic","chiles or pepper flakes, optional"],"steps":["Blend the kale mixture until smooth, then toss with pasta."]}],"metadata":{"yield":{"value":"4 servings","origin":"estimated"},"cookMinutes":{"value":15,"origin":"estimated"},"cuisine":{"value":"Italian","origin":"estimated"}}}"#
        let result=try RecipeImportValidation.review(RecipeImportValidation.decode(Data(json.utf8)),raw:"blend all that",dishTitle:"",provider:"Synthetic").draft
        #expect(result.description=="A velvety sauce with crisp toppings.")
        #expect(result.yield=="4 servings" && result.cookMinutes==15 && result.prepMinutes==nil)
        #expect(result.components![0].ingredients[0].quantity.isEmpty)
        #expect(result.components![0].ingredients[1].quantity=="1/4")
        #expect(result.components![0].ingredients[2].quantity=="2")
        #expect(result.components![0].ingredients[3].displayText.contains("or pepper flakes"))
    }
    @Test func absentOrMalformedOptionalMetadataDoesNotRejectCoreRecipe() throws {
        for metadata in ["",#", "metadata":null"#,#", "metadata":{"yield":42,"prepMinutes":{"value":-20},"cuisine":{"value":"unsupported"}}"#] {
            let json=#"{"components":[{"ingredients":["rice"],"steps":["Cook the rice until tender."]}]"#+metadata+"}"
            let draft=try RecipeImportValidation.review(RecipeImportValidation.decode(Data(json.utf8)),raw:"rice",dishTitle:"",provider:"Synthetic").draft
            #expect(draft.isValidDraft && draft.title=="Recipe Draft" && draft.prepMinutes==nil)
        }
    }
    @Test func methodTextCannotBecomeAnIngredientAndDuplicateAllocationsSurvive() throws {
        let value=RecipeExtraction(title:"Toast",components:[.init(title:"First allocation",ingredients:["butter","1 tbsp butter","1 tbsp butter"],steps:["Cook for 15 seconds per side. Heat to 135."])])
        let draft=try RecipeImportValidation.review(value,raw:"toast",dishTitle:"",provider:"Synthetic").draft
        #expect(draft.components![0].ingredients.count==3)
        #expect(!draft.ingredients.contains{$0.contains("seconds")||$0.contains("135")})
        #expect(draft.steps==value.components[0].steps)
    }
    @Test func structuralCorruptionBoundsAndImpossibleDependenciesStillFail() {
        for value in [
            RecipeExtraction(title:"Bad",components:[]),
            .init(title:"Bad",components:[.init(ingredients:[],steps:[])]),
            .init(title:"Bad",components:[.init(ingredients:["-1 cup salt"],steps:[])]),
            .init(title:"Bad",components:[.init(ingredients:["1/0 cup flour"],steps:[])]),
            .init(title:"Bad",components:[.init(ingredients:["rice"],steps:[],after:[1])]),
            .init(title:"Bad",components:[.init(ingredients:["rice"],steps:[],after:[1]),.init(ingredients:["oil"],steps:[],after:[0])]),
            .init(title:"Bad",components:[.init(ingredients:["rice"],steps:[String(repeating:"x",count:2001)])])
        ] { #expect(throws:RecipeImportFailure.invalid){try RecipeImportValidation.review(value,raw:"anything",dishTitle:"",provider:"Synthetic")} }
    }
    @Test func explicitDependenciesOrderComponentsWithoutRewritingThem() throws {
        let value=RecipeExtraction(title:"Dinner",components:[.init(title:"Assembly",ingredients:["Prepared sauce"],steps:["Fold pasta into the prepared sauce."],after:[1]),.init(title:"Sauce",ingredients:["tomatoes"],steps:["Blend until velvety."])])
        let draft=try RecipeImportValidation.review(value,raw:"tomatoes pasta",dishTitle:"",provider:"Synthetic").draft
        #expect(draft.components!.map(\.title)==["Sauce","Assembly"])
        #expect(draft.steps==["Blend until velvety.","Fold pasta into the prepared sauce."])
    }
    @Test func freshV27ResponsesMapToEditableSerializableDraftsWithDescriptions() throws {
        for c in try JSONDecoder().decode(Cases.self,from:data("RecipeGeminiFirstLive")).cases {
            let output=try #require(c.extraction)
            let decoded=try RecipeImportValidation.decode(JSONEncoder().encode(output))
            var draft=try RecipeImportValidation.review(decoded,raw:c.raw,dishTitle:"",provider:"Fresh real Gemini v27; native mapping check").draft
            #expect(draft.isValidDraft && draft.description==c.provider.description)
            #expect(draft.steps==output.components.flatMap(\.steps))
            #expect(draft.components!.map{$0.ingredients.count}==output.components.map{$0.ingredients.count})
            if c.id=="kale" {
                let rows=draft.components!.flatMap(\.ingredients)
                #expect(rows.contains{$0.quantity=="2" && $0.name.contains("per person")})
                #expect(rows.filter{$0.quantity=="1/4"}.count==2)
                #expect(rows.contains{$0.quantity=="1" && $0.unit=="tbsp" && $0.name.contains("butter")})
            }
            draft.description="An owner-reviewed description."
            #expect(try JSONDecoder().decode(RecipeContent.self,from:JSONEncoder().encode(draft))==draft)
        }
    }
}
