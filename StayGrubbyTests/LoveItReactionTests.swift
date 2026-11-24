import Foundation
import SwiftData
import Testing
@testable import StayGrubby

/// Love It, the fourth first-impression reaction (owner, November 24, 2026). Simulated, in-memory data only.
@MainActor struct LoveItReactionTests {
    struct Fixture { let container: ModelContainer; let context: ModelContext; let list: RankingList; let cooks: [CookingAttempt] }

    /// Builds `count` cooks ranked top-to-bottom in creation order (each new cook loses every comparison).
    func fixture(_ reactions: [InitialReaction]) throws -> Fixture {
        let container = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext, list = try CookingStore.prepare(context: context)
        var cooks: [CookingAttempt] = []
        for (n, reaction) in reactions.enumerated() {
            var draft = CookingDraft(); draft.dishName = "Simulated \(n)"
            var session = RankingEngine(itemID: UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: reaction)
            while session.nextOpponent != nil { session.answer(.existingItem) }
            cooks.append(try CookingStore.create(draft: draft, session: session, context: context))
        }
        return Fixture(container: container, context: context, list: list, cooks: cooks)
    }

    /// The reader in builds up to 1.0 (9): three reactions, latest then initial, version ignored.
    private func olderBuildReaction(_ data: Data?) -> String? {
        guard let data, let record = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        let known = ["Liked it", "It was fine", "Didn't like it"]
        return [record["latestSemanticReaction"], record["initialReaction"]].compactMap { $0 as? String }.first { known.contains($0) }
    }
    /// What an older build's completed re-rank writes (ScoreCalibration version 1): unknown keys preserved.
    private func olderBuildRerank(_ reaction: String, in data: Data?) throws -> Data {
        let bytes = try #require(data)
        var fields = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        fields["latestSemanticReaction"] = reaction; fields["scoreCalibrationVersion"] = 1
        return try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
    }

    @Test func fourReactionsInDisplayOrderWithLoveItFirst() {
        #expect(InitialReaction.allCases == [.loved, .liked, .fine, .disliked])
        #expect(InitialReaction.allCases.map(\.rawValue) == ["Loved it", "Liked it", "It was fine", "Didn't like it"])
        #expect(InitialReaction.loved.percentile < InitialReaction.liked.percentile)
        #expect(InitialReaction.allCases.map(\.compatibilityValue) == ["Liked it", "Liked it", "It was fine", "Didn't like it"])
    }

    @Test func loveItBandSitsAboveLikedWithOverlapAndExistingBandsUnchanged() {
        let sigmoid = { (x: Double) in 1 / (1 + exp(-x)) }
        for s in stride(from: -12.0, through: 12, by: 0.25) {
            let loved = ScoreCalibration.score(strength: s, reaction: .loved)
            #expect(loved >= 7 && loved <= 10)
            #expect(loved > ScoreCalibration.score(strength: s, reaction: .liked)) // Same strength: Love It reads higher.
            // Version 1 formulas, byte-for-byte: no existing reaction's score moves.
            #expect(abs(ScoreCalibration.score(strength: s, reaction: .liked) - (7 + 3 * sigmoid(s / 1.6 - 0.4))) < 1e-12)
            #expect(abs(ScoreCalibration.score(strength: s, reaction: nil) - (1 + 9 * sigmoid(s / 2))) < 1e-12)
        }
        // Reference values (strength −4, −2, 0, 2, 4).
        let values = [-4.0, -2, 0, 2, 4].map { String(format: "%.1f", ScoreCalibration.score(strength: $0, reaction: .loved)) }
        #expect(values == ["7.3", "7.9", "8.8", "9.5", "9.8"])
        // Full overlap: a beaten Love It cook can score below a Liked cook that won its comparisons.
        #expect(ScoreCalibration.score(strength: -3, reaction: .loved) < ScoreCalibration.score(strength: 2, reaction: .liked))
    }

    @Test func loveItStartsHigherButComparisonsDecide() throws {
        let f = try fixture(Array(repeating: .fine, count: 20)); defer { withExtendedLifetime(f) {} }
        let order = f.list.orderedItems.map(\.id)
        let loved = RankingEngine(itemID: UUID(), orderedIDs: order, reaction: .loved)
        let liked = RankingEngine(itemID: UUID(), orderedIDs: order, reaction: .liked)
        let disliked = RankingEngine(itemID: UUID(), orderedIDs: order, reaction: .disliked)
        let start = { (s: RankingEngine) in order.firstIndex(of: try #require(s.nextOpponent))! }
        #expect(try start(loved) < start(liked) && start(liked) < start(disliked))
        // Love It, then losing every comparison: it ends last, below every Liked/Fine cook.
        var draft = CookingDraft(); draft.dishName = "Loved but beaten"
        var session = loved
        while session.nextOpponent != nil { session.answer(.existingItem) }
        #expect(!session.evidence.isEmpty)
        let cook = try CookingStore.create(draft: draft, session: session, context: f.context)
        #expect(f.list.orderedItems.last?.id == cook.rankedItemID)
        #expect(ScoreCalibration.reaction(in: cook.rankedItem?.sessionDiagnosticsData) == .loved)
        // The reaction never enters Bradley–Terry: strengths equal a refit of the evidence alone.
        let refit = BradleyTerryModel.analyze(ids: f.list.items.map(\.id), evidence: f.list.comparisons.map(\.evidence))
        #expect(f.list.items.allSatisfy { abs($0.strength - refit.estimates[$0.id]!.strength) < 1e-12 })
    }

    @Test func loveItCookCanRankBelowALikedCook() throws {
        let f = try fixture([.liked, .loved]); defer { withExtendedLifetime(f) {} }
        // The Love It cook lost its comparison to the Liked cook, so it ranks second.
        #expect(f.list.orderedItems.map(\.id) == f.cooks.map(\.rankedItemID))
        #expect(ScoreCalibration.reaction(in: f.cooks[1].rankedItem?.sessionDiagnosticsData) == .loved)
        #expect(f.cooks[1].rankedItem!.strength < f.cooks[0].rankedItem!.strength)
    }

    @Test(arguments: InitialReaction.allCases)
    func reRankingToAndFromEveryReactionKeepsEvidenceAndIdentity(_ reaction: InitialReaction) throws {
        let f = try fixture([.loved, .liked, .fine, .disliked, .liked, .fine]); defer { withExtendedLifetime(f) {} }
        let cook = f.cooks[0], item = try #require(cook.rankedItem)
        let comparisons = Dictionary(uniqueKeysWithValues: f.list.comparisons.map { ($0.id, $0.evidence) })
        let ids = (cook.id, item.id)
        let workflow = CookingReRankingWorkflow(attempt: cook); try workflow.choose(reaction, context: f.context)
        while workflow.session?.nextOpponent != nil { workflow.answer(.tooTough) }
        try workflow.finish(context: f.context)
        #expect(ScoreCalibration.reaction(in: item.sessionDiagnosticsData) == reaction)
        #expect((cook.id, item.id) == ids)
        for (id, evidence) in comparisons { #expect(f.list.comparisons.first { $0.id == id }?.evidence == evidence) }
        let bytes = try #require(item.sessionDiagnosticsData)
        let fields = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        #expect(fields["semanticReaction"] as? String == reaction.rawValue)
        #expect(fields["latestSemanticReaction"] as? String == reaction.compatibilityValue)
        #expect(fields["initialSemanticReaction"] as? String == "Loved it")
        #expect(fields["initialReaction"] as? String == "Liked it")
        #expect(fields["scoreCalibrationVersion"] as? Int == 2)
        struct History: Decodable { let completedReactions: [CompletedRankingReaction] }
        let history = try JSONDecoder().decode(History.self, from: try #require(item.sessionDiagnosticsData)).completedReactions
        #expect(history.map(\.reaction) == [.loved, reaction])
        // Stored history keeps the three original values for older builds.
        let raw = try #require((fields["completedReactions"] as? [[String: Any]])?.compactMap { $0["reaction"] as? String })
        #expect(raw == ["Liked it", reaction.compatibilityValue])
    }

    @Test func olderBuildsReadLoveItAsLikedAndTheirLaterReRankWins() throws {
        let f = try fixture([.liked, .loved]); defer { withExtendedLifetime(f) {} }
        let item = try #require(f.cooks[1].rankedItem)
        // An older build sees Liked it (its nearest band), never the legacy 1–10 fallback or a decode failure.
        #expect(olderBuildReaction(item.sessionDiagnosticsData) == "Liked it")
        struct OldHistory: Decodable { struct Entry: Decodable { enum R: String, Decodable { case liked = "Liked it", fine = "It was fine", disliked = "Didn't like it" }; let reaction: R }; let completedReactions: [Entry] }
        #expect(try JSONDecoder().decode(OldHistory.self, from: try #require(item.sessionDiagnosticsData)).completedReactions.map(\.reaction) == [.liked])
        // New build re-ranks to Love It, then an older build re-ranks to Didn't like it: the older, later choice wins.
        let workflow = CookingReRankingWorkflow(attempt: f.cooks[1]); try workflow.choose(.loved, context: f.context)
        while workflow.session?.nextOpponent != nil { workflow.answer(.tooTough) }
        try workflow.finish(context: f.context)
        #expect(ScoreCalibration.reaction(in: item.sessionDiagnosticsData) == .loved)
        let afterOld = try olderBuildRerank("Didn't like it", in: item.sessionDiagnosticsData)
        #expect(ScoreCalibration.reaction(in: afterOld) == .disliked)
        // And a later new-build re-rank takes over again.
        let again = try ScoreCalibration.recording(.loved, in: afterOld)
        #expect(ScoreCalibration.reaction(in: again) == .loved)
    }

    @Test func historicalVersionOneRecordsKeepTheirExactScores() throws {
        let records = [#"{"initialReaction":"Liked it"}"#, #"{"initialReaction":"It was fine","latestSemanticReaction":"Didn't like it","scoreCalibrationVersion":1}"#,
                       #"{"initialReaction":"Didn't like it","latestSemanticReaction":"Liked it","scoreCalibrationVersion":1,"futureField":7}"#, "legacy"]
        let expected: [InitialReaction?] = [.liked, .disliked, .liked, nil]
        for (record, reaction) in zip(records, expected) {
            let data = Data(record.utf8)
            #expect(ScoreCalibration.reaction(in: data) == reaction)
            for s in [-4.0, 0, 3] { #expect(ScoreCalibration.score(strength: s, metadata: data) == ScoreCalibration.score(strength: s, reaction: reaction)) }
        }
    }

    @Test func loveItSurvivesSyncRestoreOnAnotherDevice() throws {
        let f = try fixture([.liked, .fine, .loved, .disliked]); defer { withExtendedLifetime(f) {} }
        let lovedID = f.cooks[2].id, score = try #require(f.cooks[2].rankedItem).score
        var graph = try CookingGraphExport.snapshot(context: f.context); let owner = UUID(); graph.accountID = owner
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("love-it-restore-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let device = try LocalStoreStartup.openAccount(owner, root: root); try device.restore(graph, revision: 1)
        let restored = try #require(device.container.mainContext.fetch(FetchDescriptor<CookingAttempt>()).first { $0.id == lovedID })
        #expect(ScoreCalibration.reaction(in: restored.rankedItem?.sessionDiagnosticsData) == .loved)
        #expect(restored.rankedItem?.score == score)
        #expect(try CookingGraphExport.snapshot(context: device.container.mainContext).items.map(\.sessionDiagnosticsData).sorted { ($0?.count ?? 0) < ($1?.count ?? 0) }
                == graph.items.map(\.sessionDiagnosticsData).sorted { ($0?.count ?? 0) < ($1?.count ?? 0) })
    }

    @Test func grubRankTheShareCardAndThePassUseTheSameScore() throws {
        let f = try fixture([.liked, .fine, .loved, .disliked, .liked, .fine, .liked, .disliked, .fine, .liked]); defer { withExtendedLifetime(f) {} }
        let cook = f.cooks[2], item = try #require(cook.rankedItem)
        #expect(ScoreUnlockPolicy.state(in: f.context).rankedEntryCount == 10)
        let shown = String(format: "%.1f", item.score)
        #expect(ShareCardModel.make(for: cook).scoreText == shown)
        #expect(item.score >= 7)
    }
}
