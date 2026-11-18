import Foundation
import Testing
@testable import StayGrubby

/// Master UI milestone (November 18, 2026): one Public Description, the card's cook line and Dish
/// page cook marks. Presentation and sync decisions only; ranking is untouched.
struct MasterUIMilestoneTests {
    private let author = SocialPerson(id: UUID(), displayName: "Alex", username: "alex", relationship: .friends)
    private func post(title: String, cook: String?, description: String? = nil, course: String? = nil) -> SocialPost {
        var value = SocialPost(id: UUID(), author: author, title: title, versionTitle: cook, scoreText: nil, achievement: nil,
                               createdAt: 1, photoPath: nil, published: true, isAuthor: true, moderationState: "active")
        value.postDescription = description
        if let course { value.metadata = .init(course: course) }
        return value
    }

    @Test func captionUpdatesOnlyWhenTheTextReallyDiffers() {
        let shown = post(title: "Soup", cook: nil, description: "  Bright and lemony \n")
        #expect(!PublicDescriptionSync.needsUpdate(shown, to: "Bright and lemony"), "Whitespace never triggers a write")
        #expect(PublicDescriptionSync.needsUpdate(shown, to: "Bright, lemony and herby"))
        #expect(PublicDescriptionSync.needsUpdate(post(title: "Soup", cook: nil), to: "New"))
        #expect(!PublicDescriptionSync.needsUpdate(post(title: "Soup", cook: nil), to: "  "), "Empty stays empty")
    }

    @Test func cookLineOmitsACookNameThatOnlyRepeatsTheDish() {
        #expect(SocialPostPresentation.cookLine(post(title: "Lemon Rice", cook: "lemon rice")) == nil)
        #expect(SocialPostPresentation.cookLine(post(title: "Lemon Rice", cook: "Crispy bottom", course: "side")) == "Crispy bottom · Side")
        #expect(SocialPostPresentation.cookLine(post(title: "Crème Brûlée", cook: "creme brulee", course: "dessert")) == "Dessert")
    }
}
