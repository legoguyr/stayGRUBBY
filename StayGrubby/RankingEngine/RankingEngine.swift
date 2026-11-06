import Foundation

nonisolated enum InitialReaction: String, CaseIterable, Identifiable {
    case liked = "Liked it", fine = "It was fine", disliked = "Didn't like it"
    var id: String { rawValue }
    var percentile: Double {
        switch self { case .liked: 0.2; case .fine: 0.5; case .disliked: 0.8 }
    }
}

nonisolated enum ComparisonAnswer { case newItem, existingItem, tooTough, skip }

/// Value-type session: replaying answers gives exact undo, including skipped opponents.
/// A noisy insertion posterior is an acquisition heuristic over the *current* ordering.
/// It is separate from the score model, which always retains contradictory evidence.
nonisolated struct RankingEngine {
    struct Answer {
        let opponent: UUID
        let answer: ComparisonAnswer
        let timestamp: Date
    }
    let itemID: UUID
    let orderedIDs: [UUID]
    let reaction: InitialReaction
    let startedAt: Date = .now
    private(set) var answers: [Answer] = []
    private(set) var totalAnswerActions = 0
    private(set) var undoCount = 0
    let context: RankingContext?
    private var fitted: RankingAnalysis?

    init(itemID: UUID, orderedIDs: [UUID], reaction: InitialReaction, context: RankingContext? = nil) {
        self.itemID = itemID; self.orderedIDs = orderedIDs; self.reaction = reaction; self.context = context
    }

    var evidence: [PreferenceEvidence] {
        answers.compactMap { entry in
            let outcome: Double
            switch entry.answer {
            case .newItem: outcome = 1
            case .existingItem: outcome = 0
            case .tooTough: outcome = 0.5
            case .skip: return nil
            }
            return PreferenceEvidence(first: itemID, second: entry.opponent, outcome: outcome, timestamp: entry.timestamp)
        }
    }

    var placementProbabilities: [Double] {
        let count = orderedIDs.count
        guard count > 0 else { return [1] }
        // Broad reaction prior leaves every position possible. It never enters BT fitting.
        var weights = (0...count).map { slot in
            0.25 + exp(-pow((Double(slot) / Double(count) - reaction.percentile) / 0.35, 2) / 2)
        }
        for entry in answers where entry.answer != .skip {
            guard let index = orderedIDs.firstIndex(of: entry.opponent) else { continue }
            for slot in weights.indices {
                switch entry.answer {
                case .newItem: weights[slot] *= slot <= index ? 0.995 : 0.005
                case .existingItem: weights[slot] *= slot > index ? 0.995 : 0.005
                case .tooTough:
                    weights[slot] *= 0.001 + exp(-pow((Double(slot) - Double(index) - 0.5) / 0.5, 2) / 2)
                case .skip: break
                }
            }
            let total = weights.reduce(0, +)
            weights = weights.map { $0 / total }
        }
        let total = weights.reduce(0, +)
        return weights.map { $0 / total }
    }

    private var confidenceStopReason: SessionStopReason? {
        if orderedIDs.isEmpty { return .firstItem }
        guard !evidence.isEmpty else { return nil }
        let p = placementProbabilities
        if p.max()! >= 0.90 { return .singleSlotConfidence }
        if answers.contains(where: { $0.answer == .tooTough }),
           zip(p, p.dropFirst()).contains(where: { $0 + $1 >= 0.95 }) { return .adjacentTieConfidence }
        return nil
    }

    var placementResolved: Bool { confidenceStopReason != nil && modelPlacementAgrees }

    private var modelPlacementAgrees: Bool {
        guard context != nil, !orderedIDs.isEmpty else { return true }
        guard let fitted, fitted.diagnostics.converged, let target = fitted.estimates[itemID] else { return false }
        // Same quantization as the persisted ordering. A near tie is within the
        // conditional interval; the store retains createdAt/UUID tie breaking.
        let position = orderedIDs.filter { (fitted.estimates[$0]!.strength * 1e7).rounded() > (target.strength * 1e7).rounded() }.count
        var cumulative = 0.0, lower = 0, upper = orderedIDs.count
        var found = false
        for (slot, probability) in placementProbabilities.enumerated() {
            cumulative += probability
            if !found && cumulative >= 0.025 { lower = slot; found = true }
            if cumulative >= 0.975 { upper = slot; break }
        }
        return position >= lower && position <= upper
    }

    /// When the insertion heuristic and the actual global fit disagree, ask a
    /// useful corrective pair, including repeated evidence. Skip remains local.
    private var correctiveCandidate: (id: UUID, information: Double)? {
        guard context != nil, let fitted, fitted.diagnostics.converged else { return nil }
        let skipped = Set(answers.filter { $0.answer == .skip }.map(\.opponent))
        let probabilities = placementProbabilities
        var candidates: [(UUID, Double)] = [], cumulative = 0.0
        for (index, id) in orderedIDs.enumerated() {
            cumulative += probabilities[index]
            guard !skipped.contains(id), let relationship = fitted.relationship(itemID, id), relationship.informationGainBits >= 0.01 else { continue }
            let p = BradleyTerryModel.logistic(relationship.strengthDifference)
            candidates.append((id, abs(cumulative - p) * relationship.informationGainBits))
        }
        let varied = candidates.filter { $0.0 != answers.last?.opponent }
        return (varied.isEmpty ? candidates : varied).max { $0.1 < $1.1 }
    }

    private var bestCandidate: (id: UUID, information: Double)? {
        let used = Set(answers.map(\.opponent))
        let p = placementProbabilities
        var cumulative = 0.0
        var best: (UUID, Double)?
        for (index, id) in orderedIDs.enumerated() {
            cumulative += p[index]
            guard !used.contains(id) else { continue }
            // Binary entropy is maximal at the posterior median: most uncertainty removed.
            let chance = min(0.999999, max(0.000001, cumulative))
            let information = -chance * log2(chance) - (1 - chance) * log2(1 - chance)
            if best == nil || information > best!.1 { best = (id, information) }
        }
        return best
    }

    var stopReason: SessionStopReason? {
        if let reason = confidenceStopReason, modelPlacementAgrees { return reason }
        if confidenceStopReason != nil, context != nil { return correctiveCandidate == nil ? .lowInformation : nil }
        guard let best = bestCandidate else { return .opponentsExhausted }
        return best.information < 0.08 ? .lowInformation : nil
    }

    var nextOpponent: UUID? {
        guard !placementResolved else { return nil }
        if confidenceStopReason != nil, context != nil { return correctiveCandidate?.id }
        guard let candidate = bestCandidate, candidate.information >= 0.08 else { return nil }
        return candidate.id
    }

    var isComplete: Bool { nextOpponent == nil }
    var canUndo: Bool { !answers.isEmpty }
    mutating func answer(_ answer: ComparisonAnswer, at timestamp: Date = .now) {
        guard let opponent = nextOpponent else { return }
        answers.append(Answer(opponent: opponent, answer: answer, timestamp: timestamp))
        totalAnswerActions += 1
        if answer != .skip { fitted = context?.analyze(adding: evidence, newItem: itemID) }
    }
    mutating func undo() {
        if canUndo {
            let removed = answers.removeLast(); undoCount += 1
            if removed.answer != .skip { fitted = context?.analyze(adding: evidence, newItem: itemID) }
        }
    }

    func diagnostics(analysis: RankingAnalysis? = nil, rank: RankEstimate? = nil) -> SessionDiagnostics {
        let p = placementProbabilities
        let mean = p.enumerated().reduce(0.0) { $0 + Double($1.offset) * $1.element }
        let variance = p.enumerated().reduce(0.0) { $0 + pow(Double($1.offset) - mean, 2) * $1.element }
        var cumulative = 0.0
        var lower: Int?
        var upper = orderedIDs.count
        for (slot, probability) in p.enumerated() {
            cumulative += probability
            if lower == nil && cumulative >= 0.025 { lower = slot }
            if cumulative >= 0.975 { upper = slot; break }
        }
        let estimate = analysis?.estimates[itemID]
        return SessionDiagnostics(version: 2, startedAt: startedAt, initialReaction: reaction.rawValue,
                                  existingItemCount: orderedIDs.count, comparisonCount: evidence.count,
                                  skipCount: answers.count - evidence.count, totalAnswerActions: totalAnswerActions,
                                  undoCount: undoCount, stopReason: stopReason,
                                  maximumSlotProbability: p.max() ?? 1,
                                  positionMean: mean, positionStandardDeviation: sqrt(variance),
                                  positionLower95: lower ?? 0, positionUpper95: upper,
                                  positionEntropyBits: -p.filter { $0 > 0 }.reduce(0) { $0 + $1 * log2($1) },
                                  strengthStandardDeviation: estimate?.uncertainty,
                                  scoreInterval95: estimate?.scoreInterval95, modelRank: rank,
                                  modelConverged: analysis?.diagnostics.converged,
                                  modelMaximumGradient: analysis?.diagnostics.maximumGradient)
    }
}
