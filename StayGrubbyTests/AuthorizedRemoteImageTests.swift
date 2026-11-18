import Foundation
import Testing
import UIKit
@testable import StayGrubby

@MainActor struct AuthorizedRemoteImageTests {
    private func jpeg() throws -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { context in
            UIColor.orange.setFill(); context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        return try #require(image.jpegData(compressionQuality: 0.8))
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
