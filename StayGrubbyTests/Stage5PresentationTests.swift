import Foundation
import Testing
@testable import StayGrubby

@MainActor struct Stage5PresentationTests {
    @Test func conversionIsHiddenAndServingProjectionRemainsReadOnly() {
        #expect(!RecipeUnits.showsControl)
        var content=RecipeContent(title:"Rice",yield:"4 servings")
        content.components=[.init(ingredients:[.init(quantity:"400",unit:"g",name:"Arborio rice")],steps:[.init(instruction:"Cook as written.")])]
        let original=content, scaled=RecipeUnits.content(content,mode:.original,servings:8)
        #expect(scaled.orderedComponents[0].ingredients[0].quantity == "800")
        #expect(scaled.orderedComponents[0].ingredients[0].unit == "g" && content == original)
        #expect(RecipeUnits.content(content,mode:.original,servings:nil).orderedComponents[0].ingredients[0].quantity == "400")
    }
    #if DEBUG
    @Test func reviewProfileRecipesNeverReturnForeignPrivateOrBorrowedOwnership() async throws {
        let review=SocialReview(), peer=review.people[0], own=UUID(), shared=UUID(), secret=UUID()
        review.recipes[own]=Recipe(id:own,isOwner:true,content:.init(title:"Own"),visibility:"private",revision:1,createdAt:1,updatedAt:1,saved:false)
        review.recipes[shared]=Recipe(id:shared,isOwner:false,creator:peer,content:.init(title:"Shared"),visibility:"friends",revision:1,createdAt:1,updatedAt:1,saved:false)
        review.recipes[secret]=Recipe(id:secret,isOwner:false,creator:peer,content:.init(title:"Secret"),visibility:"private",revision:1,createdAt:1,updatedAt:1,saved:false)
        let ownPage=try JSONDecoder().decode(CookbookPage.self,from:await review.request("recipes","profile_index",.init()))
        #expect(ownPage.entries.map(\.recipeID) == [own])
        let other=try JSONDecoder().decode(CookbookPage.self,from:await review.request("recipes","profile_index",.init(peerID:peer.id)))
        #expect(other.entries.map(\.recipeID) == [shared] && other.entries[0].dishID == nil)
    }
    #endif
}
