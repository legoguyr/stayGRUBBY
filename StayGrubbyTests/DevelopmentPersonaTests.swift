#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import StayGrubby

@MainActor struct DevelopmentPersonaTests {
    @Test func launchFlagRequiresAValidIsolatedStore() {
        let plain = DebugReviewConfiguration(arguments: ["--development-persona"])
        let invalid = DebugReviewConfiguration(arguments: ["--development-persona", "--ui-test-store", "bad"])
        #expect(!plain.developmentPersona && !invalid.developmentPersona)
        #expect(!plain.socialReview && !invalid.socialReview)
        let id = UUID().uuidString
        let isolated = DebugReviewConfiguration(arguments: ["--ui-test-store", id])
        let persona = DebugReviewConfiguration(arguments: ["--development-persona", "--ui-test-store", id])
        let root = FileManager.default.temporaryDirectory
        #expect(persona.developmentPersona && persona.socialReview && !isolated.socialReview)
        #expect(persona.storeURL(in: root) != isolated.storeURL(in: root))
        #expect(persona.mediaRoot(in: root) != isolated.mediaRoot(in: root))
    }

    @Test func seededRankingsAndRecipeSnapshotsUseActualCookRelationships() async throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("persona-test-\(UUID()).seeded")
        defer { try? FileManager.default.removeItem(at: marker) }
        let container = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        try DevelopmentPersona.seed(context: context, marker: marker)
        let initial = try CookingGraphExport.snapshot(context: context)
        try DevelopmentPersona.seed(context: context, marker: marker)
        #expect(try CookingGraphExport.snapshot(context: context) == initial)
        #expect(initial.dishes.count == 11 && initial.attempts.count == 14)
        #expect(!initial.comparisons.isEmpty)
        #expect(ScoreUnlockPolicy.state(in: context).rankedEntryCount == 14)
        let attempts = try context.fetch(FetchDescriptor<CookingAttempt>())
        let latest = try #require(attempts.first { $0.versionTitle == "Smoky Sunday" })
        let ordinary = try #require(attempts.first { $0.versionTitle == "Oven-roasted batch" })
        #expect(latest.dish?.id == ordinary.dish?.id)

        let review = SocialReview()
        try review.loadPersona(context: context)
        let data = try await review.request("recipes", "provenance", .init(targetID: latest.rankedItemID))
        let snapshot = try #require(JSONDecoder().decode(RecipeCooksPage.self, from: data).cooks.first)
        let recipeID = try #require(snapshot.recipeID)
        let current = try JSONDecoder().decode(Recipe.self, from: await review.request("recipes", "get", .init(recipeID: recipeID)))
        #expect(current.linkedAttemptID == latest.id && current.linkedDishID == latest.dish?.id)
        #expect(snapshot.revision == 1 && current.revision == 2 && snapshot.snapshot.steps != current.content.steps)
        #expect(snapshot.creatorName == "Avery Chen")
        let other = try await review.request("recipes", "provenance", .init(targetID: ordinary.rankedItemID))
        #expect(try JSONDecoder().decode(RecipeCooksPage.self, from: other).cooks.isEmpty)
        #expect(review.posts.contains { review.postCookIDs[$0.id] == latest.id && $0.isAuthor })
    }
}
#endif
