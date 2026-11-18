import Foundation
import SwiftData
import Testing
@testable import StayGrubby

/// Dish/Recipe integrity and Smart Collections (November 18, 2026).
@MainActor struct DishOrganizationTests {
    @MainActor private final class Store {
        let container: ModelContainer
        var context: ModelContext { container.mainContext }
        let list: RankingList
        init() throws {
            container = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
            _ = try CookingStore.prepare(context: container.mainContext)
            list = try CookingStore.globalRanking(context: container.mainContext)
            // A bound store records sync operations, so tests can see which edits would upload.
            let binding = SyncStoreBinding(accountID: UUID(), restorationRequired: false); binding.enabled = true
            container.mainContext.insert(binding)
            try container.mainContext.save()
        }
        /// Adds a cook (new Dish unless `dish`), ranked above everything so far.
        @discardableResult
        func cook(_ name: String, in dish: Dish? = nil, title: String = "") throws -> CookingAttempt {
            var draft = dish.map(CookingDraft.init(dish:)) ?? CookingDraft()
            draft.dishName = dish?.name ?? name; draft.versionTitle = title
            var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: .liked)
            while session.nextOpponent != nil { session.answer(.newItem) }
            return try CookingStore.create(draft: draft, existingDish: dish, session: session, context: context)
        }
        func operations() throws -> Int { try context.fetchCount(FetchDescriptor<SyncOperation>()) }
        func dishes() throws -> [Dish] { try context.fetch(FetchDescriptor<Dish>()) }
    }

    @Test func similarlyNamedDishesStayIndependentAndCollectionsOnlyOrganize() throws {
        let s = try Store()
        let saffron = try #require(try s.cook("Saffron Risotto").dish)
        let mushroom = try #require(try s.cook("Mushroom Risotto").dish)
        try s.cook("Mushroom Risotto", in: mushroom, title: "Porcini")
        let butternut = try #require(try s.cook("Butternut Squash Risotto").dish)
        #expect(Set(try s.dishes().map(\.id)).count == 3, "Shared words never merge Dishes")

        try DishCollectionStore.set(["Risotto", "Comfort Food"], on: butternut, context: s.context)
        try DishCollectionStore.set(["risotto"], on: mushroom, context: s.context)
        try DishCollectionStore.set([" Risotto "], on: saffron, context: s.context)
        #expect(saffron.collections == ["Risotto"] && mushroom.collections == ["risotto"])

        // Browsing derives everything and writes nothing.
        let before = try s.operations(), dishCount = try s.dishes().count
        let summaries = DishCollectionSummary.all(dishes: try s.dishes(), entries: ScoreUnlockPolicy.entries(in: s.context), scores: ScoreUnlockPolicy.state(in: s.context))
        #expect(summaries.map(\.label) == ["Comfort Food", "Risotto"], "One Dish appears in two collections")
        let risotto = try #require(summaries.last)
        #expect(risotto.members.map(\.dish.id) == [butternut.id, mushroom.id, saffron.id], "Ordered by each Dish's best Grub Rank cook")
        #expect(risotto.members.count == 3 && risotto.cookCount == 4)
        #expect(risotto.members.allSatisfy { $0.scoreText == nil }, "Locked scores stay locked; none are invented")
        let operationsAfter = try s.operations(), dishesAfter = try s.dishes().count
        #expect(operationsAfter == before && dishesAfter == dishCount && !s.context.hasChanges)

        // An unchanged save writes nothing; rename and delete touch only labels.
        try DishCollectionStore.set(["Risotto", "Comfort Food"], on: butternut, context: s.context)
        #expect(try s.operations() == before)
        let ids = try s.dishes().map(\.id).sorted { $0.uuidString < $1.uuidString }
        try DishCollectionStore.rename("RISOTTO", to: "Risottos", dishes: try s.dishes(), context: s.context)
        #expect([butternut, mushroom, saffron].allSatisfy { $0.collections.contains("Risottos") && !$0.collections.contains("Risotto") })
        #expect(try s.operations() == before + 1, "A rename is one synced edit")
        try DishCollectionStore.remove("Risottos", dishes: try s.dishes(), context: s.context)
        #expect(butternut.collections == ["Comfort Food"] && mushroom.collections.isEmpty && saffron.collections.isEmpty)
        #expect(try s.dishes().map(\.id).sorted { $0.uuidString < $1.uuidString } == ids && mushroom.attempts.count == 2)
    }

    @Test func separatingACookIsLosslessAndRankingNeutral() throws {
        // The owner's real case: three different risottos logged as cooks of one "Risotto" Dish.
        let s = try Store()
        let butternut = try s.cook("Risotto", title: "Butternut Squash")
        let risotto = try #require(butternut.dish)
        let mushroom = try s.cook("Risotto", in: risotto, title: "Mushroom")
        try s.cook("Risotto", in: risotto, title: "Pea and mahi mahi")
        try CookingStore.editDishText(risotto, publicDescription: "Creamy rice", privateNotes: "Stir constantly", context: s.context)
        risotto.cuisine = Cuisine(id: "italian", label: "Italian")
        let order = s.list.orderedItems.map(\.id)
        let comparisons = try s.context.fetchCount(FetchDescriptor<Comparison>())
        let (cookID, itemID) = (mushroom.id, mushroom.rankedItemID)

        let separate = try DishIdentityStore.move(mushroom, toNewDishNamed: "Mushroom Risotto", collections: ["Risotto"], context: s.context)
        #expect(mushroom.id == cookID && mushroom.rankedItemID == itemID && mushroom.dish?.id == separate.id)
        let comparisonsAfter = try s.context.fetchCount(FetchDescriptor<Comparison>())
        #expect(s.list.orderedItems.map(\.id) == order && comparisonsAfter == comparisons, "Ranking evidence and order unchanged")
        #expect(separate.name == "Mushroom Risotto" && separate.cuisine?.id == "italian" && separate.collections == ["Risotto"])
        #expect(separate.publicDescription == nil && separate.privateNotes == nil, "Dish text stays with the original Dish")
        #expect(risotto.attempts.count == 2 && risotto.publicDescription == "Creamy rice" && mushroom.sequenceNumber == 1)
        #expect(mushroom.rankedItem?.name == "Mushroom Risotto — Mushroom")
        #expect(try SyncJournal.pending(s.context).last?.kind == "moveCook")

        // Joining an existing Dish is explicit too; the original Dish always keeps a cook.
        let pea = try #require(risotto.attempts.first { $0.versionTitle == "Pea and mahi mahi" })
        try DishIdentityStore.move(pea, destination: separate, context: s.context)
        #expect(separate.attempts.count == 2 && risotto.attempts.map(\.id) == [butternut.id])
        #expect(throws: (any Error).self) { try DishIdentityStore.move(butternut, toNewDishNamed: "Other", context: s.context) }
        #expect(throws: (any Error).self) { try DishIdentityStore.move(pea, toNewDishNamed: "   ", context: s.context) }
    }

    @Test func emptyAndMissingCollectionsAreTheSameSyncState() throws {
        let s = try Store()
        let dish = try #require(try s.cook("Saffron Risotto").dish)
        let row = DishTransfer(dish)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(row)) as? [String: Any])
        #expect((json["collections"] as? [String]) == [], "Always sent, so clearing the last collection syncs")
        json.removeValue(forKey: "collections")
        #expect(try JSONDecoder().decode(DishTransfer.self, from: JSONSerialization.data(withJSONObject: json)) == row, "An older server's row equals an empty Dish")
        json["collections"] = NSNull()
        #expect(try JSONDecoder().decode(DishTransfer.self, from: JSONSerialization.data(withJSONObject: json)) == row)
        json["collections"] = ["Risotto"]
        #expect(try JSONDecoder().decode(DishTransfer.self, from: JSONSerialization.data(withJSONObject: json)).collections == ["Risotto"])
    }

    @Test func collectionLabelsAreBoundedAndDeduplicated() {
        #expect(DishCollectionPolicy.normalized(["  Risotto ", "risotto", "Rísotto", "", "Comfort  Food"]) == ["Risotto", "Comfort Food"])
        #expect(DishCollectionPolicy.normalized(Array(repeating: "x", count: 1) + (0..<30).map { "C\($0)" }).count == DishCollectionPolicy.maximumPerDish)
        #expect(DishCollectionPolicy.normalized([String(repeating: "a", count: 60)]).first?.count == DishCollectionPolicy.maximumLength)
        #expect(!DishCollectionPolicy.valid(["Risotto", "risotto"]) && DishCollectionPolicy.valid([]))
        #expect(!FeatureFlags.off.isOn(.dishCollections), "Smart Collections stay off until the server migration is live")
    }
}
