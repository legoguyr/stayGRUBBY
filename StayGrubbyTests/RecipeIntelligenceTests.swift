import Foundation
import Testing
@testable import StayGrubby

@MainActor struct RecipeIntelligenceTests {
    private let simple = "Vodka Pasta\n2 tbsp olive oil\npasta\nCook until it looks right."
    private var extraction: RecipeExtraction { .init(title:"Vodka Pasta",yield:nil,source:nil,components:[.init(title:nil,ingredients:["2 tbsp olive oil","pasta"],steps:["Cook until it looks right."])]) }
    @Test func bulkListCleanupIsConservativeAndLocal() {
        let lines=BulkIngredients.lines("• 2 tbsp olive oil\n\n- 3 cloves garlic\n1. 28 oz crushed tomatoes\n2) salt\n1/2 cup cream\n1.5 lb pasta\n7 spice\n-1 pinch salt\n00 flour")
        #expect(lines.map(\.text)==["2 tbsp olive oil","3 cloves garlic","28 oz crushed tomatoes","salt","1/2 cup cream","1.5 lb pasta","7 spice","-1 pinch salt","00 flour"])
        #expect(lines.first?.original=="• 2 tbsp olive oil")
    }
    @Test func bulkStaysInSectionRetainsIDsAndOriginals() {
        let old=RecipeIngredient(name:"rice");let a=RecipeComponent(ingredients:[old]),b=RecipeComponent(title:"Sauce")
        var c=RecipeContent(title:"Dinner",components:[a,b]), entry=IngredientEntryDraft()
        entry.appendBulk("• 1/2 cup cream\n2. salt to taste",to:b.id,in:&c)
        #expect(c.components![0].ingredients==[old]);#expect(c.components![1].ingredients.count==2)
        let cream=c.components![1].ingredients[0];#expect(cream.quantity=="1/2" && cream.unit=="cup")
        #expect(entry.bulkOriginals[cream.id]=="• 1/2 cup cream");#expect(entry.text(for:cream)=="1/2 cup cream")
        entry.begin(cream);entry.set("3/4 cup cream",for:cream);#expect(entry.prepared(c).components![1].ingredients[0].quantity=="3/4")
    }
    @Test func sourceValidationPreservesUnknownsAndNoInventedFacts() throws {
        let result=try RecipeImportValidation.review(extraction,raw:simple,dishTitle:"Existing Dish",provider:"Mock")
        #expect(result.draft.components!.count==1 && result.draft.components![0].title==nil)
        #expect(result.draft.yield==nil && result.draft.prepMinutes==nil && result.draft.cookMinutes==nil)
        #expect(result.draft.components![0].ingredients[1].quantity=="")
        #expect(result.draft.steps==["Cook until it looks right."] && result.warnings.count==2)
        var invented=extraction;invented.components[0].steps=["Cook at 375°F for 22 minutes."]
        #expect(throws:RecipeImportFailure.invalid){try RecipeImportValidation.review(invented,raw:simple,dishTitle:"Dish",provider:"Mock")}
        invented=extraction;invented.yield="4";#expect(throws:RecipeImportFailure.invalid){try RecipeImportValidation.review(invented,raw:simple,dishTitle:"Dish",provider:"Mock")}
    }
    @Test func representativeMultiComponentMessyAndAmbiguousFixtures() throws {
        let raw="Cod with Red Pesto and Gnocchi & Brussels\nRed Pesto\n1 cup peppers\nBlend peppers.\nCod\n2 cod fillets\nPat cod dry.\nGnocchi & Brussels\n1 lb gnocchi\nCook gnocchi."
        let e=RecipeExtraction(title:"Cod with Red Pesto and Gnocchi & Brussels",components:[.init(title:"Red Pesto",ingredients:["1 cup peppers"],steps:["Blend peppers."]),.init(title:"Cod",ingredients:["2 cod fillets"],steps:["Pat cod dry."]),.init(title:"Gnocchi & Brussels",ingredients:["1 lb gnocchi"],steps:["Cook gnocchi."])])
        let result=try RecipeImportValidation.review(e,raw:raw,dishTitle:"Dinner",provider:"Mock");#expect(result.draft.components!.map(\.title)==["Red Pesto","Cod","Gnocchi & Brussels"])
        for (title,ingredients,steps) in [
            ("Butternut squash risotto",["300g arborio","stock maybe 1L","parm"],["roast squash salt pepper olive oil till golden about 20 min","add stock 2 ladles then one at a time."]),
            ("Soup",["stock","salt"],["cook chicken until done"]),
            ("Dinner",["onions"],["maybe sauce then rice? stir."]),
            ("Well-formatted soup",["1 L stock","2 carrots"],["Simmer for 20 min."])
        ] {
            let source=([title]+ingredients+steps).joined(separator:"\n")
            let e=RecipeExtraction(title:title,components:[.init(title:nil,ingredients:ingredients,steps:steps)])
            let r=try RecipeImportValidation.review(e,raw:source,dishTitle:"Dish",provider:"Mock")
            #expect(r.draft.steps==steps && r.draft.components!.count==1)
        }
    }
    @Test func schemaLimitsMissingMalformedAndExtraFields() throws {
        for json in ["{}","[]","null","{\"components\":[],\"unexpected\":true}","{\"components\":[{\"ingredients\":[],\"steps\":[],\"extra\":0}]}"] {
            #expect(throws:RecipeImportFailure.invalid){try RecipeImportValidation.decode(Data(json.utf8))}
        }
        let empty=try RecipeImportValidation.decode(Data("{\"components\":[]}".utf8))
        #expect(throws:RecipeImportFailure.invalid){try RecipeImportValidation.review(empty,raw:simple,dishTitle:"Dish",provider:"Mock")}
        #expect(throws:RecipeImportFailure.tooLong){try RecipeImportValidation.input(String(repeating:"a",count:12_001))}
        #expect(throws:RecipeImportFailure.tooLong){try RecipeImportValidation.input(String(repeating:"🧄",count:9_000))}
        let roundtrip=try RecipeImportValidation.decode(JSONEncoder().encode(extraction));#expect(roundtrip==extraction)
    }
    @Test func applePreferredAndAutomaticFallbackContract() async throws {
        let apple=Provider(identity:"Apple",value:extraction),gemini=Provider(identity:"Gemini",value:extraction)
        let result=try await RecipeIntelligenceService.format(simple,dishTitle:"Dish",apple:apple,fallback:gemini)
        #expect(result.provider=="Apple" && apple.calls==1 && gemini.calls==0)
        apple.isAvailable=false
        let fallback=try await RecipeIntelligenceService.format(simple,dishTitle:"Dish",apple:apple,fallback:gemini)
        #expect(fallback.provider=="Gemini" && gemini.calls==1)
        apple.isAvailable=true;apple.error = .timeout
        _=try await RecipeIntelligenceService.format(simple,dishTitle:"Dish",apple:apple,fallback:gemini)
        #expect(gemini.calls==2)
    }
    @Test func allFailureCategoriesRetainInputAndAllowManual() async {
        for error in [RecipeImportFailure.unavailable,.timeout,.quota,.rateLimited,.network,.invalid] {
            let apple=Provider(identity:"Apple",value:extraction);apple.isAvailable=false
            let gemini=Provider(identity:"Gemini",value:extraction);gemini.error=error
            await #expect(throws:error){try await RecipeIntelligenceService.format(simple,dishTitle:"Dish",apple:apple,fallback:gemini)}
            let manual=RecipeImportValidation.manual(simple,dishTitle:"Original Dish")
            #expect(manual.draft.title=="Original Dish" && manual.draft.steps.isEmpty && manual.draft.components![0].steps[0].instruction==simple)
        }
    }
    @Test func cancelledProviderNeverFallsBackOrProducesDraft() async {
        let apple=Provider(identity:"Apple",value:extraction);apple.cancel=true
        let gemini=Provider(identity:"Gemini",value:extraction)
        await #expect(throws:CancellationError.self){try await RecipeIntelligenceService.format(simple,dishTitle:"Dish",apple:apple,fallback:gemini)}
        #expect(gemini.calls==0)
    }
    @Test func legacyStorageWireAndSearchRemainExistingContract() throws {
        let result=try RecipeImportValidation.review(extraction,raw:simple,dishTitle:"Dish",provider:"Gemini")
        let content=try JSONDecoder().decode(RecipeContent.self,from:JSONEncoder().encode(result.draft))
        #expect(content==result.draft && content.ingredients.contains("2 tbsp olive oil"))
        #expect(CookbookSearch.matches(content.ingredients.joined(separator:" "),query:"OLIVE"))
        #expect(!String(data:try JSONEncoder().encode(content),encoding:.utf8)!.contains("provider"))
    }
    @MainActor private final class Provider: RecipeIntelligenceProvider {
        var identity:String;var isAvailable=true;var calls=0;var value:RecipeExtraction;var error:RecipeImportFailure?;var cancel=false
        init(identity:String,value:RecipeExtraction){self.identity=identity;self.value=value}
        func extract(_ raw:String) async throws -> RecipeExtraction {calls+=1;if cancel{throw CancellationError()};if let error{throw error};return value}
    }
}
