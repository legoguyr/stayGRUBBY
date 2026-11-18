import Foundation
import Testing
@testable import StayGrubby

/// The Pass Dish Details: the creator's other shared cooks of one Dish (November 17, 2026).
struct SharedCookOrderTests {
    private let author = SocialPerson(id: UUID(), displayName: "Alex", username: "alex", relationship: .friends)
    private func post(_ title: String, score: String?, age: Double, author: SocialPerson? = nil, published: Bool = true, moderation: String = "active", key: String? = "dish-fixture") -> SocialPost {
        SocialPost(id: UUID(), author: author ?? self.author, title: title, versionTitle: nil, scoreText: score, achievement: nil,
                   createdAt: 1_000_000 - age, photoPath: nil, published: published, isAuthor: false, moderationState: moderation, dishKey: key)
    }
    @Test func groupsOnlyTheSameCreatorsVisibleCooksOfTheSameDish() {
        let shown = post("Harissa Chicken", score: "8.6", age: 0)
        let same = post("  harissa   CHICKEN ", score: "9.1", age: 10)
        let other = post("Lemon Rice", score: "7.0", age: 5, key: "other-dish")
        let someoneElse = post("Harissa Chicken", score: "9.9", age: 3, author: SocialPerson(id: UUID(), displayName: "Sam", username: "sam", relationship: .friends))
        let draft = post("Harissa Chicken", score: "5.0", age: 4, published: false)
        let hidden = post("Harissa Chicken", score: "5.0", age: 4, moderation: "hidden")
        let result = SharedCookOrder.otherCooks(of: shown, among: [shown, same, other, someoneElse, draft, hidden], order: .recent)
        #expect(result.map(\.id) == [same.id], "Excludes the shown post, other Dishes, other creators, drafts and moderated posts")
    }
    @Test func recentAndHighestRatedNeverRankALockedScore() {
        let shown = post("Soup", score: nil, age: 0)
        let locked = post("Soup", score: nil, age: 1)
        let high = post("Soup", score: "9.1", age: 30)
        let low = post("Soup", score: "6,5", age: 20)
        let all = [shown, locked, high, low]
        #expect(SharedCookOrder.otherCooks(of: shown, among: all, order: .recent).map(\.id) == [locked.id, low.id, high.id])
        #expect(SharedCookOrder.otherCooks(of: shown, among: all, order: .highestRated).map(\.id) == [high.id, low.id, locked.id],
                "Unlocked scores high to low; locked cooks follow, never ranked")
        #expect(SharedCookOrder.score(locked) == nil)
    }
    @Test func exactIdentitySurvivesRenamingAndNeverGuessesFromTitles() {
        let shown = post("Crème Brûlée", score: nil, age: 0)
        #expect(SharedCookLookup.sameDish(post("Renamed dessert", score: nil, age: 1), as: shown))
        #expect(!SharedCookLookup.sameDish(post("Crème Brûlée", score: nil, age: 1, key: "other-dish"), as: shown))
        #expect(!SharedCookLookup.sameDish(post("Crème Brûlée", score: nil, age: 1, key: nil), as: shown))
        let legacy = post("Crème Brûlée", score: nil, age: 0, key: nil)
        #expect(!SharedCookLookup.sameDish(legacy, as: legacy))
        let sam = SocialPerson(id: UUID(), displayName: "Sam", username: "sam", relationship: .friends)
        #expect(!SharedCookLookup.sameDish(post("Crème Brûlée", score: nil, age: 1, author: sam), as: shown))
    }
}
