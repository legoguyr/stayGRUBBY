import Foundation
import SwiftData
import Testing
@testable import StayGrubby

/// One canonical Dish universe (FOOD_ARCHITECTURE §3.4): combining two identities of the same
/// real-world Dish moves everything onto one Dish and loses no evidence.
@MainActor struct DishIdentityCombineTests {
    @Test func combiningMovesCooksAndKeepsEveryPieceOfEvidence() throws {
        let f = try CookingReRankingWorkflowTests().fixture(3)
        defer { withExtendedLifetime(f) {} }
        let ranked = try #require(f.cooks[0].dish), recipeDish = try #require(f.cooks[1].dish)
        ranked.privateNotes = "Grill hot."; recipeDish.privateNotes = "Marinate overnight."
        recipeDish.publicDescription = "Smoky and bright."; recipeDish.cuisine = CuisineCatalog.resolve("Moroccan")
        try f.context.save()
        let movedCook = f.cooks[1], movedID = movedCook.id, movedItem = movedCook.rankedItemID
        let order = f.list.orderedItems.map(\.id)
        let before = try CookingGraphExport.snapshot(context: f.context)

        try DishIdentityStore.combine(recipeDish, into: ranked, context: f.context)

        let after = try CookingGraphExport.snapshot(context: f.context)
        #expect(movedCook.dish?.id == ranked.id && movedCook.id == movedID && movedCook.rankedItemID == movedItem)
        #expect(ranked.attempts.count == 2 && Set(ranked.attempts.map(\.sequenceNumber)) == [1, 2])
        #expect(after.dishes.count == before.dishes.count - 1 && !after.dishes.contains { $0.id == recipeDish.id })
        // Ranking evidence is untouched: same items, strengths, comparisons and global order.
        func evidence(_ items: [RankedItemTransfer]) -> [String] { items.map { "\($0.id)|\($0.strength)|\($0.uncertainty)" }.sorted() }
        #expect(evidence(after.items) == evidence(before.items) && after.comparisons == before.comparisons)
        #expect(f.list.orderedItems.map(\.id) == order)
        #expect(Set(after.attempts.map(\.id)) == Set(before.attempts.map(\.id)))
        // Dish text: empty fields filled, conflicting notes kept in order.
        #expect(ranked.publicDescription == "Smoky and bright." && ranked.cuisine?.label == "Moroccan")
        #expect(ranked.privateNotes == "Grill hot.\n\nMarinate overnight.")
        #expect(movedCook.meaningfulVersionLabel == "Version 2" && movedCook.rankedItem?.name == movedCook.displayName)
        #expect(try f.context.fetchCount(FetchDescriptor<SyncOperation>()) >= 0)
    }

    @Test func notesMergeKeepsSourceAttributionAndRespectsLimits() {
        #expect(DishIdentityStore.mergedNotes(nil, nil, sourceLabel: nil, keepsSource: false) == nil)
        #expect(DishIdentityStore.mergedNotes("A", "A", sourceLabel: nil, keepsSource: false) == "A")
        #expect(DishIdentityStore.mergedNotes("A", nil, sourceLabel: "Cookbook · Zahav", keepsSource: true) == "A\n\nAlso from: Cookbook · Zahav")
        let long = DishIdentityStore.mergedNotes(String(repeating: "x", count: 7_990), String(repeating: "y", count: 50), sourceLabel: nil, keepsSource: false)
        #expect(long?.unicodeScalars.count == DishTextPolicy.privateMaximum)
    }
}
