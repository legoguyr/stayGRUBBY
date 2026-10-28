import Foundation
import Testing
@testable import StayGrubby

@MainActor struct CookbookUXTests {
    private func entry(_ title: String, text: String, cuisine: String = "Italian", updated: Double = 1) -> CookbookEntry {
        .init(dishID: UUID(), recipeID: UUID(), dishTitle: title, recipeTitle: title, course: "main", cuisine: cuisine, revision: 2, searchText: text, updatedAt: updated, prepMinutes: 10, cookMinutes: 20)
    }
    @Test func localSearchCoversTitlesIngredientsCuisineSourceAndClearing() {
        let cod = entry("Cod & Pesto", text: "Red peppers garlic The Home Cookbook")
        let values = [cod,entry("Crème tart", text: "flour", cuisine: "French",updated: 2)]
        for term in ["COD","pest","pepp","garlic","ital","home cook"] { #expect(CookbookSearch.entries(values,query:term,course:"",cuisine:"",alphabetical:false).map(\.id)==[cod.id]) }
        #expect(CookbookSearch.entries(values,query:"creme",course:"",cuisine:"",alphabetical:false).count==1)
        #expect(CookbookSearch.entries(values,query:"",course:"",cuisine:"",alphabetical:false).count==2)
        #expect(CookbookSearch.entries(values,query:"",course:"soup",cuisine:"",alphabetical:false).isEmpty)
        #expect(CookbookSearch.entries(values,query:"",course:"main",cuisine:"French",alphabetical:true).count==1)
        #expect(cod.duration==30)
    }
    @Test func hundredsOfEntriesFilterLocallyWithoutPerKeystrokeRequests() async throws {
        let values = (0..<520).map { entry("Dish \($0)",text:$0==319 ? "saffron cookbook" : "stock") }.sorted { $0.id.uuidString < $1.id.uuidString }
        var calls=0
        let request: SocialRequest = { endpoint, action, payload in
            #expect(endpoint=="recipes" && action=="library_index");calls+=1
            let rest=values.filter { payload.beforeID == nil || $0.id.uuidString > payload.beforeID!.uuidString }
            return try JSONEncoder().encode(CookbookPage(entries:Array(rest.prefix(50))))
        }
        let index=try await CookbookIndex.load(request:request)
        #expect(index.count==520 && calls==11)
        for q in ["s","sa","saf","saff","saffron",""] { _=CookbookSearch.entries(index,query:q,course:"",cuisine:"",alphabetical:false) }
        #expect(calls==11)
        #expect(CookbookSearch.entries(index,query:"saffron",course:"",cuisine:"",alphabetical:false).count==1)
    }
    @Test func sectionMovesRetainIdentityQuantityFormattingAndGlobalOrder() throws {
        let ingredient=RecipeIngredient(quantity:"1 1/2",unit:"cups",name:"tomato",preparation:"diced",note:"drained")
        let step=RecipeStep(instruction:"Simmer.\nStir gently.")
        let sauce=RecipeComponent(title:"Sauce",ingredients:[ingredient],steps:[step]), chicken=RecipeComponent(title:"Chicken")
        var draft=RecipeDraft(title:"Dinner",components:[sauce,chicken])
        draft.moveRecipeRow(ingredient.id,from:sauce.id,to:chicken.id,ingredient:true)
        draft.moveRecipeRow(step.id,from:sauce.id,to:chicken.id,ingredient:false)
        #expect(draft.components![0].ingredients.isEmpty && draft.components![1].ingredients==[ingredient])
        #expect(draft.components![1].steps==[step])
        draft.components!.swapAt(0,1)
        let saved=draft.preparedForSave();let decoded=try JSONDecoder().decode(RecipeDraft.self,from:JSONEncoder().encode(saved))
        #expect(decoded==saved && decoded.components![0].id==chicken.id && decoded.components![0].order==0)
        #expect(decoded.ingredients==[ingredient.displayText] && decoded.steps==[step.instruction])
        draft.moveRecipeRow(ingredient.id,from:chicken.id,to:UUID(),ingredient:true)
        #expect(draft.components![0].ingredients==[ingredient])
    }
}
