import Foundation

/// One resolver for a cook's user-facing name (FOOD_ARCHITECTURE §4.2).
///
/// The custom name is stored in the existing `versionTitle` / `version_title` field.
/// Without one, a cook shows the fallback "Version N" from its stable `sequenceNumber`
/// (never renumbered). A lone unnamed cook shows no label. Names are labels only:
/// identity, ranking evidence and Recipe provenance key on IDs, never on this value.
nonisolated enum CookName {
    /// Matches the server limit for shared cook names (`social_posts.version_title`).
    static let maximumLength = 200

    /// Trims, collapses internal whitespace runs and bounds the length. Empty becomes nil,
    /// which returns the cook to its fallback name.
    static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let collapsed = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(maximumLength))
    }

    static func fallback(sequence: Int) -> String { "Version \(sequence)" }

    /// The name shown wherever a cook needs a label, or nil for a lone unnamed first cook.
    static func label(custom: String?, sequence: Int, siblingCount: Int) -> String? {
        if let custom = normalized(custom) { return custom }
        return siblingCount > 1 || sequence > 1 ? fallback(sequence: sequence) : nil
    }

    /// The name with its fallback always shown, used as the Cook Name field placeholder.
    static func name(custom: String?, sequence: Int) -> String {
        normalized(custom) ?? fallback(sequence: sequence)
    }
}
