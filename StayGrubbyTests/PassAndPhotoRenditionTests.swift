import Testing
import Foundation
@testable import StayGrubby

/// One stored photo, two renditions: each frame asks for the rendition its size needs, so a Recipe/Dish hero,
/// a card or a tile never stretches the 360 px thumbnail (blurry Recipe-linked photo, November 11 2026).
struct PassAndPhotoRenditionTests {
    @Test func onlyFixedSmallFramesUseTheThumbnailRendition() {
        #expect(SGPhotoRole.thumbnail.usesThumbnailRendition)
        #expect(SGPhotoRole.compactThumbnail.usesThumbnailRendition)
        for role in [SGPhotoRole.tile, .card, .cookbook, .hero] { #expect(!role.usesThumbnailRendition) }
        // The thumbnail covers the largest fixed frame at 3x; flexible frames need display.
        #expect(Double(LocalPhotoStore.thumbnailMaximumPixels) >= Double(SGTheme.Size.rowThumbnail) * 3)
        #expect(LocalPhotoStore.displayMaximumPixels >= 1_200)
    }

    @Test func sharedPhotosAreNeverDownsampledBelowTheirUploadedRendition() {
        #expect(SocialPhoto.maximumPixels >= LocalPhotoStore.displayMaximumPixels)
    }

    @Test func passPageKeepsCookPostsInOrderAndPaginatesOnTheLastServerItem() throws {
        let author = SocialPerson(id: UUID(), displayName: "Cook", username: "cook", relationship: .friends)
        let post = SocialPost(id: UUID(), author: author, title: "Shakshuka", versionTitle: nil, scoreText: nil, achievement: nil,
                              createdAt: 200, photoPath: "\(author.id)/p.jpg", published: true, isAuthor: false, moderationState: "active")
        let cook = try JSONSerialization.jsonObject(with: JSONEncoder().encode(post))
        let legacy = UUID(), older = UUID()
        let raw: [String: Any] = ["activities": [
            ["kind": "recipe_created", "recipe": ["id": legacy.uuidString, "createdAt": 300]],
            ["kind": "cook", "post": cook],
            ["kind": "recipe_created", "recipe": ["id": older.uuidString, "createdAt": 100]],
        ]]
        let page = try JSONDecoder().decode(PassPage.self, from: JSONSerialization.data(withJSONObject: raw))
        #expect(page.posts.map(\.id) == [post.id] && page.posts.first?.photoPath == post.photoPath)
        #expect(page.cursor == PassPage.Cursor(createdAt: 100, id: older)) // the last server item, of any kind
        #expect(page.serverCount == 3 && !page.hasMore)
    }
}
