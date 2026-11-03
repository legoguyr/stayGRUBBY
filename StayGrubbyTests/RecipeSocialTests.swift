import Foundation
import Testing
@testable import StayGrubby

@MainActor struct RecipeSocialTests {
    @Test func publicationRequiresExplicitRecipeChoiceAndCarriesPinnedRevision() async throws {
        let rid = UUID(), pid = UUID(), author = SocialPerson(id: UUID(), displayName: "Cook", username: "cook", relationship: .none)
        let r = Recipe(id: rid, isOwner: true, content: .init(title: "Soup", description: "A useful introduction.", ingredients: ["water"], steps: ["Heat."]), visibility: "private", revision: 4, createdAt: 1, updatedAt: 1, saved: false)
        var payloads: [SocialPayload] = []
        let request: SocialRequest = { endpoint, action, payload in
            #expect(endpoint == "social_content" && action == "prepare")
            payloads.append(payload)
            return try JSONEncoder().encode(SocialPostsPage(posts: [.init(id: pid, author: author, title: "Soup", versionTitle: nil, scoreText: nil, achievement: nil, createdAt: 1, photoPath: nil, published: true, isAuthor: true, moderationState: "active")]))
        }
        _ = try await SocialPostPublisher.publish(attemptID: UUID(), postID: pid, revision: 10, includePhoto: false, photo: nil, request: request, media: nil)
        #expect(payloads[0].includeRecipe == false && payloads[0].recipeID == nil && payloads[0].sourceRevision == nil)
        _ = try await SocialPostPublisher.publish(attemptID: UUID(), postID: pid, revision: 10, includePhoto: false, photo: nil, request: request, media: nil, sharedRecipe: r)
        #expect(payloads[1].includeRecipe == true && payloads[1].recipeID == rid && payloads[1].sourceRevision == 4 && payloads[1].confirmed == true)
        #expect(payloads[1].recipe == nil) // No client-authored shared snapshot or private cook graph.
    }
    @Test func sharedContractPreservesDescriptionMetadataComponentsAndExactQuantities() throws {
        let content = RecipeContent(title: "Soup", description: "Optional Recipe-owned prose.", ingredients: ["1/2 cup lentils"], steps: ["Simmer for 5 minutes."], components: [.init(title: "Soup", order: 0, ingredients: [IngredientParser.parse("1/2 cup lentils").ingredient(id: UUID(), order: 0)], steps: [.init(order: 0, instruction: "Simmer for 5 minutes.")])], yield: "4 servings", prepMinutes: 5, cookMinutes: 10)
        let value = SharedRecipe(postID: UUID(), recipeID: UUID(), revision: 3, content: content, isAuthor: false)
        let bytes = try JSONEncoder().encode(value)
        let restored = try JSONDecoder().decode(SharedRecipe.self, from: bytes)
        #expect(restored.content == content && restored.revision == 3 && !restored.isAuthor)
        let scaled = RecipeScaling.content(restored.content, servings: 8)
        #expect(scaled.yield == "8 servings")
        #expect(restored.content.components?.first?.ingredients.first?.quantity == "1/2")
        let nilDescription = RecipeContent(title: "Legacy", ingredients: ["water"], steps: [])
        #expect(try JSONDecoder().decode(RecipeContent.self, from: JSONEncoder().encode(nilDescription)).description == nil)
    }
    #if DEBUG
    @Test func independentCopyPreservesIntroductionWithoutForeignPhotoOrSourceMutation() async throws {
        let review = SocialReview(), rid = UUID(), copyID = UUID(), originalPhoto = UUID()
        review.recipes[rid] = Recipe(id: rid, isOwner: false, content: .init(title: "Friend's soup", description: "A Recipe description.", ingredients: ["water"], steps: ["Heat."], photoID: originalPhoto), visibility: "friends", revision: 2, createdAt: 1, updatedAt: 1, saved: false)
        let data = try await review.request("recipes", "fork", .init(targetID: copyID, confirmed: true, recipeID: rid))
        let copy = try JSONDecoder().decode(Recipe.self, from: data)
        #expect(copy.isOwner && copy.visibility == "private" && copy.revision == 1 && copy.id != rid)
        #expect(copy.content.description == "A Recipe description." && copy.content.photoID == nil)
        #expect(review.recipes[rid]?.content.photoID == originalPhoto && review.recipes[rid]?.revision == 2)
    }
    #endif
}
