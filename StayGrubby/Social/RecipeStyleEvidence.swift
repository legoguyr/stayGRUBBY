import Foundation

/// Version 3 cookbook editing equivalents. Procedural numbers and ingredients
/// still pass the existing source/binding guard; this is not a free thesaurus.
nonisolated enum RecipeStyleEvidence {
    static func heatAlternative(_ raw: String) -> Bool {
        raw.components(separatedBy: CharacterSet(charactersIn: ".;\n")).contains {
            $0.range(of: #"\bor\b"#, options: [.regularExpression,.caseInsensitive]) != nil &&
            $0.range(of: #"\b(?:chili|chile|chilies|chiles|chillies|pepper flakes)\b"#, options: [.regularExpression,.caseInsensitive]) != nil
        }
    }
    static func text(_ value: String, raw: String, kind: RecipeSourceEvidence.Kind) -> String {
        var s = value.lowercased().replacingOccurrences(of: #"\b(?:chili|chilies|chiles|chillies)\b"#, with: "chile", options: .regularExpression)
        switch kind {
        case .ingredient, .step:
            s = s.replacingOccurrences(of: #"\b(?:some|a little|as needed|to taste|preferred)\b"#, with: "", options: .regularExpression)
            if heatAlternative(raw) { s = s.replacingOccurrences(of: #"\b(?:red\s+)?pepper flakes\b"#, with: "chile", options: .regularExpression) }
        default: break
        }
        if case .title = kind {
            if raw.range(of: #"\b(?:blend|blender|sauce|mix|top)\b"#, options: [.regularExpression,.caseInsensitive]) != nil { s = s.replacingOccurrences(of: #"\b(?:sauce|garnish)\b"#, with: "", options: .regularExpression) }
            s = s.replacingOccurrences(of: #"\b(?:assembly|preparation)\b"#, with: "preparation", options: .regularExpression) + " preparation"
        }
        if case .step = kind {
            s = s.replacingOccurrences(of: #"\b(?:onto|over)\b"#, with: "on", options: .regularExpression)
            s = s.replacingOccurrences(of: #"\bbring (?:it )?to (?:a )?boil\b"#, with: "boil", options: .regularExpression).replacingOccurrences(of: #"\bice bath\b"#, with: "ice water", options: .regularExpression)
            if raw.range(of: #"\b(?:kale|spinach|chard|greens|leaves)\b"#, options: [.regularExpression,.caseInsensitive]) != nil && raw.range(of: #"\b(?:blanch|blanche|boil)\b"#, options: [.regularExpression,.caseInsensitive]) != nil && raw.range(of: #"\bstarts? to wet\b"#, options: [.regularExpression,.caseInsensitive]) != nil { s = s.replacingOccurrences(of: #"\bwilt(?:ed|ing)?\b"#, with: "wet", options: .regularExpression) }
            if raw.range(of: #"\b(?:blender|blend)\b"#, options: [.regularExpression,.caseInsensitive]) != nil { s = s.replacingOccurrences(of: #"\bpur(?:ee|ée)\b"#, with: "blend", options: .regularExpression) }
            if raw.range(of: #"\btop\b"#, options: [.regularExpression,.caseInsensitive]) != nil && raw.range(of: #"\boil\b"#, options: [.regularExpression,.caseInsensitive]) != nil { s = s.replacingOccurrences(of: #"\bcoat\b"#, with: "top", options: .regularExpression) }
            if ["mix","butter","glossy"].allSatisfy({ raw.range(of: "\\b" + $0 + "\\b", options: [.regularExpression,.caseInsensitive]) != nil }) { s = s.replacingOccurrences(of: #"\bemulsify\b"#, with: "mix", options: .regularExpression) }
            if raw.range(of: #"\bparchment\b"#, options: [.regularExpression,.caseInsensitive]) != nil && raw.range(of: #"\b(?:sheet|pan|tin)\b"#, options: [.regularExpression,.caseInsensitive]) != nil { s = s.replacingOccurrences(of: #"\bline\b"#, with: "put", options: .regularExpression).replacingOccurrences(of: #"\bbaking\b"#, with: "bake", options: .regularExpression) }
            s = s.replacingOccurrences(of: #"\b(?:you are going to|you're going to|youre gonna|you are gonna|is done by|is made by)\b"#, with: "", options: .regularExpression).replacingOccurrences(of: #"\btaking\b"#, with: "take", options: .regularExpression)
        }
        return s
    }
}
