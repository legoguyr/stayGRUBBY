import Foundation

/// One page of The Pass (API `social_feed` `activity_page`; the internal contract keeps its original
/// names). The Pass is intentionally shared Cook activity only (FOOD_ARCHITECTURE §3). Deployed servers
/// still interleave legacy `recipe_created` items; they are never presented, but every item, of any
/// kind, advances the pagination cursor so a page made only of legacy items cannot stall "Load more".
nonisolated struct PassPage: Codable, Sendable {
    /// Cook posts, in server order.
    var posts: [SocialPost]
    /// The last item the server returned (any kind): the exclusive cursor for the next page.
    var cursor: Cursor?
    /// How many items the server returned before filtering (a full page means more may exist).
    var serverCount: Int

    nonisolated struct Cursor: Equatable, Sendable { var createdAt: Double; var id: UUID }
    static let pageSize = 25
    var hasMore: Bool { serverCount >= Self.pageSize }

    init(posts: [SocialPost]) {
        self.posts = posts; serverCount = posts.count
        cursor = posts.last.map { Cursor(createdAt: $0.createdAt, id: $0.id) }
    }

    private enum CodingKeys: String, CodingKey { case activities }
    private enum ItemKeys: String, CodingKey { case kind, post, recipe }
    private struct Stamp: Decodable { var id: UUID; var createdAt: Double }

    init(from decoder: Decoder) throws {
        var items = try decoder.container(keyedBy: CodingKeys.self).nestedUnkeyedContainer(forKey: .activities)
        var posts: [SocialPost] = [], cursor: Cursor?, count = 0
        while !items.isAtEnd {
            let item = try items.nestedContainer(keyedBy: ItemKeys.self)
            count += 1
            if try item.decode(String.self, forKey: .kind) == "cook" {
                let post = try item.decode(SocialPost.self, forKey: .post)
                posts.append(post); cursor = Cursor(createdAt: post.createdAt, id: post.id)
            } else if let stamp = (try? item.decodeIfPresent(Stamp.self, forKey: .recipe)) ?? (try? item.decodeIfPresent(Stamp.self, forKey: .post)) {
                cursor = Cursor(createdAt: stamp.createdAt, id: stamp.id) // Legacy/unknown activity: cursor only.
            }
        }
        self.posts = posts; self.cursor = cursor; serverCount = count
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var items = container.nestedUnkeyedContainer(forKey: .activities)
        for post in posts {
            var item = items.nestedContainer(keyedBy: ItemKeys.self)
            try item.encode("cook", forKey: .kind); try item.encode(post, forKey: .post)
        }
    }
}
