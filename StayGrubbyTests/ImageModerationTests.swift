import Foundation
import Testing
import UIKit
@testable import StayGrubby

@MainActor struct ImageModerationTests {
    private func jpeg() throws -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { context in
            UIColor.orange.setFill(); context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        return try #require(image.jpegData(compressionQuality: 0.8))
    }
    @Test func reviewerVisibilityRequiresServerMembership() async {
        let ordinary: SocialRequest = { _, _, _ in throw URLError(.userAuthenticationRequired) }
        let staff: SocialRequest = { endpoint, action, _ in
            #expect(endpoint == "image_moderation" && action == "capabilities")
            return Data(#"{"reviewer":true}"#.utf8)
        }
        #expect(!(await ImageModerationModel.authorized(request: ordinary)))
        #expect(await ImageModerationModel.authorized(request: staff))
    }
    @Test func reviewUsesFreshOriginalAndExplicitGenerationHashAndDecision() async throws {
        let id = UUID(), generation = UUID(), path = UUID().uuidString.lowercased()+"/"+UUID().uuidString.lowercased()+".jpg"
        let bytes = try jpeg(), model = ImageModerationModel()
        var submitted: SocialPayload?
        let request: SocialRequest = { _, action, payload in
            if action == "resolve" { submitted = payload; return Data(#"{"state":"approved"}"#.utf8) }
            return try JSONSerialization.data(withJSONObject: ["objectID":id.uuidString,"generation":generation.uuidString,"state":"pending","bucket":"social-photos","path":path])
        }
        let media: SocialMediaRequest = { action in
            guard case .reviewDownload(let bucket, let receivedPath) = action else { throw URLError(.unsupportedURL) }
            #expect(bucket == "social-photos" && receivedPath == path)
            return bytes
        }
        await model.inspect(id, request: request, media: media)
        #expect(model.image != nil && model.hash == RecipePhotoService.digest(bytes))
        #expect(await model.decide("approved", request: request))
        #expect(submitted?.objectID == id && submitted?.generation == generation && submitted?.expectedState == "pending")
        #expect(submitted?.photoHash == RecipePhotoService.digest(bytes) && submitted?.decision == "approved")
    }
    @Test func invalidFileCanBeRejectedButCannotBeApproved() async throws {
        let id = UUID(), generation = UUID(), model = ImageModerationModel()
        let path = UUID().uuidString.lowercased()+"/"+UUID().uuidString.lowercased()+".jpg"
        var decisions = 0
        let request: SocialRequest = { _, action, _ in
            if action == "resolve" { decisions += 1; return Data(#"{"state":"rejected"}"#.utf8) }
            return try JSONSerialization.data(withJSONObject: ["objectID":id.uuidString,"generation":generation.uuidString,"state":"pending","bucket":"recipe-photos","path":path])
        }
        await model.inspect(id, request: request, media: { _ in Data("invalid image".utf8) })
        #expect(model.image == nil && model.failed)
        #expect(!(await model.decide("approved", request: request)) && decisions == 0)
        #expect(await model.decide("rejected", request: request))
        #expect(decisions == 1)
    }
    @Test func leavingReviewDiscardsAnInflightOriginal() async throws {
        let id = UUID(), model = ImageModerationModel(), bytes = try jpeg()
        let path = UUID().uuidString.lowercased()+"/"+UUID().uuidString.lowercased()+".jpg"
        let request: SocialRequest = { _, _, _ in
            try JSONSerialization.data(withJSONObject: ["objectID":id.uuidString,"generation":UUID().uuidString,"state":"pending","bucket":"social-photos","path":path])
        }
        await model.inspect(id, request: request, media: { _ in
            model.clearInspection() // The app backgrounds while the download is in flight.
            return bytes
        })
        #expect(model.inspection == nil && model.image == nil && model.hash == nil)
        #expect(!(await model.decide("approved", request: request)))
    }
    @Test func inspectionCannotReadPrivateCookingBucket() async throws {
        let id = UUID(), model = ImageModerationModel()
        var downloads = 0
        let request: SocialRequest = { _, _, _ in
            try JSONSerialization.data(withJSONObject: ["objectID":id.uuidString,"generation":UUID().uuidString,"state":"pending","bucket":"cooking-photos","path":"private"])
        }
        await model.inspect(id, request: request, media: { _ in downloads += 1; return Data() })
        #expect(model.failed && model.image == nil && downloads == 0)
    }
    @Test func aDeniedCacheHitWithdrawsMemoryAndDiskInsteadOfDisplayingBytes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = AccountContentCache(mediaDirectory: root), bytes = try jpeg()
        let image = try #require(UIImage(data: bytes)), key = "post-image/fixture"
        cache.media.storeImage(image, key: key)
        cache.media.store(bytes, key: key)
        cache.media.store(bytes, key: "social-photos/fixture")
        var downloads = 0
        let media: SocialMediaRequest = { action in
            if case .authorize = action { throw URLError(.userAuthenticationRequired) }
            downloads += 1; return bytes
        }
        do {
            _ = try await AuthorizedRemoteImage.load(key: key, action: .download(path: "fixture"), cache: cache, media: media)
            Issue.record("A denied permission check must fail closed")
        } catch { }
        #expect(cache.media.image(key) == nil && cache.media.data(key) == nil && cache.media.data("social-photos/fixture") == nil && downloads == 0)
    }
    @Test func authorizedCacheHitUsesOnePermissionReadWithoutAnotherDownload() async throws {
        let cache = AccountContentCache(mediaDirectory: nil), bytes = try jpeg()
        cache.media.storeImage(try #require(UIImage(data: bytes)), key: "fixture")
        var checks = 0, downloads = 0
        let media: SocialMediaRequest = { action in
            if case .authorize = action { checks += 1; return Data() }
            downloads += 1; return bytes
        }
        _ = try await AuthorizedRemoteImage.load(key: "fixture", action: .avatarDownload(path: "fixture"), cache: cache, media: media)
        #expect(checks == 1 && downloads == 0)
    }
    @Test func alternateByteCacheEntryAlsoRequiresCurrentPermission() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = AccountContentCache(mediaDirectory: root), bytes = try jpeg(), key = "social-photos/fixture"
        cache.media.store(bytes, key: key)
        var downloads = 0
        let media: SocialMediaRequest = { action in
            if case .authorize = action { throw URLError(.userAuthenticationRequired) }
            downloads += 1; return bytes
        }
        do {
            _ = try await AuthorizedRemoteImage.bytes(key: key, action: .download(path: "fixture"), cache: cache, media: media)
            Issue.record("Alternate cache users must observe the same access decision")
        } catch { }
        #expect(cache.media.data(key) == nil && downloads == 0)
    }

}
