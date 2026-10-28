import Foundation
import Testing
@testable import StayGrubby

@MainActor struct FoodBibleV2Tests {
    @Test func disclosurePersistsPerAccountAndVersion() {
        let suite = "recipe-consent-test-\(UUID())", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let a = "account.\(UUID())", b = "account.\(UUID())"
        #expect(!RecipeImportConsent.acknowledged(scope: a, defaults: defaults))
        RecipeImportConsent.acknowledge(scope: a, defaults: defaults)
        #expect(RecipeImportConsent.acknowledged(scope: a, defaults: UserDefaults(suiteName: suite)!))
        #expect(!RecipeImportConsent.acknowledged(scope: b, defaults: defaults))
        #expect(!RecipeImportConsent.acknowledged(scope: nil, defaults: defaults))
        #expect(!RecipeImportConsent.acknowledged(scope: "development.\(UUID())", defaults: defaults))
        RecipeImportConsent.clear(scope: a, defaults: defaults)
        #expect(!RecipeImportConsent.acknowledged(scope: a, defaults: defaults))
    }
    @Test func noAcknowledgementSendsNothingAndManualStaysLocal() async {
        var calls = 0
        let request: RecipeImportRequest = { _ in calls += 1; throw RecipeImportFailure.quota }
        await #expect(throws: RecipeImportFailure.unavailable) { try await RecipePasteRequest.format("Private text", dishTitle: "", acknowledged: false, request: request) }
        #expect(calls == 0)
        let manual = RecipeImportValidation.manual("Private text", dishTitle: "Manual")
        #expect(manual.draft.orderedComponents[0].steps[0].instruction == "Private text")
        #expect(calls == 0)
        for _ in 0..<6 {
            await #expect(throws: RecipeImportFailure.quota) { try await RecipePasteRequest.format("Soup with stock", dishTitle: "Soup", acknowledged: true, request: request) }
        }
        #expect(calls == 6) // One per deliberate request; no local daily allowance or automatic retries.
        #expect(RecipeImportFailure.quota.message.contains("cooldown"))
    }
    @Test func libraryIdentityIsRecipeAndStandaloneSearches() throws {
        let id = UUID(), dish = UUID()
        let linked = CookbookEntry(dishID: dish, recipeID: id, dishTitle: "Cooked Dish", recipeTitle: "Recipe", revision: 1)
        let standalone = CookbookEntry(dishID: nil, recipeID: UUID(), dishTitle: "Kale Sauce", recipeTitle: "Kale Sauce", cuisine: "Italian", revision: 1, searchText: "Parmesan")
        #expect(linked.id == id && linked.id != dish)
        let decoded = try JSONDecoder().decode(CookbookEntry.self, from: JSONEncoder().encode(standalone))
        #expect(decoded.dishID == nil && decoded.recipeID == standalone.id)
        #expect(CookbookSearch.entries([linked,standalone], query: "Parmesan", course: "", cuisine: "Italian", alphabetical: true).map(\.id) == [standalone.id])
    }
    @Test func recipePhotoRoundTripAndVerifiedTransport() async throws {
        #if DEBUG
        let bytes = SocialReview.avatarFixture, id = UUID(), path = "\(UUID().uuidString.lowercased())/\(id.uuidString.lowercased()).jpg"
        let hash = RecipePhotoService.digest(bytes)
        var uploads = 0, completions = 0
        let descriptor = RecipePhotoDescriptor(id: id, path: path, sha256: hash, ready: false)
        let request: SocialRequest = { _, action, payload in
            #expect(payload.assetID == id)
            if action == "complete_photo" { completions += 1 }
            return try JSONEncoder().encode(RecipePhotoDescriptor(id: id, path: path, sha256: hash, ready: action != "prepare_photo"))
        }
        let media: SocialMediaRequest = { action in
            #expect(action.bucket == "recipe-photos")
            if case .recipeUpload(_, let data) = action { #expect(data == bytes); uploads += 1; return Data() }
            return bytes
        }
        #expect(try await RecipePhotoService.upload(bytes, id: id, request: request, media: media) == id)
        #expect(uploads == 1 && completions == 1)
        #expect(try await RecipePhotoService.download(id, request: request, media: media) == bytes)
        let corrupt: SocialMediaRequest = { _ in Data("bad".utf8) }
        await #expect(throws: AccountFoundationError.invalidResolution) { try await RecipePhotoService.download(id, request: request, media: corrupt) }
        var content = RecipeContent(title: "Photo Recipe", description: "Brief description."); content.photoID = descriptor.id
        let restored = try JSONDecoder().decode(RecipeContent.self, from: JSONEncoder().encode(content))
        #expect(restored == content)
        #endif
    }
}
