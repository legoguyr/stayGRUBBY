import Foundation
import Testing
@testable import StayGrubby

struct RecipeBrowsingTests {
    private func entry(_ title: String, course: String? = nil, cuisine: String? = nil, source: String? = nil, allergens: RecipeAllergenAssessment? = nil, date: Double = 1) -> CookbookEntry {
        var result = CookbookEntry(recipeID: UUID(), dishTitle: title, recipeTitle: title, course: course, cuisine: cuisine, revision: 1)
        result.source = source; result.createdAt = date; result.updatedAt = date; result.allergens = allergens; return result
    }
    @Test func groupsComposeWithSearchAndResetWithoutClaimingUnknownIsSafe() {
        let a = entry("Lemon soup",course:"soup",cuisine:"Italian",source:"My notes",allergens:.init(contains:["milk"],possible:["wheat"]))
        let b = entry("Lemon cake",course:"dessert",cuisine:"French",allergens:.init(contains:["egg"]))
        let unknown = entry("Lemon mystery")
        var filters = RecipeFilters(); filters.courses = ["soup","main"]; filters.cuisines = ["Italian"]; filters.sources = ["My notes"]; filters.contains = ["milk"]
        #expect(filters.entries([a,b,unknown],query:"lemon",sort:.updated).map(\.id) == [a.id])
        filters.avoid = ["wheat"]; #expect(filters.entries([a,b,unknown],query:"",sort:.updated).isEmpty)
        filters = RecipeFilters(); filters.avoid = ["wheat"]
        #expect(filters.matches(unknown)) // Unknown stays unknown, never becomes an allergen-free claim.
        filters = RecipeFilters(); #expect(!filters.isActive && filters.entries([a,b,unknown],query:"",sort:.updated).count == 3)
        filters.courses = [RecipeFilters.unspecified]; #expect(filters.matches(unknown) && !filters.matches(a))
    }
    @Test func directionalSortIsStableAndMissingDatesStayLast() {
        let a = entry("Apple",date:3), z = entry("Zucchini",date:1)
        var missing = entry("Missing"); missing.createdAt = nil; missing.updatedAt = nil
        let filters = RecipeFilters()
        #expect(filters.entries([z,a],query:"",sort:.alphabetical).map(\.id) == [a.id,z.id])
        #expect(filters.entries([z,a],query:"",sort:.reverseAlphabetical).map(\.id) == [z.id,a.id])
        #expect(filters.entries([missing,a,z],query:"",sort:.newest).map(\.id) == [a.id,z.id,missing.id])
        #expect(filters.entries([missing,a,z],query:"",sort:.oldest).map(\.id) == [z.id,a.id,missing.id])
    }
}
