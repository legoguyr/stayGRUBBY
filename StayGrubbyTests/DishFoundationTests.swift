import Foundation
import SwiftData
import Testing
import UIKit
@testable import StayGrubby

@MainActor struct DishFoundationTests {
    private func fixture() throws -> (ModelContainer, CookingAttempt, URL) {
        let container = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        _ = try CookingStore.prepare(context: context)
        var draft = CookingDraft(); draft.dishName = "Stage 1 fixture"; draft.notes = "Original private cook notes"
        let cook = try CookingStore.create(draft: draft, session: RankingEngine(itemID: UUID(), orderedIDs: [], reaction: .liked), context: context)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (container, cook, root)
    }
    private func photo() throws -> PreparedCookingPhoto {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 160)).pngData { c in
            UIColor.orange.setFill(); c.fill(CGRect(x: 0, y: 0, width: 240, height: 160))
        }
        return try LocalPhotoStore.prepare(data: image)
    }
    @Test func dishTextIsSeparateFromCookNotesAndRankingAndNullRoundTrips() throws {
        let (container, cook, root) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let context = container.mainContext, dish = try #require(cook.dish)
        let before = try CookingGraphExport.snapshot(context: context)
        #expect(dish.publicDescription == nil && dish.privateNotes == nil)
        try CookingStore.editDishText(dish, publicDescription: "Public lemon dish", privateNotes: "Private technique notes", context: context)
        let graph = try CookingGraphExport.snapshot(context: context)
        #expect(graph.items == before.items && graph.comparisons == before.comparisons && graph.attempts == before.attempts)
        #expect(cook.notes == "Original private cook notes")
        #expect(try CookingGraph.decode(graph.encoded()) == graph)
        let row = try #require(graph.dishes.first)
        var old = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(row)) as? [String: Any])
        old.removeValue(forKey: "publicDescription"); old.removeValue(forKey: "privateNotes")
        let legacy = try JSONDecoder().decode(DishTransfer.self, from: JSONSerialization.data(withJSONObject: old))
        #expect(legacy.publicDescription == nil && legacy.privateNotes == nil)
        try CookingStore.editDishText(dish, publicDescription: "", privateNotes: "", context: context)
        let cleared = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(DishTransfer(dish))) as? [String: Any])
        #expect(cleared["publicDescription"] is NSNull && cleared["privateNotes"] is NSNull)
    }
    @Test func textBoundsRejectInsteadOfTruncatingOrPublishingLegacyNotes() throws {
        let (container, cook, root) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let dish = try #require(cook.dish)
        #expect(throws: (any Error).self) { try CookingStore.editDishText(dish, publicDescription: String(repeating: "a", count: 2001), privateNotes: "", context: container.mainContext) }
        #expect(dish.publicDescription == nil && dish.privateNotes == nil && cook.notes == "Original private cook notes")
        #expect(DishTextPolicy.valid(description: String(repeating: "a", count: 2000), notes: String(repeating: "b", count: 8000)))
        #expect(!DishTextPolicy.valid(description: nil, notes: String(repeating: "b", count: 8001)))
        #expect(!DishTextPolicy.valid(description: "invalid\0text", notes: nil))
    }
    @Test func sixPhotoCollectionHasStableCoverOrderingAndIndividualRemoval() throws {
        let (container, cook, root) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let context = container.mainContext, prepared = try photo()
        let before = try CookingGraphExport.snapshot(context: context)
        var ids: [UUID] = []
        for _ in 0..<6 { ids.append(try CookingPhotoCollection.append(try photo(), to: cook, context: context, root: root).id) }
        #expect(cook.orderedImages.map(\.id) == ids && cook.primaryImage?.id == ids.first)
        #expect(throws: CookingPhotoCollection.PhotoError.limit) { try CookingPhotoCollection.append(prepared, to: cook, context: context, root: root) }
        let last = try #require(cook.orderedImages.last)
        try CookingPhotoCollection.setCover(last, in: cook, context: context)
        #expect(cook.primaryImage?.id == last.id)
        let selected = try #require(cook.orderedImages.last)
        let survivor = try #require(cook.primaryImage)
        let survivorData = try CookingPhotoFiles.read(media: MediaTransfer(survivor), thumbnail: false, root: root)
        try CookingPhotoCollection.remove(selected, from: cook, context: context, root: root)
        #expect(cook.media.count == 5 && cook.primaryImage?.id == survivor.id)
        #expect(try CookingPhotoFiles.read(media: MediaTransfer(survivor), thumbnail: false, root: root) == survivorData)
        #expect(throws: CookingPhotoCollection.PhotoError.invalidOrder) { try CookingPhotoCollection.reorder([UUID()], in: cook, context: context) }
        let after = try CookingGraphExport.snapshot(context: context)
        #expect(after.items == before.items && after.comparisons == before.comparisons)
        try after.validate()
    }
    @Test func legacyCoverEditPreservesSecondaryPhotosAndTieOrderIsDeterministic() throws {
        let (container, cook, root) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let context = container.mainContext, prepared = try photo()
        let first = try CookingPhotoCollection.append(prepared, to: cook, context: context, root: root)
        let firstID = first.id
        #expect(throws: (any Error).self) { try CookingPhotoCollection.append(prepared, to: cook, context: context, root: root) }
        let second = try CookingPhotoCollection.append(photo(), to: cook, context: context, root: root)
        var draft = CookingDraft(attempt: cook); draft.pendingPhoto = try photo()
        try CookingStore.edit(cook, draft: draft, context: context, mediaDirectory: root)
        #expect(cook.media.count == 2 && !cook.media.contains { $0.id == firstID } && cook.media.contains { $0.id == second.id })
        draft = CookingDraft(attempt: cook); draft.removeExistingPhoto = true
        try CookingStore.edit(cook, draft: draft, context: context, mediaDirectory: root)
        #expect(cook.media.count == 1 && cook.primaryImage?.id == second.id)
        let third = try CookingPhotoCollection.append(photo(), to: cook, context: context, root: root)
        second.sortOrder = 0; third.sortOrder = 0; third.createdAt = second.createdAt
        #expect(cook.primaryImage?.id.uuidString == [second.id.uuidString, third.id.uuidString].sorted().first)
        #expect(cook.dish?.photoVersions.first?.id == cook.id)
    }
    @Test func legacyQueuedChangesDecodeAndNewOperationsAdvertiseCollectionSupport() throws {
        let old = try JSONDecoder().decode(SyncChanges.self, from: Data(#"{"upserts":[],"deletions":[]}"#.utf8))
        #expect(old.photoCollectionVersion == nil)
        let next = SyncChanges(upserts: [], deletions: [])
        #expect(next.photoCollectionVersion == 1)
        #expect(try JSONDecoder().decode(SyncChanges.self, from: JSONEncoder().encode(next)) == next)
    }
}
