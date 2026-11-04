import Foundation
import SwiftData
import Testing
@testable import StayGrubby

@MainActor struct Stage2OwnerCorrectionTests {
    @Test func hiddenLegacyMetadataSurvivesOrdinaryOwnerEdits() throws {
        let f = try CookingReRankingWorkflowTests().fixture(1); defer { withExtendedLifetime(f) {} }
        let cook = f.cooks[0]
        var old = CookingDraft(attempt: cook); old.customTags = ["Legacy custom label"]; old.dietary = [.halal, .vegetarian]
        old.publicDescription = "Public description"; old.privateNotes = "Owner-only Dish note"; old.notes = "Private cook note"
        try CookingStore.edit(cook, draft: old, context: f.context)
        let ids = cook.tags.map(\.persistentModelID)
        let before = try CookingGraphExport.snapshot(context: f.context)
        var edit = CookingDraft(attempt: cook); edit.category = .soup
        // Visible dietary choices extend the existing set instead of stripping a hidden legacy value.
        edit.dietary.insert(.glutenFree)
        try CookingStore.edit(cook, draft: edit, context: f.context)
        #expect(cook.customTags == ["Legacy custom label"] && cook.dietaryTags.contains(.halal))
        #expect(Set(ids).isSubset(of: Set(cook.tags.map(\.persistentModelID))))
        #expect(cook.notes == "Private cook note" && cook.dish?.privateNotes == "Owner-only Dish note")
        #expect(cook.dish?.publicDescription == "Public description")
        #expect(!CookingProductOptions.dietary.contains(.halal))
        #expect(DietaryTag(rawValue: "halal") == .halal)
        #expect(CookingDiscovery.entries(in: f.list, attempts: f.cooks, query: "Legacy custom label").isEmpty)
        let after = try CookingGraphExport.snapshot(context: f.context)
        #expect(after.items == before.items && after.comparisons == before.comparisons && after.media == before.media)
    }

    @Test(arguments: CookingBrowseSort.allCases)
    func browsingOrdersPreserveEveryIdentityRankAndEvidence(order: CookingBrowseSort) throws {
        let f = try CookingReRankingWorkflowTests().fixture(10); defer { withExtendedLifetime(f) {} }
        for (i, cook) in f.cooks.enumerated() { cook.cookedAt = i == 3 ? nil : Date(timeIntervalSince1970: Double(i * 100)) }
        try f.context.save()
        let before = try CookingGraphExport.snapshot(context: f.context)
        let entries = CookingDiscovery.entries(in: f.list, attempts: f.cooks)
        let scores = ScoreUnlockPolicy.state(in: f.context, list: f.list)
        let sorted = CookingBrowseOrder.entries(entries, order: order, scores: scores)
        #expect(Set(sorted.map(\.id)) == Set(entries.map(\.id)))
        #expect(Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0.globalRank) }) == Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.globalRank) }))
        if order == .grubRank { #expect(sorted.map(\.id) == entries.map(\.id)) }
        if order == .alphabetical { #expect(sorted.map(\.id) == f.cooks.map(\.id)) }
        if order == .score {
            let visible = sorted.compactMap { $0.attempt.rankedItem.flatMap { scores.scoreText($0.score) }.flatMap(Double.init) }
            #expect(visible == visible.sorted(by: >))
        }
        if order == .recentlyCooked || order == .oldest { #expect(sorted.last?.attempt.cookedAt == nil) }
        if order == .recentlyCooked { #expect(sorted.first?.attempt.id == f.cooks.last?.id) }
        if order == .oldest { #expect(sorted.first?.attempt.id == f.cooks.first?.id) }
        #expect(try CookingGraphExport.snapshot(context: f.context) == before && !f.context.hasChanges)
        let locked = CookingBrowseOrder.entries(entries, order: .score, scores: .locked)
        #expect(locked.map(\.id) == entries.map(\.id))
    }
    @Test func versionProjectionAndFilteringPrecedeSorting() throws {
        let f = try CookingReRankingWorkflowTests().fixture(4); defer { withExtendedLifetime(f) {} }
        let eligible = CookingDiscovery.entries(in: f.list, attempts: f.cooks)
        let match = CookingDiscovery.entries(in: f.list, attempts: f.cooks, query: "Dish 2")
        let projected = RankingsPresentation.entries(eligible, matching: match, mode: .topVersion)
        #expect(projected.count == 1)
        #expect(CookingBrowseOrder.entries(projected, order: .alphabetical, scores: .locked).map(\.globalRank) == projected.map(\.globalRank))
    }
    @Test func stableTimestampBoundariesAndMissingMetadata() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        for (seconds, expected) in [(0.0,"Just now"),(59,"Just now"),(60,"1 min ago"),(3599,"59 min ago"),(3600,"1 hr ago"),(86399,"23 hr ago"),(86400,"1 day ago"),(518400,"6 days ago")] {
            #expect(SocialPostPresentation.timestamp(now.addingTimeInterval(-seconds), now: now) == expected)
        }
        #expect(SocialPostPresentation.timestamp(now.addingTimeInterval(60), now: now) == "Just now")
        #expect(!SocialPostPresentation.timestamp(now.addingTimeInterval(-604800), now: now).contains("ago"))
        #expect(SocialPostPresentation.metadata(nil) == nil)
        #expect(SocialPostPresentation.metadata(.init(course: "soup")) == "Soup")
        let cuisine = try #require(CuisineCatalog.resolve("Italian"))
        #expect(SocialPostPresentation.metadata(.init(cuisine: cuisine)) == "Italian")
        #expect(SocialPostPresentation.metadata(.init(course: "main", cuisine: cuisine)) == "Main • Italian")
    }
    @Test func profileShareURLIsTheSamePrivateSafePointer() throws {
        let url = try #require(AppRoute.profileURL(username: "review_cook"))
        #expect(url.absoluteString == "https://staygrubby.com/@review_cook")
        #expect(url.query == nil && url.fragment == nil && url.user == nil && url.password == nil)
    }
}
