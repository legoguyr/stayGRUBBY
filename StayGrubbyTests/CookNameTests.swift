import Foundation
import SwiftData
import Testing
@testable import StayGrubby

/// D1: renameable cooks (FOOD_ARCHITECTURE §4.2). Names are labels only.
@MainActor struct CookNameTests {
    @Test func normalizationTrimsCollapsesBoundsAndClears() {
        #expect(CookName.normalized("  Spicy \n  Version ") == "Spicy Version")
        #expect(CookName.normalized("   ") == nil)
        #expect(CookName.normalized(nil) == nil)
        #expect(CookName.normalized(String(repeating: "a", count: 250))?.count == CookName.maximumLength)
    }

    @Test func fallbackFollowsStableSequenceAndHidesForLoneUnnamedCook() {
        #expect(CookName.label(custom: nil, sequence: 1, siblingCount: 1) == nil)
        #expect(CookName.label(custom: nil, sequence: 1, siblingCount: 2) == "Version 1")
        // Gaps after deletion stay honest; numbers never renumber.
        #expect(CookName.label(custom: nil, sequence: 3, siblingCount: 1) == "Version 3")
        #expect(CookName.label(custom: " Thanksgiving 2026 ", sequence: 1, siblingCount: 1) == "Thanksgiving 2026")
        #expect(CookName.name(custom: nil, sequence: 2) == "Version 2")
    }

    @Test func renameChangesOnlyNameAndDisplayCacheNeverEvidence() throws {
        let f = try CookingReRankingWorkflowTests().fixture(3)
        defer { withExtendedLifetime(f) {} }
        let dish = try #require(f.cooks[0].dish)
        #expect(f.cooks[0].rankedItem?.name == "Dish 0") // lone unnamed cook: no fallback label
        var session = RankingEngine(itemID: UUID(), orderedIDs: f.list.orderedItems.map(\.id), reaction: .liked)
        while session.nextOpponent != nil { session.answer(.newItem) }
        let second = try CookingStore.create(draft: CookingDraft(dish: dish), existingDish: dish, session: session, context: f.context)
        let first = f.cooks[0]
        #expect(first.meaningfulVersionLabel == "Version 1" && second.meaningfulVersionLabel == "Version 2")
        #expect(first.rankedItem?.name == "Dish 0 — Version 1") // sibling cache follows fallback visibility

        let before = try CookingGraphExport.snapshot(context: f.context)
        let order = f.list.orderedItems.map(\.id)
        let operations = try f.context.fetchCount(FetchDescriptor<SyncOperation>())
        try CookingStore.rename(second, to: "  Spicy   Version ", context: f.context)
        let after = try CookingGraphExport.snapshot(context: f.context)

        #expect(second.versionTitle == "Spicy Version")
        #expect(second.displayName == "Dish 0 — Spicy Version" && second.rankedItem?.name == second.displayName)
        #expect(first.meaningfulVersionLabel == "Version 1")
        // IDs, strengths, uncertainty, diagnostics, comparisons and order are unchanged.
        func evidence(_ items: [RankedItemTransfer]) -> [String] {
            items.map { "\($0.id)|\($0.strength)|\($0.uncertainty)|\($0.rankingID?.uuidString ?? "")|\($0.sessionDiagnosticsData?.base64EncodedString() ?? "")" }.sorted()
        }
        #expect(evidence(before.items) == evidence(after.items))
        #expect(before.comparisons == after.comparisons)
        #expect(before.attempts.map(\.id) == after.attempts.map(\.id))
        #expect(before.attempts.map(\.sequenceNumber) == after.attempts.map(\.sequenceNumber))
        #expect(f.list.orderedItems.map(\.id) == order)
        #expect(try f.context.fetchCount(FetchDescriptor<SyncOperation>()) >= operations)

        // Clearing returns to the fallback; an unchanged name is a no-op.
        try CookingStore.rename(second, to: "   ", context: f.context)
        #expect(second.versionTitle == nil && second.meaningfulVersionLabel == "Version 2")
        #expect(second.rankedItem?.name == "Dish 0 — Version 2")
        let unchanged = try CookingGraphExport.snapshot(context: f.context)
        try CookingStore.rename(second, to: nil, context: f.context)
        #expect(try CookingGraphExport.snapshot(context: f.context) == unchanged)
        #expect(evidence(unchanged.items) == evidence(before.items) && unchanged.comparisons == before.comparisons)
    }

    @Test func namesAreNotUniqueBecauseIdentityIsTheID() throws {
        let f = try CookingReRankingWorkflowTests().fixture(2)
        defer { withExtendedLifetime(f) {} }
        try CookingStore.rename(f.cooks[0], to: "Spicy", context: f.context)
        try CookingStore.rename(f.cooks[1], to: "Spicy", context: f.context)
        #expect(f.cooks[0].versionTitle == f.cooks[1].versionTitle && f.cooks[0].id != f.cooks[1].id)
    }
}
