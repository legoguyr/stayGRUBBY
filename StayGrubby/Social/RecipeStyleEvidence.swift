import Foundation

/// Version 3 cookbook editing equivalents. Procedural numbers and ingredients
/// still pass the existing source/binding guard; this is not a free thesaurus.
nonisolated enum RecipeStyleEvidence {
    static func broilerClause(_ raw: String) -> String? {
        raw.components(separatedBy: CharacterSet(charactersIn: ".!?;\n")).first {
            $0.range(of: #"\bturn on (?:the )?(?:boiler|broiler)\b"#, options: [.regularExpression,.caseInsensitive]) != nil && $0.range(of: #"\b(?:cook|heat)\b.{0,80}\bunder\b"#, options: [.regularExpression,.caseInsensitive]) != nil
        }
    }
    static func heatAlternative(_ raw: String) -> Bool {
        raw.components(separatedBy: CharacterSet(charactersIn: ".;\n")).contains {
            $0.range(of: #"\bor\b"#, options: [.regularExpression,.caseInsensitive]) != nil &&
            $0.range(of: #"\b(?:chili|chile|chilies|chiles|chillies|pepper flakes)\b"#, options: [.regularExpression,.caseInsensitive]) != nil
        }
    }
    static func text(_ value: String, raw: String, kind: RecipeSourceEvidence.Kind) -> String {
        var s = value.lowercased().replacingOccurrences(of: #"\b(?:chili|chilies|chiles|chillies)\b"#, with: "chile", options: .regularExpression)
        // Closed spelling/inflection equivalents, mirrored by the Edge guard.
        s = s.replacingOccurrences(of: #"\b(?:wisk|whisking|whisked)\b"#, with: "whisk", options: .regularExpression)
            .replacingOccurrences(of: #"\b(?:stirring|stirred)\b"#, with: "stir", options: .regularExpression)
            .replacingOccurrences(of: #"\b(?:heated|heating)\b"#, with: "heat", options: .regularExpression)
            .replacingOccurrences(of: #"\b(?:browned|browning)\b"#, with: "brown", options: .regularExpression)
            .replacingOccurrences(of: #"\bprevents\b"#, with: "prevent", options: .regularExpression)
        switch kind {
        case .ingredient, .step:
            // Only singular measures OF ingredients, never a bare cup/vessel.
            s = s.replacingOccurrences(of: #"\b(?:a|an)\s+(teaspoon|tablespoon|cup|pinch|ounce|pound|gram|kilogram|milliliter|millilitre|liter|litre)\s+of\b"#, with: "1 $1 of", options: .regularExpression)
            s = s.replacingOccurrences(of: #"\b(?:some|a little|as needed|to taste|preferred)\b"#, with: "", options: .regularExpression)
            if heatAlternative(raw) { s = s.replacingOccurrences(of: #"\b(?:red\s+)?pepper flakes\b"#, with: "chile", options: .regularExpression) }
        default: break
        }
        if case .title = kind {
            if raw.range(of: #"\b(?:blend|blender|sauce|mix|top)\b"#, options: [.regularExpression,.caseInsensitive]) != nil { s = s.replacingOccurrences(of: #"\b(?:sauce|garnish)\b"#, with: "", options: .regularExpression) }
            s = s.replacingOccurrences(of: #"\b(?:assembly|preparation)\b"#, with: "preparation", options: .regularExpression) + " preparation"
        }
        if case .step = kind {
            s = s.replacingOccurrences(of: #"\b(?:diced|dicing)\b"#, with: "dice", options: .regularExpression)
                .replacingOccurrences(of: #"\b(?:chopped|chopping)\b"#, with: "chop", options: .regularExpression)
                .replacingOccurrences(of: #"\b(?:sliced|slicing)\b"#, with: "slice", options: .regularExpression)
                .replacingOccurrences(of: #"\bsaut(?:é|e)(?:ing|ed)?(?!\p{L})"#, with: "saute", options: .regularExpression)
            if broilerClause(raw) != nil {
                s = s.replacingOccurrences(of: #"\b(?:boiler|broiler|broil(?:ed|ing)?)\b"#, with: "broiler", options: .regularExpression)
            }
            if raw.range(of: #"\b(?:mid|medium)[ -]low\b"#, options: [.regularExpression,.caseInsensitive]) != nil && raw.range(of: #"\b(?:heat|pan)\b"#, options: [.regularExpression,.caseInsensitive]) != nil {
                s = s.replacingOccurrences(of: #"\bmid[ -]low\b"#, with: "medium-low", options: .regularExpression)
            }
            if raw.range(of: #"\bdunk(?:ed|ing)?\b"#, options: [.regularExpression,.caseInsensitive]) != nil {
                s = s.replacingOccurrences(of: #"\b(?:dunk(?:ed|ing)?|dip(?:ped|ping)?)\b"#, with: "dunk", options: .regularExpression)
            }
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
