import Foundation

/// An explicit reassessment starts a new latent strength for this entry. Historical
/// observations still have unit weight, attached to the strength assessed then.
/// The original Comparison records and RankedItem identities never change.
nonisolated struct RankingAssessment: Codable, Equatable {
    let parameterID: UUID
    let comparisonIDs: [UUID]

    static func read(_ data: Data?) throws -> [Self] {
        guard let data else { return [] }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw RankingContext.InvalidHistory() }
        guard let value = object["rankingAssessments"] else { return [] }
        guard JSONSerialization.isValidJSONObject(value) else { throw RankingContext.InvalidHistory() }
        return try JSONDecoder().decode([Self].self, from: JSONSerialization.data(withJSONObject: value))
    }

    static func appending(_ assessment: Self, to data: Data?) throws -> Data {
        var object: [String: Any] = [:]
        if let data {
            guard let fields = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw RankingContext.InvalidHistory() }
            object = fields
        }
        var assessments = try read(data)
        assessments.append(assessment)
        object["rankingAssessments"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(assessments))
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}

nonisolated struct RankingObservation: Equatable {
    let id: UUID
    let evidence: PreferenceEvidence
}

/// Immutable session snapshot shared by acquisition and persistence. No reaction,
/// ordinal penalty, evidence decay, or hand-assigned score enters the BT objective.
nonisolated struct RankingContext: Equatable {
    struct InvalidHistory: Error {}
    let currentIDs: [UUID]
    let observations: [RankingObservation]
    let assessments: [UUID: [RankingAssessment]]

    init(currentIDs: [UUID], observations: [RankingObservation], assessments: [UUID: [RankingAssessment]] = [:]) throws {
        let current = Set(currentIDs)
        guard current.count == currentIDs.count, Set(observations.map(\.id)).count == observations.count else { throw InvalidHistory() }
        var parameters = current
        for (item, epochs) in assessments {
            guard current.contains(item) else { throw InvalidHistory() }
            var assigned = Set<UUID>()
            for epoch in epochs {
                guard parameters.insert(epoch.parameterID).inserted,
                      !epoch.comparisonIDs.isEmpty,
                      epoch.comparisonIDs.allSatisfy({ assigned.insert($0).inserted }) else { throw InvalidHistory() }
            }
        }
        for observation in observations {
            let e = observation.evidence
            guard current.contains(e.first), current.contains(e.second), e.first != e.second,
                  [0.0, 0.5, 1.0].contains(e.outcome) else { throw InvalidHistory() }
        }
        // Stale IDs after normal comparison deletion are harmless; assigning an
        // existing unrelated comparison is corrupt metadata, never silently ignored.
        let byID = Dictionary(uniqueKeysWithValues: observations.map { ($0.id, $0.evidence) })
        for (item, epochs) in assessments {
            for id in epochs.flatMap(\.comparisonIDs) {
                if let e = byID[id], e.first != item && e.second != item { throw InvalidHistory() }
            }
        }
        self.currentIDs = currentIDs.sorted { $0.uuidString < $1.uuidString }; self.observations = observations.sorted { $0.id.uuidString < $1.id.uuidString }; self.assessments = assessments
    }

    func reassessment(of item: UUID) -> RankingAssessment? {
        let retired = Set((assessments[item] ?? []).flatMap(\.comparisonIDs))
        let ids = observations.filter { ($0.evidence.first == item || $0.evidence.second == item) && !retired.contains($0.id) }.map(\.id)
        return ids.isEmpty ? nil : RankingAssessment(parameterID: UUID(), comparisonIDs: ids.sorted { $0.uuidString < $1.uuidString })
    }

    func adding(_ assessment: RankingAssessment?, for item: UUID) throws -> Self {
        var updated = assessments
        if let assessment { updated[item, default: []].append(assessment) }
        return try Self(currentIDs: currentIDs, observations: observations, assessments: updated)
    }

    func analyze(adding evidence: [PreferenceEvidence] = [], newItem: UUID? = nil) -> RankingAnalysis {
        var assignment: [UUID: [UUID: UUID]] = [:]
        for (item, epochs) in assessments {
            for epoch in epochs {
                for id in epoch.comparisonIDs { assignment[item, default: [:]][id] = epoch.parameterID }
            }
        }
        let history = observations.map { observation in
            let e = observation.evidence
            return PreferenceEvidence(first: assignment[e.first]?[observation.id] ?? e.first,
                                      second: assignment[e.second]?[observation.id] ?? e.second,
                                      outcome: e.outcome, timestamp: e.timestamp)
        }
        let visible = Array(Set(currentIDs + (newItem.map { [$0] } ?? []))).sorted { $0.uuidString < $1.uuidString }
        let parameters = Array(Set(visible + history.flatMap { [$0.first, $0.second] }))
        return BradleyTerryModel.analyze(ids: parameters, evidence: history + evidence).projected(onto: visible)
    }
}
