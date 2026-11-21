import Foundation
import SwiftData
import Testing
@testable import StayGrubby

@MainActor struct Stage2CookingEntryTests {
    private func container() throws -> ModelContainer {
        let container = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        _ = try CookingStore.prepare(context: container.mainContext)
        return container
    }
    @Test func entrySavesCookDescriptionAndPrivateMetadataSeparately() throws {
        let container = try container(); let context = container.mainContext
        defer { withExtendedLifetime(container) {} }
        var draft = CookingDraft(); draft.dishName = "Roasted peppers"
        draft.publicDescription = " Sweet, smoky peppers "
        draft.privateNotes = " My private Dish technique "
        draft.notes = " This cook needed less salt "
        draft.category = .main; draft.customTags = ["Sunday"]
        let cook = try CookingStore.create(draft: draft, session: RankingEngine(itemID: UUID(), orderedIDs: [], reaction: .liked), context: context)
        let dish = try #require(cook.dish)
        #expect(cook.publicDescription == "Sweet, smoky peppers" && dish.publicDescription == nil && dish.privateNotes == "My private Dish technique")
        #expect(cook.notes == "This cook needed less salt" && cook.customTags == ["Sunday"])
        let graph = try CookingGraphExport.snapshot(context: context)
        #expect(graph.dishes.first?.publicDescription == dish.publicDescription)
        #expect(graph.dishes.first?.privateNotes == dish.privateNotes)
        #expect(graph.attempts.first?.notes == cook.notes && graph.attempts.first?.publicDescription == cook.publicDescription)
        let inherited = CookingDraft(dish: dish)
        #expect(inherited.publicDescription.isEmpty && inherited.privateNotes == dish.privateNotes)
        #expect(inherited.notes.isEmpty && inherited.existingPhotoCount == 0)
    }
    @Test func editingAndCancellingDraftsPreserveEvidenceAndOriginalCookNotes() throws {
        let container = try container(); let context = container.mainContext
        defer { withExtendedLifetime(container) {} }
        var draft = CookingDraft(); draft.dishName = "Soup"; draft.notes = "Original cook notes"
        let cook = try CookingStore.create(draft: draft, session: RankingEngine(itemID: UUID(), orderedIDs: [], reaction: .fine), context: context)
        let before = try CookingGraphExport.snapshot(context: context)
        var edit = CookingDraft(attempt: cook)
        edit.publicDescription = "Public soup"; edit.privateNotes = "Private soup"
        #expect(cook.dish?.publicDescription == nil && cook.dish?.privateNotes == nil)
        try CookingStore.edit(cook, draft: edit, context: context)
        let after = try CookingGraphExport.snapshot(context: context)
        #expect(after.items == before.items && after.comparisons == before.comparisons)
        #expect(cook.id == before.attempts.first?.id && cook.notes == "Original cook notes")
        let reread = CookingDraft(attempt: cook)
        #expect(reread.publicDescription == "Public soup" && reread.privateNotes == "Private soup")
        edit.publicDescription = ""; edit.privateNotes = ""
        try CookingStore.edit(cook, draft: edit, context: context)
        #expect(cook.publicDescription == "" && cook.dish?.publicDescription == nil && cook.dish?.privateNotes == nil && cook.notes == "Original cook notes")
    }
    @Test func invalidDishTextCannotCreateOrPartiallyEdit() throws {
        let container = try container(); let context = container.mainContext
        defer { withExtendedLifetime(container) {} }
        var draft = CookingDraft(); draft.dishName = "Soup"; draft.publicDescription = String(repeating: "x", count: 2001)
        #expect(!draft.validDishText)
        #expect(throws: (any Error).self) { try CookingStore.create(draft: draft, session: RankingEngine(itemID: UUID(), orderedIDs: [], reaction: .liked), context: context) }
        #expect(try context.fetchCount(FetchDescriptor<CookingAttempt>()) == 0)
        draft.publicDescription = "Public"
        let cook = try CookingStore.create(draft: draft, session: RankingEngine(itemID: UUID(), orderedIDs: [], reaction: .liked), context: context)
        let before = try CookingGraphExport.snapshot(context: context)
        var edit = CookingDraft(attempt: cook); edit.privateNotes = "bad\0text"; edit.dishName = "Must not rename"
        #expect(throws: (any Error).self) { try CookingStore.edit(cook, draft: edit, context: context) }
        #expect(try CookingGraphExport.snapshot(context: context) == before)
    }
}
