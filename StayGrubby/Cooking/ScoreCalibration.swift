import Foundation

/// Presentation only. Never supplies a prior, comparison outcome, or sorting key to BT.
///
/// Version 2 (November 24, 2026) adds Love It. Stored reaction fields in the opaque diagnostics JSON:
/// - `initialReaction` / `latestSemanticReaction`: the original three-value fields. New builds write
///   `InitialReaction.compatibilityValue`, so builds up to 1.0 (9) and the pre-Love-It server show a
///   Love It cook in the Liked band instead of the legacy 1–10 fallback.
/// - `initialSemanticReaction` / `semanticReaction`: the actual reaction, including Love It.
/// `semanticReaction` counts only while `scoreCalibrationVersion` ≥ 2: an older build's re-rank rewrites
/// the version to 1 and `latestSemanticReaction`, so its newer choice wins over a stale Love It.
nonisolated enum ScoreCalibration {
    static let version = 2
    enum MetadataError: Error { case invalidDiagnostics }

    static func reaction(in data: Data?) -> InitialReaction? {
        guard let data, let record = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        func parse(_ key: String) -> InitialReaction? { (record[key] as? String).flatMap(InitialReaction.init(rawValue:)) }
        let current = (record["scoreCalibrationVersion"] as? Int ?? 0) >= 2 ? parse("semanticReaction") : nil
        return current ?? parse("latestSemanticReaction") ?? parse("initialSemanticReaction") ?? parse("initialReaction")
    }
    static func score(strength: Double, metadata: Data?) -> Double {
        score(strength: strength, reaction: reaction(in: metadata))
    }
    static func score(strength: Double, reaction: InitialReaction?) -> Double {
        let s = strength.isFinite ? strength : 0
        switch reaction {
        case .loved: return 7 + 3 * sigmoid(s / 1.6 + 0.4) // Liked's 7–10 range, shifted up; a beaten Love It cook can still score below a winning Liked one.
        case .liked: return 7 + 3 * sigmoid(s / 1.6 - 0.4)
        case .fine: return 4.8 + 3 * sigmoid(s / 1.6)
        case .disliked: return 1 + 4.8 * sigmoid(s / 1.6)
        case nil: return 1 + 9 * sigmoid(s / 2) // Unknown legacy assessment: preserve the old mapping.
        }
    }
    private static func sigmoid(_ value: Double) -> Double {
        if value >= 0 { return 1 / (1 + exp(-value)) }
        let e = exp(value); return e / (1 + e)
    }

    /// Preserve original diagnostics and unknown future fields. Called only inside a completed
    /// re-rank transaction; cancellation, comparisons and passive restore never write this key.
    static func recording(_ reaction: InitialReaction, in data: Data?) throws -> Data {
        var fields: [String: Any] = [:]
        if let data {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw MetadataError.invalidDiagnostics }
            fields = object
        }
        fields["latestSemanticReaction"] = reaction.compatibilityValue
        fields["semanticReaction"] = reaction.rawValue
        fields["scoreCalibrationVersion"] = version
        return try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
    }
}
