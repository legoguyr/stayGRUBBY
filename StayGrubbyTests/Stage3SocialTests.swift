import Foundation
import Testing
import UIKit
@testable import StayGrubby

@MainActor struct Stage3SocialTests {
    @Test func directedPayloadContainsPointerAndNeverGrantsAccess() throws {
        let id = UUID(), peer = UUID(), origin = UUID()
        for content in [SocialSendContent.recipe(id), .post(id)] {
            let payload = content.payload(query: "Cook", after: "last_cook", peer: peer, origin: origin)
            let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
            #expect(json["targetType"] as? String == content.type)
            #expect(json["targetID"] as? String == id.uuidString)
            #expect(json["peerID"] as? String == peer.uuidString)
            #expect(json["originID"] as? String == origin.uuidString)
            #expect(json["body"] == nil && json["recipe"] == nil && json["visibility"] == nil)
        }
    }
    @Test func copyCaptionContainsOnlyThePublicExportModel() {
        let model = ShareCardModel(title: "Soup", versionSubtitle: "Lemon version", scoreText: "8.7", achievement: .topFive, photo: nil)
        let card = RenderedDishShareCard(image: UIImage(), model: model, hasPhoto: false)
        #expect(NativeDishShareSheet.caption(for: card) == "#stayGRUBBY\nSoup\nLemon version\n8.7 / 10")
        #expect(NativeDishShareSheet.activityItems(for: card).count == 2)
        #expect(!NativeDishShareSheet.activityItems(for: card).contains { $0 is URL })
        let locked = ShareCardModel(title: "Soup", versionSubtitle: nil, scoreText: nil, achievement: nil, photo: nil)
        #expect(NativeDishShareSheet.activityItems(for: .init(image: UIImage(), model: locked, hasPhoto: false)).isEmpty)
    }
    @Test func directedNoticesHaveClearIdentityAndDestinationPointers() {
        let actor = SocialPerson(id: UUID(), displayName: "Cook", username: "cook", relationship: .friends)
        for kind in ["recipe_shared", "post_shared"] {
            let notice = SocialNotification(id: UUID(), kind: kind, actor: actor, targetID: UUID(), postID: nil, createdAt: 100, read: false)
            #expect(notice.message == (kind == "recipe_shared" ? "sent you a Recipe" : "sent you a shared cook"))
            #expect(!notice.read && notice.postID == nil)
        }
    }
}
