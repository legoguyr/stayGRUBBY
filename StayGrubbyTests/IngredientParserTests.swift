import Foundation
import Testing
@testable import StayGrubby

nonisolated enum IngredientParserCorpus {
    struct Case: Sendable {
        let input: String
        let quantity: String
        let unit: String
        let name: String
        var prep = ""
        var note = ""
        init(_ input: String, _ quantity: String, _ unit: String, _ name: String, prep: String = "", note: String = "") {
            self.input=input;self.quantity=quantity;self.unit=unit;self.name=name;self.prep=prep;self.note=note
        }
        init(_ input: String, _ name: String, prep: String = "", note: String = "") { self.init(input,"","",name,prep:prep,note:note) }
    }
    static let cases: [Case] = [
        .init("1/4 cup parsley","1/4","cup","parsley"), .init("¼ cup parsley","1/4","cup","parsley"),
        .init("1/4 cup of parsley","1/4","cup","parsley"), .init("parsley 1/4 cup","1/4","cup","parsley"),
        .init("parsley ¼ cup","1/4","cup","parsley"), .init("parsley, 1/4 cup","1/4","cup","parsley"),
        .init("parsley - 1/4 cup","1/4","cup","parsley"), .init("parsley 300g","300","g","parsley"),
        .init("300g parsley","300","g","parsley"), .init("300 g parsley","300","g","parsley"),
        .init("2 cloves garlic","2","clove","garlic"), .init("2 cloves garlic minced","2","clove","garlic",prep:"minced"),
        .init("garlic 2 cloves","2","clove","garlic"), .init("garlic, minced, 2 cloves","2","clove","garlic",prep:"minced"),
        .init("2 tbsp olive oil","2","tbsp","olive oil"), .init("olive oil 2 tbsp","2","tbsp","olive oil"),
        .init("olive oil 2 tablespoons","2","tbsp","olive oil"), .init("2 tbs olive oil","2","tbsp","olive oil"),
        .init("1 ½ lb chicken thighs","1 1/2","lb","chicken thighs"), .init("1 1/2 lb chicken thighs","1 1/2","lb","chicken thighs"), .init("1½ lb chicken thighs","1 1/2","lb","chicken thighs"),
        .init("1 1/2 lbs boneless skinless chicken thighs","1 1/2","lb","boneless skinless chicken thighs"),
        .init("chicken thighs 1.5 lbs","1 1/2","lb","chicken thighs"), .init("28 oz crushed tomatoes","28","oz","crushed tomatoes"),
        .init("crushed tomatoes 28oz","28","oz","crushed tomatoes"), .init("1 tsp Calabrian chili","1","tsp","Calabrian chili"),
        .init("salt to taste","salt",note:"to taste"), .init("black pepper as needed","black pepper",note:"as needed"),
        .init("a pinch of salt","a pinch of salt"), .init("a handful of parsley","a handful of parsley"),
        .init("zest of 1 lemon","zest of 1 lemon"), .init("juice of 2 lemons","juice of 2 lemons"),
        .init("1 large onion diced","1","","large onion",prep:"diced"), .init("3-4 tbsp olive oil","3-4","tbsp","olive oil"),
        .init("2 to 3 cloves garlic","2-3","clove","garlic"), .init("½ bunch parsley finely chopped","1/2","bunch","parsley",prep:"finely chopped"),
        .init("1 can (28 oz) crushed tomatoes","1","can","crushed tomatoes",note:"28 oz"),
        .init("2 tbsp parsley plus more for garnish","2","tbsp","parsley",note:"plus more for garnish"),
        .init("2 tbsp parsley (plus more for garnish)","2","tbsp","parsley",note:"plus more for garnish"),
        .init("1 lemon (zest and juice)","1","","lemon",note:"zest and juice"),
        .init("parsley optional","parsley",note:"optional"), .init("red pepper flakes, optional","red pepper flakes",note:"optional"),
        .init("salt, to taste","salt",note:"to taste"), .init("2% milk","2% milk"), .init("Chinese five spice","Chinese five spice"),
        .init("5 spice powder","5 spice powder"), .init("00 flour","00 flour"), .init("7 spice","7 spice"),
        .init("7 spice seasoning","7 spice seasoning"), .init("10-inch tortilla","10-inch tortilla"),
        .init("500ml stock","500","mL","stock"), .init("500 mL stock","500","mL","stock"),
        .init("1lb chicken","1","lb","chicken"), .init("12oz tomatoes","12","oz","tomatoes"),
        .init("2 carrots peeled and sliced","2","","carrots",prep:"peeled and sliced"),
        .init("28 oz tomatoes crushed","28","oz","tomatoes",prep:"crushed"),
        .init("1 tsp 7 spice seasoning","1","tsp","7 spice seasoning"),
        .init("cream of mushroom soup","cream of mushroom soup"), .init("a good handful of parsley","a good handful of parsley"),
        .init("2¼ cups flour","2 1/4","cup","flour"), .init("¼–½ cup milk","1/4-1/2","cup","milk"),
        .init("1/4-1/2 cup milk","1/4-1/2","cup","milk"), .init("1.25 kg potatoes","1 1/4","kg","potatoes"),
        .init("2 packages noodles","2","package","noodles"), .init("2 pkg noodles","2","package","noodles"),
        .init("1 dash bitters","1","dash","bitters"), .init("2 sprigs rosemary","2","sprig","rosemary"),
        .init("cod fillets 2","2","","cod fillets"), .init("1 tbsp. oil","1","tbsp","oil"),
        .init("1/0 cup flour","1/0 cup flour"), .init("3-2 cups stock","3-2 cups stock"),
        .init("1 can (tomatoes (crushed))","1 can (tomatoes (crushed))"), .init("2 tbsp parsley (extra","2 tbsp parsley (extra")
    ]
}

@MainActor struct IngredientParserTests {
    @Test(arguments: IngredientParserCorpus.cases)
    func corpus(_ example: IngredientParserCorpus.Case) {
        let p=IngredientParser.parse(example.input)
        #expect(p.rawInput==example.input)
        #expect((p.quantity?.canonical ?? "") == example.quantity)
        #expect(p.unit==example.unit);#expect(p.name==example.name)
        #expect(p.preparation==example.prep);#expect(p.note==example.note)
    }
    @Test(arguments: [
        ["1/4 cup parsley","¼ cup parsley","1/4 cup of parsley","parsley 1/4 cup"],
        ["300g parsley","300 g parsley","parsley 300g"],
        ["2 tbsp olive oil","2 tablespoons olive oil","olive oil 2 tbsp"],
        ["1.5 lb chicken","1½ pounds chicken","1 1/2 lbs chicken"]
    ])
    func equivalentInputs(_ lines: [String]) {
        let id=UUID(),expected=IngredientParser.parse(lines[0]).ingredient(id:id)
        for line in lines { #expect(IngredientParser.parse(line).ingredient(id:id)==expected) }
    }
    @Test func exactFractionsAndRangesNeverDependOnFloatingPoint() {
        for (input,canonical,display) in [("0.1","1/10","1/10"),("0.5","1/2","½"),("2.25","2 1/4","2¼"),("1½","1 1/2","1½"),("1/4-1/2","1/4-1/2","¼–½"),("2–3","2-3","2–3")] {
            let q=IngredientQuantity.parse(input);#expect(q?.canonical==canonical);#expect(q?.display==display)
        }
        for glyph in ["½","¼","¾","⅓","⅔","⅛","⅜","⅝","⅞"] { #expect(IngredientQuantity.parse(glyph)?.display==glyph) }
        for bad in ["1/0","-1","99999999999999999999","1/999999999999999999","1e6","2-1"] { #expect(IngredientQuantity.parse(bad)==nil) }
    }
    @Test func formatterRoundTripsCommonStructuredMeaning() throws {
        for line in IngredientParserCorpus.cases.filter({ !$0.quantity.isEmpty }) {
            let a=IngredientParser.parse(line.input).ingredient(), b=IngredientParser.parse(IngredientLineFormatter.editableLine(a)).ingredient(id:a.id)
            #expect(a==b)
            let restored=try JSONDecoder().decode(RecipeIngredient.self,from:JSONEncoder().encode(a));#expect(restored==a)
            let keys=try #require(JSONSerialization.jsonObject(with:JSONEncoder().encode(a)) as? [String:Any]);#expect(keys["rawInput"]==nil)
        }
    }
    @Test func allUnitAliasesNormalizeWithoutExtractingUnitsFromNames() {
        for (alias,canonical) in IngredientUnit.aliases { let p=IngredientParser.parse("2 \(alias) parsley");#expect(p.unit==canonical && p.name=="parsley") }
        for line in ["cup noodles","ground cloves","package seasoning","bunch of ideas"] { #expect(IngredientParser.parse(line).name==line) }
    }
    @Test func deterministicLocalParsingBenchmark() {
        let clock=ContinuousClock(),start=clock.now
        for _ in 0..<100 { for c in IngredientParserCorpus.cases { #expect(IngredientParser.parse(c.input)==IngredientParser.parse(c.input)) } }
        print("Ingredient parser: \(IngredientParserCorpus.cases.count*200) parses in \(start.duration(to:clock.now))")
    }
}
