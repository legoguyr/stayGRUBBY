import Foundation
import Testing
@testable import StayGrubby

@MainActor struct V1ProductCloseoutTests {
    @Test func onlyMeaningfulCookVersionLabelsWithoutStoredChanges() throws {
        let f = try CookingReRankingWorkflowTests().fixture(1); defer { withExtendedLifetime(f) {} }
        let cook = f.cooks[0]; cook.versionTitle = nil; cook.sequenceNumber = 1
        #expect(cook.meaningfulVersionLabel == nil && !cook.displayName.contains("Version 1"))
        #expect(cook.versionLabel == "Version 1")
        cook.versionTitle = "Extra crispy"; #expect(cook.meaningfulVersionLabel == "Extra crispy")
        cook.versionTitle = nil
        let second = CookingAttempt(item: RankedItem(name: "Second"), sequence: 2, category: .other, cookedAt: nil)
        cook.dish?.attempts.append(second); second.dish = cook.dish
        #expect(cook.meaningfulVersionLabel == "Version 1" && second.meaningfulVersionLabel == "Version 2")
        #expect(cook.sequenceNumber == 1 && cook.versionTitle == nil)
    }
    @Test func newSharingDefaultPreservesExistingAudienceAndForeignCreatorCredit() {
        let person = SocialPerson(id: UUID(), displayName: "Recipe Author", username: "recipe_author", relationship: .friends)
        var r = Recipe(id: UUID(), isOwner: true, creator: person, content: .init(title: "Soup"), visibility: "private", revision: 7, createdAt: 1, updatedAt: 2, saved: false)
        #expect(RecipeSharingPolicy.initiallyShared(nil))
        #expect(!RecipeSharingPolicy.initiallyShared(r) && RecipeSharingPolicy.creatorCredit(r) == nil)
        r.visibility = "friends"; #expect(RecipeSharingPolicy.initiallyShared(r))
        r.isOwner = false; #expect(RecipeSharingPolicy.creatorCredit(r) == "Recipe Author")
        r.content.originalCreator = "Cookbook Author"; #expect(RecipeSharingPolicy.creatorCredit(r) == "Cookbook Author")
        r.isOwner = true; r.content.originalCreator = "recipe author"; #expect(RecipeSharingPolicy.creatorCredit(r) == nil)
        #expect(r.revision == 7)
    }
    @Test func distinctRecipeActivityDecodesWithNoCookOrScore() throws {
        let recipe = UUID(), activity = UUID(), author = UUID()
        let json = """
        {"activities":[{"kind":"recipe_created","recipe":{"id":"\(activity)","createdAt":100,"isAuthor":false,"author":{"id":"\(author)","displayName":"Author","username":"author","relationship":"friends"},"entry":{"recipeID":"\(recipe)","dishTitle":"Soup","recipeTitle":"Soup","revision":3}}}]}
        """
        let page = try JSONDecoder().decode(GrubListPage.self, from: Data(json.utf8))
        guard case .recipe(let r) = page.activities.first else { Issue.record("Recipe activity decoded as cooking"); return }
        #expect(r.entry.recipeID == recipe && r.id == activity && r.entry.dishID == nil)
        let roundTrip = try JSONDecoder().decode(GrubListPage.self, from: JSONEncoder().encode(page))
        #expect(roundTrip.activities[0].id == activity)
    }
    @Test func historicalForeignCreatorSurvivesDecodingWithoutChangingRecipeContent() throws {
        let json = """
        {"id":"\(UUID())","creatorName":"Original Author","recipeID":null,"revision":4,"snapshot":{"title":"Pinned soup","ingredients":["stock"],"steps":["Simmer"]}}
        """
        let used = try JSONDecoder().decode(RecipeCookSnapshot.self, from: Data(json.utf8))
        #expect(used.creatorName == "Original Author" && used.recipeID == nil && used.revision == 4)
        #expect(used.snapshot.originalCreator == nil && used.snapshot.ingredients == ["stock"])
    }
}
