import Foundation
import Testing
@testable import StayGrubby

@MainActor struct IngredientEntryTests {
    @Test func rapidEntryRetainsOriginalsAndDropsOnlyFinalPlaceholder() {
        let section=RecipeComponent();var content=RecipeContent(title:"Soup",components:[section]);var entry=IngredientEntryDraft()
        var row=RecipeIngredient();content.components![0].ingredients=[row];entry.begin(row)
        for text in ["1/4 cup of parsley","garlic, minced, 2 cloves","parsley 300g","salt to taste","a good handful of parsley","28 oz crushed tomatoes","1.5 lb chicken","3-4 tbsp oil","2 carrots peeled and sliced","1 can (28 oz) tomatoes"] {
            entry.set(text,for:row);let id=entry.submit(row.id,in:&content,advance:true)!
            row=content.components![0].ingredients.first { $0.id==id }!
        }
        #expect(content.components![0].ingredients.count==11)
        let saved=entry.prepared(content);#expect(saved.components![0].ingredients.count==10 && saved.isValidDraft)
        #expect(saved.components![0].ingredients[0].quantity=="1/4")
        #expect(entry.text(for:saved.components![0].ingredients[0])=="1/4 cup of parsley")
    }
    @Test func emptyReturnAndRepeatedPlusDoNotAccumulateEmptyLines() {
        let row=RecipeIngredient();var c=RecipeContent(title:"Soup",components:[.init(ingredients:[row])]);var e=IngredientEntryDraft();e.begin(row)
        for _ in 0..<10 { e.set("\n",for:row);#expect(e.submit(row.id,in:&c,advance:true)==row.id) }
        #expect(c.components![0].ingredients.count==1 && e.text(for:row).isEmpty)
        #expect(e.prepared(c).components![0].ingredients.isEmpty && e.isValid(c))
    }
    @Test func pendingTextIsResolvedOnSaveWithoutReturn() {
        let row=RecipeIngredient();let c=RecipeContent(title:"Soup",components:[.init(ingredients:[row])]);var e=IngredientEntryDraft();e.begin(row);e.set("parsley 300g",for:row)
        let saved=e.prepared(c);#expect(saved.components![0].ingredients[0].id==row.id);#expect(saved.ingredients==["300 g parsley"])
        #expect(e.text(for:row)=="parsley 300g" && e.hasChanges && e.isValid(c))
    }
    @Test func unchangedLegacyAndStructuredRowsAreNeverReparsed() {
        let rows=[RecipeIngredient(name:"1 1/2 cups stock"),RecipeIngredient(quantity:"about 1",unit:"large spoon",name:"stock",preparation:"use your judgment",note:"old (important) note")]
        var c=RecipeContent(title:"Soup",components:[.init(ingredients:rows)]);var e=IngredientEntryDraft()
        for r in rows { e.begin(r);_ = e.submit(r.id,in:&c,advance:false) }
        #expect(c.components![0].ingredients==rows)
        #expect(e.prepared(c).components![0].ingredients.map(\.displayText)==rows.map(\.displayText))
    }
    @Test func clearingMeaningfulExistingRowRequiresExplicitDelete() {
        let row=RecipeIngredient(name:"parsley");var c=RecipeContent(title:"Soup",components:[.init(ingredients:[row])]);var e=IngredientEntryDraft();e.begin(row);e.set("",for:row)
        #expect(!e.isValid(c));#expect(!e.prepared(c).isValidDraft);#expect(e.prepared(c).components![0].ingredients.count==1)
        c.components![0].ingredients=[];e.forget(row.id);#expect(e.isValid(c))
    }
    @Test func multilinePasteInsertsWithinCorrectSectionAndKeepsFirstIdentity() {
        let row=RecipeIngredient(name:"old"),tail=RecipeIngredient(name:"salt");var c=RecipeContent(title:"Dinner",components:[.init(title:"Sauce",ingredients:[row,tail]),.init(title:"Chicken",ingredients:[.init(name:"chicken")])]);var e=IngredientEntryDraft();e.begin(row)
        e.set("2 tbsp olive oil\n3 cloves garlic minced\r\n28 oz crushed tomatoes\n1 tsp Calabrian chili\n",for:row);let next=e.submit(row.id,in:&c,advance:true)
        #expect(c.components![0].ingredients.map(\.name)==["olive oil","garlic","crushed tomatoes","Calabrian chili","","salt"])
        #expect(c.components![0].ingredients.first?.id==row.id && next==c.components![0].ingredients[4].id)
        #expect(e.prepared(c).components![0].ingredients.count==5 && c.components![1].ingredients.count==1)
    }
    @Test func valueDraftSurvivesInterruptionAndMovesByStableIdentity() {
        let row=RecipeIngredient(name:"oil");let a=RecipeComponent(title:"Sauce",ingredients:[row]),b=RecipeComponent(title:"Chicken");var c=RecipeContent(title:"Dinner",components:[a,b]);var e=IngredientEntryDraft();e.begin(row);e.set("2 tbsp oli...",for:row)
        let retained=e;c.moveRecipeRow(row.id,from:a.id,to:b.id,ingredient:true)
        #expect(e==retained && e.text(for:row)=="2 tbsp oli...")
        #expect(e.prepared(c).components![1].ingredients.first?.name=="oli...")
        #expect(e.prepared(c).components![1].ingredients.first?.quantity=="2")
    }
    @Test func correctionsResetRawDraftWithoutChangingIdentity() {
        let row=RecipeIngredient(quantity:"2",unit:"tbsp",name:"oil");var e=IngredientEntryDraft();e.begin(row);e.set("3 tbsp oil",for:row)
        var corrected=row;corrected.quantity="4";e.forget(row.id);e.begin(corrected)
        #expect(e.text(for:corrected)=="4 tbsp oil" && e.resolved(corrected)==corrected)
    }
    @Test func saveDecodeReadEditSaveAndSearchKeepSemanticIngredientData() throws {
        let row=IngredientParser.parse("parsley 300g").ingredient();var c=RecipeDraft(title:"Green sauce",components:[.init(ingredients:[row],steps:[.init(instruction:"Mix.")])]);c=c.preparedForSave()
        let disk=try JSONEncoder().encode(c);var reopened=try JSONDecoder().decode(RecipeDraft.self,from:disk)
        var e=IngredientEntryDraft();e.begin(reopened.components![0].ingredients[0]);e.set("parsley 350g",for:row);reopened=e.prepared(reopened)
        let again=try JSONDecoder().decode(RecipeContent.self,from:JSONEncoder().encode(reopened))
        #expect(again.components![0].ingredients[0].quantity=="350" && again.components![0].ingredients[0].id==row.id)
        let card=CookbookEntry(dishID:UUID(),recipeID:UUID(),dishTitle:"Green sauce",recipeTitle:"Green sauce",revision:2,searchText:again.ingredients.joined(separator:" "))
        #expect(CookbookSearch.entries([card],query:"parsley",course:"",cuisine:"",alphabetical:false).count==1)
    }
    @Test func voiceOverUsesCookingUnitsAndMeaningfulIngredientText() {
        let row=IngredientParser.parse("2 tbsp olive oil").ingredient()
        #expect(IngredientLineFormatter.accessibilityLine(row)=="2 tablespoons olive oil")
        #expect(IngredientLineFormatter.amount(IngredientParser.parse("½ bunch parsley").ingredient())=="½ bunch")
        #expect(IngredientLineFormatter.accessibilityLine(IngredientParser.parse("¼ cup parsley finely chopped").ingredient())=="¼ cup parsley, finely chopped")
    }

    @Test func staleReturnCannotDuplicateAlreadySubmittedLine() {
        let row=RecipeIngredient();var c=RecipeContent(title:"Soup",components:[.init(ingredients:[row])]);var e=IngredientEntryDraft();e.begin(row);e.set("2 tbsp oil",for:row)
        let next=e.submit(row.id,in:&c,advance:true)
        for _ in 0..<20 { e.set("2 tbsp oil\nmore",for:row);#expect(e.submit(row.id,in:&c,advance:true)==nil) }
        #expect(c.components![0].ingredients.count==2 && e.editingID==next && e.prepared(c).ingredients==["2 tbsp oil"])
    }

}
