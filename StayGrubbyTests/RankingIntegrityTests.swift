import Foundation
import SwiftData
import Testing
@testable import StayGrubby

@MainActor struct RankingIntegrityTests {
    func id(_ n: Int) -> UUID { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n + 1))! }
    func context(_ count: Int = 15, repeats: Int) throws -> RankingContext {
        var observations: [RankingObservation] = []
        for a in 0..<count { for b in (a + 1)..<count { for _ in 0..<repeats {
            observations.append(.init(id: id(10_000 + observations.count), evidence: .init(first: id(a), second: id(b), outcome: 1, timestamp: Date(timeIntervalSince1970: 1))))
        } } }
        return try .init(currentIDs: (0..<count).map(id), observations: observations)
    }
    func position(_ target: UUID, in analysis: RankingAnalysis) -> Int {
        analysis.ids.sorted {
            let a = (analysis.estimates[$0]!.strength * 1e7).rounded(), b = (analysis.estimates[$1]!.strength * 1e7).rounded()
            return a == b ? $0.uuidString < $1.uuidString : a > b
        }.firstIndex(of: target)! + 1
    }
    func complete(_ engine: inout RankingEngine, answer: (UUID, Int) -> ComparisonAnswer) throws {
        var steps = 0
        let limit = max(80, engine.orderedIDs.count + 16)
        while let opponent = engine.nextOpponent {
            #expect(steps < limit, "Session must finish without a long corrective questionnaire")
            guard steps < limit else { throw RankingContext.InvalidHistory() }
            engine.answer(answer(opponent, steps), at: Date(timeIntervalSince1970: Double(2_000 + steps)))
            steps += 1
        }
        #expect(engine.stopReason != nil)
    }

    @Test(arguments: [1, 3, 8]) func denseHistoryDoesNotOverwhelmExplicitReassessment(repeats: Int) throws {
        let baseline = try context(repeats: repeats)
        let original = baseline.analyze()
        #expect(position(id(3), in: original) == 4)
        // Reproduces the old acquisition/commit mismatch without changing the fitter.
        var old = RankingEngine(itemID: id(3), orderedIDs: baseline.currentIDs.filter { $0 != id(3) }, reaction: .disliked)
        try complete(&old) { _, _ in .existingItem }
        #expect(old.evidence.count == 4)
        let oldPosition = position(id(3), in: baseline.analyze(adding: old.evidence))
        #expect(oldPosition <= 7)

        for (index, reaction, answer, expected) in [(3, InitialReaction.disliked, ComparisonAnswer.existingItem, 15), (13, .liked, .newItem, 1)] {
            let target = id(index), epoch = try #require(baseline.reassessment(of: target))
            let fresh = try baseline.adding(epoch, for: target)
            var session = RankingEngine(itemID: target, orderedIDs: baseline.currentIDs.filter { $0 != target }, reaction: reaction, context: fresh)
            try complete(&session) { _, _ in answer }
            let fit = fresh.analyze(adding: session.evidence)
            #expect(fit.diagnostics.converged && fit.diagnostics.ignoredEvidenceCount == 0)
            #expect(position(target, in: fit) == expected)
            #expect(session.evidence.count <= 9)
            #expect(Set(fit.ids) == Set(baseline.currentIDs)) // Historical parameters are not entries.
            #expect(fresh.observations.map(\.evidence) == baseline.observations.map(\.evidence))
            print("integrity history=\(baseline.observations.count) oldDown=\(oldPosition) new=\(expected) questions=\(session.evidence.count)")
        }
    }

    @Test(arguments: [15, 40, 100], [0, 1, 2, 3, 4, 5])
    func initialRankingUsesTheSameGlobalModel(count: Int, scenario: Int) throws {
        let baseline = try context(count, repeats: 2), target = id(1_000)
        var session = RankingEngine(itemID: target, orderedIDs: baseline.currentIDs, reaction: scenario == 0 ? .liked : scenario == 1 ? .disliked : .fine, context: baseline)
        let first = session.nextOpponent
        session.answer(.skip); session.undo(); #expect(session.nextOpponent == first && session.evidence.isEmpty)
        session.answer(.tooTough); session.undo(); #expect(session.nextOpponent == first && session.evidence.isEmpty)
        try complete(&session) { opponent, n in
            switch scenario {
            case 0: return .newItem
            case 1: return .existingItem
            case 2: return baseline.currentIDs.firstIndex(of: opponent)! >= count / 2 ? .newItem : .existingItem
            case 3: return n.isMultiple(of: 2) ? .newItem : .existingItem
            case 4: return .tooTough
            default: return .skip
            }
        }
        let fit = baseline.analyze(adding: session.evidence, newItem: target)
        #expect(fit.diagnostics.converged && fit.diagnostics.ignoredEvidenceCount == 0)
        if scenario == 0 { #expect(position(target, in: fit) == 1) }
        if scenario == 1 { #expect(position(target, in: fit) == count + 1) }
        if scenario == 2 { #expect(abs(position(target, in: fit) - (count / 2 + 1)) <= 2) }
        if scenario == 5 { #expect(session.evidence.isEmpty && (session.stopReason == .opponentsExhausted || session.stopReason == .lowInformation)) }
        #expect(session.evidence.allSatisfy { $0.first == target && baseline.currentIDs.contains($0.second) })
    }

    @Test func persistedSecondVersionReassessmentRestoreAndDeletionKeepEvidenceAndIdentity() throws {
        let base = try context(repeats: 3)
        let container = try ModelContainer(for: AppPersistence.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext, list = try CookingStore.prepare(context: context)
        let dish = Dish(name: "Independent versions", category: .main); context.insert(dish)
        for n in 0..<15 {
            let item = RankedItem(id: id(n), name: "Fixture \(n)")
            item.createdAt = Date(timeIntervalSince1970: Double(n))
            context.insert(item); list.items.append(item)
            let cook = CookingAttempt(item: item, sequence: n + 1, category: .main, cookedAt: .now)
            context.insert(cook); dish.attempts.append(cook)
        }
        for e in base.observations { let comparison = Comparison(evidence: e.evidence, id: e.id); context.insert(comparison); list.comparisons.append(comparison) }
        try list.recompute(); try context.save()
        let cook = try #require(dish.attempts.first { $0.rankedItemID == id(3) })
        let ids = Set(list.items.map(\.id)), originals = Dictionary(uniqueKeysWithValues: list.comparisons.map { ($0.id, $0.evidence) })
        let workflow = CookingReRankingWorkflow(attempt: cook); try workflow.choose(.disliked, context: context)
        var n = 0
        while workflow.session?.nextOpponent != nil { workflow.answer(.existingItem); n += 1; if n > 80 { throw RankingContext.InvalidHistory() } }
        try workflow.finish(context: context)
        #expect(list.orderedItems.last?.id == cook.rankedItemID)
        #expect(Set(list.items.map(\.id)) == ids && dish.attempts.count == 15)
        for (id, evidence) in originals { #expect(list.comparisons.first { $0.id == id }?.evidence == evidence) }
        let fit = try list.rankingContext().analyze()
        for item in list.items { #expect(abs(item.strength - fit.estimates[item.id]!.strength) < 1e-12) }
        #expect(cook.rankedItem!.score == ScoreCalibration.score(strength: cook.rankedItem!.strength, reaction: .disliked))
        #expect(RankingCompletionSnapshot.capture(from: list).eligibleRankedEntryCount == 15)
        #expect(ScoreUnlockPolicy.entries(in: context, list: list).first { $0.attempt.id == cook.id }?.globalRank == 15)
        let owner = UUID(), root = FileManager.default.temporaryDirectory.appendingPathComponent("integrity-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        var graph = try CookingGraphExport.snapshot(context: context); graph.accountID = owner
        do { let store = try LocalStoreStartup.openAccount(owner, root: root); try store.restore(graph, revision: 1) }
        let reopened = try LocalStoreStartup.openAccount(owner, root: root), restored = reopened.container.mainContext
        #expect(try CookingGraphExport.snapshot(context: restored) == graph.canonicalized())
        let restoredList = try #require(restored.fetch(FetchDescriptor<RankingList>()).first)
        try restoredList.recompute()
        #expect(restoredList.orderedItems.map(\.id) == list.orderedItems.map(\.id))
        let restoredCook = try #require(restored.fetch(FetchDescriptor<CookingAttempt>()).first { $0.id == cook.id })
        try CookingStore.delete(restoredCook, context: restored)
        #expect(restoredList.items.count == 14 && !restoredList.items.contains { $0.id == cook.rankedItemID })
        #expect(restoredList.comparisons.allSatisfy { $0.firstItemID != cook.rankedItemID && $0.secondItemID != cook.rankedItemID })
        #expect(try restoredList.rankingContext().analyze().diagnostics.ignoredEvidenceCount == 0)
    }

    @Test func repeatedAssessmentSkipOnlyAndStaleSessionAreSafe() throws {
        let f = try CookingReRankingWorkflowTests().fixture(12)
        let target = try #require(f.cooks.first), item = try #require(target.rankedItem)
        for direction in [ComparisonAnswer.existingItem, .newItem, .existingItem] {
            let oldIDs = Set(f.list.comparisons.map(\.id))
            let workflow = CookingReRankingWorkflow(attempt: target)
            try workflow.choose(direction == .newItem ? .liked : .disliked, context: f.context)
            var n = 0
            while workflow.session?.nextOpponent != nil { workflow.answer(direction); n += 1; if n > 80 { throw RankingContext.InvalidHistory() } }
            try workflow.finish(context: f.context)
            #expect(oldIDs.isSubset(of: Set(f.list.comparisons.map(\.id))))
            #expect(direction == .newItem ? f.list.orderedItems.first?.id == item.id : f.list.orderedItems.last?.id == item.id)
        }
        let metadata = try RankingAssessment.read(item.sessionDiagnosticsData)
        #expect(metadata.count == 3)
        let before = f.list.items.map { ($0.id, $0.strength) }
        let skip = CookingReRankingWorkflow(attempt: target); try skip.choose(.fine, context: f.context)
        while skip.session?.nextOpponent != nil { skip.answer(.skip) }
        try skip.finish(context: f.context)
        #expect(try RankingAssessment.read(item.sessionDiagnosticsData) == metadata)
        for (id, strength) in before { #expect(f.list.items.first { $0.id == id }?.strength == strength) }
        let stale = CookingReRankingWorkflow(attempt: target); try stale.choose(.fine, context: f.context)
        while stale.session?.nextOpponent != nil { stale.answer(.newItem) }
        try RankingStore.record(.init(first: item.id, second: f.cooks[1].rankedItemID, outcome: 0.5), in: f.list, context: f.context)
        let saved = try CookingGraphExport.snapshot(context: f.context)
        #expect(throws: (any Error).self) { try stale.finish(context: f.context) }
        #expect(try CookingGraphExport.snapshot(context: f.context) == saved)
    }

    @Test func deletingOpponentPreservesTheRemainingAssessmentAndHistory() throws {
        let f = try CookingReRankingWorkflowTests().fixture(12)
        let target = try #require(f.cooks.first), item = try #require(target.rankedItem)
        let workflow = CookingReRankingWorkflow(attempt: target); try workflow.choose(.disliked, context: f.context)
        while workflow.session?.nextOpponent != nil { workflow.answer(.existingItem) }
        try workflow.finish(context: f.context)
        let metadata = item.sessionDiagnosticsData, other = f.cooks[1], retired = other.rankedItemID
        let retained = Dictionary(uniqueKeysWithValues: f.list.comparisons.filter { $0.firstItemID != retired && $0.secondItemID != retired }.map { ($0.id, $0.evidence) })
        try CookingStore.delete(other, context: f.context)
        #expect(item.sessionDiagnosticsData == metadata && f.list.items.count == 11)
        #expect(Set(f.list.comparisons.map(\.id)) == Set(retained.keys))
        for edge in f.list.comparisons { #expect(edge.evidence == retained[edge.id]) }
        let fit = try f.list.rankingContext().analyze()
        #expect(fit.diagnostics.converged && fit.diagnostics.ignoredEvidenceCount == 0)
        #expect(Set(fit.ids) == Set(f.list.items.map(\.id)))
    }

    @Test func historicalMarginalizationPreservesPairwiseUncertainty() {
        let a = id(0), b = id(1), history = id(2)
        let full = BradleyTerryModel.analyze(ids: [a,b,history], evidence: [
            .init(first:a, second:history, outcome:1), .init(first:history, second:b, outcome:1)])
        let projected = full.projected(onto: [a,b])
        #expect(projected.ids == [a,b])
        #expect(abs(projected.relationship(a,b)!.standardDeviation - full.relationship(a,b)!.standardDeviation) < 1e-12)
        #expect(projected.estimates[a]!.strength == full.estimates[a]!.strength)
        #expect(abs(projected.estimates[a]!.uncertainty - full.estimates[a]!.uncertainty) < 1e-12)
        #expect(projected.rankEstimates().values.allSatisfy { $0.lower95 >= 1 && $0.upper95 <= 2 })
    }

    @Test func metadataIsAdditiveCorruptionFailsClosedAndNoAssessmentDoesNotChangeLegacyFit() throws {
        let baseline = try context(repeats: 1)
        let ordinary = BradleyTerryModel.analyze(ids: baseline.currentIDs, evidence: baseline.observations.map(\.evidence))
        #expect(ordinary.estimates == baseline.analyze().estimates)
        let epoch = try #require(baseline.reassessment(of: id(3)))
        let old = Data("{\"futureField\":42,\"initialReaction\":\"It was fine\"}".utf8)
        let data = try RankingAssessment.appending(epoch, to: old)
        #expect(try RankingAssessment.read(data) == [epoch])
        #expect((try JSONSerialization.jsonObject(with: data) as? [String: Any])?["futureField"] as? Int == 42)
        #expect(throws: (any Error).self) { try RankingAssessment.read(Data("{\"rankingAssessments\":false}".utf8)) }
        #expect(throws: (any Error).self) { try baseline.adding(.init(parameterID: id(3), comparisonIDs: epoch.comparisonIDs), for: id(3)) }
    }
}
