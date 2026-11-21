import Foundation
import Testing
import SwiftData
@testable import StayGrubby

@MainActor struct CookDescriptionTests {
    private func memory() throws -> ModelContainer {
        let c = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        _ = try CookingStore.prepare(context: c.mainContext)
        return c
    }
    private func create(_ context: ModelContext, description: String, dish: Dish? = nil) throws -> CookingAttempt {
        var draft = dish.map(CookingDraft.init(dish:)) ?? CookingDraft()
        draft.dishName = dish?.name ?? "Description soup"; draft.publicDescription = description
        draft.notes = "Private cook detail"; draft.privateNotes = "Private Dish detail"
        let list = try CookingStore.globalRanking(context: context)
        var engine = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .liked)
        while engine.nextOpponent != nil { engine.answer(.newItem) }
        return try CookingStore.create(draft: draft, existingDish: dish, session: engine, context: context)
    }
    @Test func untouchedNewCooksOmitDescriptionInsteadOfWritingAnExplicitClear() throws {
        let container = try memory(); let context = container.mainContext
        for text in ["", "  \n\t"] {
            let cook = try create(context, description: text)
            #expect(cook.publicDescription == nil)
            let encoded = try JSONEncoder().encode(AttemptTransfer(cook))
            let record = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
            #expect(record["publicDescription"] == nil)
            var edit = CookingDraft(attempt: cook); edit.notes = "Another private note"
            try CookingStore.edit(cook, draft: edit, context: context)
            #expect(cook.publicDescription == nil)
        }
        let described = try create(context, description: "  Intentional public description  ")
        #expect(described.publicDescription == "Intentional public description")
        let again = try create(context, description: "", dish: described.dish)
        #expect(again.publicDescription == nil && described.publicDescription == "Intentional public description")
    }
    @Test func clearingExistingCanonicalAndLegacyTextRemainsIntentional() throws {
        let container = try memory(); let context = container.mainContext
        let cook = try create(context, description: "Canonical text")
        var draft = CookingDraft(attempt: cook); draft.publicDescription = "  "
        try CookingStore.edit(cook, draft: draft, context: context)
        #expect(cook.publicDescription == "")
        cook.publicDescription = nil; cook.dish?.publicDescription = "Legacy text"; try context.save()
        draft = CookingDraft(attempt: cook); draft.publicDescription = ""
        try CookingStore.edit(cook, draft: draft, context: context)
        #expect(cook.publicDescription == "" && cook.dish?.publicDescription == "Legacy text")
    }
    @Test func newCooksNeverInheritOrOverwriteSiblingDescription() throws {
        let container = try memory(); let context = container.mainContext
        let first = try create(context, description: "First cook")
        let dish = try #require(first.dish)
        dish.publicDescription = "Legacy food description"; try context.save()
        #expect(CookingDraft(dish: dish).publicDescription.isEmpty)
        let second = try create(context, description: "Second cook", dish: dish)
        #expect(first.publicDescription == "First cook" && second.publicDescription == "Second cook")
        #expect(dish.publicDescription == "Legacy food description")
        #expect(first.notes == "Private cook detail" && dish.privateNotes == "Private Dish detail")
    }
    @Test func unrelatedLegacyEditsDoNotSilentlyChooseDishText() throws {
        let container = try memory(); let context = container.mainContext
        let cook = try create(context, description: "")
        cook.publicDescription = nil; cook.dish?.publicDescription = "Legacy food description"; try context.save()
        var draft = CookingDraft(attempt: cook)
        draft.useLegacyDescriptionContext(.init(attemptID: cook.id, publicDescription: nil, effectiveDescription: "Legacy active post caption", legacyDishDescription: "Legacy food description", legacyPosts: [], hasMoreLegacyPosts: false, needsReview: true))
        #expect(draft.publicDescription == "Legacy active post caption" && !draft.shouldSavePublicDescription)
        draft.notes = "Changed private note"
        try CookingStore.edit(cook, draft: draft, context: context)
        #expect(cook.publicDescription == nil)
        draft.publicDescription = "Deliberate Cook choice"
        try CookingStore.edit(cook, draft: draft, context: context)
        #expect(cook.publicDescription == "Deliberate Cook choice" && cook.dish?.publicDescription == "Legacy food description")
    }
    @Test func descriptionSaveUsesOneJournalOperationAndNoRankingChanges() throws {
        let container = try memory(); let context = container.mainContext
        let cook = try create(context, description: "Original")
        let binding = SyncStoreBinding(accountID: UUID(), restorationRequired: false); binding.acceptedRevision = 4
        context.insert(binding); try context.save(); try SyncJournal.enable(context)
        let before = try CookingGraphExport.snapshot(context: context)
        try CookingStore.editCookDescription(cook, publicDescription: " Updated ", context: context)
        let once = try SyncJournal.pending(context)
        #expect(once.count == 1)
        try CookingStore.editCookDescription(cook, publicDescription: "Updated", context: context)
        #expect(try SyncJournal.pending(context).count == 1)
        let after = try CookingGraphExport.snapshot(context: context)
        #expect(after.items == before.items && after.comparisons == before.comparisons && after.dishes == before.dishes)
        let changes = try JSONDecoder().decode(SyncChanges.self, from: #require(once.first).payload)
        #expect(changes.upserts.count == 1 && changes.upserts.first?.reference.entity == .attempt)
    }
    @Test func explicitClearAndOldMissingFieldRoundTripDifferently() throws {
        let container = try memory(); let context = container.mainContext
        let cook = try create(context, description: "Something")
        try CookingStore.editCookDescription(cook, publicDescription: "", context: context)
        let graph = try CookingGraphExport.snapshot(context: context)
        let encoded = try JSONEncoder().encode(#require(graph.attempts.first))
        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(json["publicDescription"] as? String == "")
        json.removeValue(forKey: "publicDescription")
        let legacy = try JSONDecoder().decode(AttemptTransfer.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(legacy.publicDescription == nil)
        #expect(cook.dish?.publicDescription == nil && cook.notes == "Private cook detail")
    }
    @Test func hydrationAndDiskRelaunchPreserveTheCanonicalCookField() throws {
        let container = try memory(); let context = container.mainContext
        let cook = try create(context, description: "Restored on another device")
        let id = cook.id, graph = try CookingGraphExport.snapshot(context: context)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        do {
            let device = try LocalStoreSession.open(.guest, root: root)
            try CookingGraphHydration.apply(graph, revision: 1, context: device.container.mainContext)
            let restored = try #require(device.container.mainContext.fetch(FetchDescriptor<CookingAttempt>()).first(where: { $0.id == id }))
            #expect(restored.publicDescription == "Restored on another device" && restored.notes == "Private cook detail")
        }
        let reopened = try LocalStoreSession.open(.guest, root: root)
        let restored = try #require(reopened.container.mainContext.fetch(FetchDescriptor<CookingAttempt>()).first(where: { $0.id == id }))
        #expect(CookingDraft(attempt: restored).publicDescription == "Restored on another device")
    }
    @Test func exactPostLinkWorksAfterRenameAndDishFanoutMakesNoRequests() async throws {
        let container = try memory(); let context = container.mainContext
        let cook = try create(context, description: "Cook text"); cook.dish?.name = "Renamed soup"; try context.save()
        var post = SocialPost(id: UUID(), author: .init(id: UUID(), displayName: "Me", username: "me", relationship: .none), title: "Old name", versionTitle: nil, scoreText: nil, achievement: nil, createdAt: 1, photoPath: nil, published: true, isAuthor: true, moderationState: "active")
        post.sourceAttemptID = cook.id
        #expect(try PublicDescriptionSync.attempt(owning: post, in: context)?.id == cook.id)
        var calls = 0
        let dish = try #require(cook.dish)
        let result = await PublicDescriptionSync.pushToPosts(of: dish, request: { _,_,_ in calls += 1; return Data() })
        #expect(calls == 0 && result.updated == 0)
    }
    @Test func syncRequiresDurabilitySupportOnlyWhenTheNewFieldIsPresent() throws {
        func payload(_ record: [String: Any]) throws -> Data {
            let entry = SyncRecord(reference: .init(entity: .attempt, key: UUID().uuidString), data: try JSONSerialization.data(withJSONObject: record))
            return try JSONEncoder().encode(SyncChanges(upserts: [entry], deletions: []))
        }
        #expect(!(try CookDescriptionSyncSupport.requiresSupport(payload(["notes": "Legacy private note"]))))
        #expect(!(try CookDescriptionSyncSupport.requiresSupport(payload(["publicDescription": NSNull()]))))
        #expect(try CookDescriptionSyncSupport.requiresSupport(payload(["publicDescription": ""])))
        #expect(try CookDescriptionSyncSupport.requiresSupport(payload(["publicDescription": "Public cook"])))
        let receipt = Data("{\"format_version\":1,\"auth_user_id\":\"\(UUID())\",\"account_id\":\"\(UUID())\",\"sync_revision\":0,\"library_state\":\"initialized\"}".utf8)
        #expect(try JSONDecoder().decode(ProvisionedAccount.self, from: receipt).cookDescriptionVersion == nil)
        var json = try #require(JSONSerialization.jsonObject(with: receipt) as? [String: Any]); json["cook_description_version"] = 1
        #expect(try JSONDecoder().decode(ProvisionedAccount.self, from: JSONSerialization.data(withJSONObject: json)).cookDescriptionVersion == 1)
    }
    @Test func technicalBoundsPreserveParagraphsWithoutAcceptingCorruptControls() {
        #expect(CookDescriptionPolicy.valid("A paragraph\n\tAnother line"))
        #expect(!CookDescriptionPolicy.valid("Bad\u{0001}text"))
        #expect(!CookDescriptionPolicy.valid(String(repeating: "a", count: 2_001)))
        #expect(CookDescriptionPolicy.valid(nil) && CookDescriptionPolicy.normalized("  ") == "")
    }
}
