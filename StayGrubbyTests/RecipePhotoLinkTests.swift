import Foundation
import SwiftData
import Testing
@testable import StayGrubby

@MainActor struct RecipePhotoLinkTests {
    @Test func exactVersionAndOwnedPhotoHaveIndependentDeterministicIdentity() throws {
        let f = try CookingReRankingWorkflowTests().fixture(2)
        defer { withExtendedLifetime(f) {} }
        let first = f.cooks[0], second = f.cooks[1], dish = try #require(first.dish)
        second.dish = dish
        func media(_ cook: CookingAttempt) -> CookingMedia {
            let id = UUID(); let m = CookingMedia(id: id, displayFilename: id.uuidString+".jpg", thumbnailFilename: id.uuidString+"-thumb.jpg", pixelWidth: 10, pixelHeight: 10)
            f.context.insert(m); m.attempt = cook; cook.media.append(m); return m
        }
        let firstImage = media(first), secondImage = media(second), ownedPhoto = UUID()
        try f.context.save()
        let before = try CookingGraphExport.snapshot(context: f.context)
        #expect(RecipePhotoPolicy.fallbackCook(ownedPhoto: ownedPhoto, cook: first, dish: dish, exactLink: true) == nil)
        #expect(RecipePhotoPolicy.fallbackCook(ownedPhoto: nil, cook: first, dish: dish, exactLink: true)?.primaryImage?.id == firstImage.id)
        #expect(RecipePhotoPolicy.fallbackCook(ownedPhoto: nil, cook: second, dish: dish, exactLink: true)?.primaryImage?.id == secondImage.id)
        #expect(RecipePhotoPolicy.fallbackCook(ownedPhoto: nil, cook: nil, dish: dish, exactLink: true) == nil)
        #expect(RecipePhotoPolicy.fallbackCook(ownedPhoto: nil, cook: nil, dish: dish, exactLink: false)?.id == dish.cookbookRepresentativeCook?.id)
        #expect(try CookingGraphExport.snapshot(context: f.context) == before)
        // Replacing a Recipe photo changes no cook-owned identity/media.
        #expect(RecipePhotoPolicy.fallbackCook(ownedPhoto: UUID(), cook: second, dish: dish, exactLink: true) == nil)
        #expect(first.primaryImage?.id == firstImage.id && second.primaryImage?.id == secondImage.id)
    }
}
