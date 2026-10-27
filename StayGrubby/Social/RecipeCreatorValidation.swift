import Foundation

/// Source/provenance validation for the transient Creator contract, not Recipe ownership.
nonisolated enum RecipeCreatorValidation {
    static func effectiveSource(_ raw: String) -> String {
        let q = #"(?:\d+(?:[./]\d+)?|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)"#
        let pattern = #"\b"# + q + #"\s+([a-z]+(?:\s+[a-z]+){0,2})\s*,?\s+(?:no,?|actually,?|sorry,? I mean)\s+("# + q + #")\s+\1\b"#
        return raw.replacingOccurrences(of: pattern, with: "$2 $1", options: [.regularExpression,.caseInsensitive])
    }
    static func number(_ value: String) -> Double? {
        guard let token = RecipeSourceEvidence.tokens(value).first(where: { $0.hasPrefix("n") && $0.dropFirst().first?.isNumber == true }) else { return nil }
        let parts = token.dropFirst().split(separator: "/").compactMap { Double($0) }
        return parts.count == 2 && parts[1] != 0 ? parts[0]/parts[1] : nil
    }
    static func tokenNumber(_ token: String) -> Double? {
        guard token.hasPrefix("n") else { return nil }; let a = token.dropFirst().split(separator: "/").compactMap { Double($0) }
        return a.count == 2 && a[1] != 0 ? a[0]/a[1] : nil
    }
    static func durations(_ text: String) -> [Double] {
        let t = RecipeSourceEvidence.tokens(text)
        return t.indices.compactMap { i in guard i+1 < t.count, let n = tokenNumber(t[i]), ["min","hour"].contains(t[i+1]) else { return nil }; return n * (t[i+1] == "hour" ? 60 : 1) }
    }
    static func explicit(_ raw: String, key: String) -> Double? {
        let t = RecipeSourceEvidence.tokens(raw)
        for i in t.indices {
            if key == "yield", ["serves","servings","yield","makes"].contains(t[i]), i+1 < t.count, let n = tokenNumber(t[i+1]) { return n }
            let role = key == "prepMinutes" ? ["prep","preparation"] : key == "cookMinutes" ? ["cook","cooking"] : ["total","elapsed"]
            if key != "yield", role.contains(t[i]), i+3 < t.count, t[i+1] == "time", let n = tokenNumber(t[i+2]), ["min","hour"].contains(t[i+3]) { return n * (t[i+3] == "hour" ? 60 : 1) }
        }
        return nil
    }
    static func statement(_ raw: String, key: String) -> String {
        let role = key == "yield" ? "(?:serves|servings|yield|makes)" : key == "prepMinutes" ? "(?:prep(?:aration)? time)" : key == "cookMinutes" ? "(?:cook(?:ing)? time)" : "(?:total time|elapsed time)"
        return RecipeEditorialEvidence.matches(#"\b"# + role + #"\b[^.;\n]{0,180}"#, raw).first?.first ?? String(raw.prefix(180))
    }
    static func yieldLabel(_ raw: String, n: Double) -> String {
        let t = RecipeSourceEvidence.tokens(statement(raw, key: "yield")), count = String(format: "%g", n)
        guard let i = t.firstIndex(where: { tokenNumber($0) != nil }), i+1 < t.count else { return count }
        let tail = Array(t.dropFirst(i+1))
        if ["servings","serving","people","persons","person","portions"].contains(tail[0]) { return count }
        return ([count] + tail.prefix(2).filter { $0.range(of: #"^[a-z]+$"#, options: .regularExpression) != nil }).joined(separator: " ")
    }
    static func normalize(_ metadata: RecipeCreatorMetadata, raw: String, polished: Bool = false) -> RecipeCreatorMetadata {
        var m = metadata
        func evidence(_ text: String?) -> Bool { guard let text, !text.isEmpty, text.count <= 500 else { return false }; return RecipeImportValidation.normalized(raw).contains(RecipeImportValidation.normalized(text)) }
        func text(_ p: RecipeTextProposal, key: String) -> RecipeTextProposal {
            if key != "cuisine", let stated = explicit(raw, key: key), p.origin != .derived { return .init(value: yieldLabel(raw, n: stated), origin: .provided, evidence: statement(raw, key: key)) }
            guard p.origin != .unknown, let value = p.value, !value.isEmpty, value.count <= 100 else { return .init() }
            if polished && p.origin == .estimated {
                if key == "cuisine" && !CuisineCatalog.predefined.contains(where: { $0.label == value }) { return .init() }
                return .init(value: value, origin: .estimated, evidence: String(raw.prefix(500)))
            }
            guard evidence(p.evidence) else { return .init() }
            if key == "cuisine" {
                guard CuisineCatalog.predefined.contains(where: { $0.label == value }), p.origin != .provided || RecipeImportValidation.normalized(p.evidence!).contains(RecipeImportValidation.normalized(value)) else { return .init() }
                return p
            }
            let n = number(value), stated = explicit(raw, key: key)
            if let stated, n != stated, !(key == "yield" && p.origin == .derived) { return .init() }
            if p.origin == .provided && (stated == nil || n != stated) { return .init() }
            if p.origin == .derived {
                let ns = RecipeSourceEvidence.tokens(p.evidence!).filter { $0.hasPrefix("n") && $0.dropFirst().first?.isNumber == true }.compactMap { token -> Double? in
                    let a = token.dropFirst().split(separator: "/").compactMap { Double($0) }; return a.count == 2 ? a[0]/a[1] : nil
                }
                guard ns.count == 2, ns[1] > 0, ns[0]/ns[1] == n, p.evidence!.range(of: #"per (?:person|serving)"#, options: [.regularExpression,.caseInsensitive]) != nil else { return .init() }
            }
            return p
        }
        func time(_ p: RecipeTimeProposal, key: String) -> RecipeTimeProposal {
            if let stated = explicit(raw, key: key) { guard stated <= 10080 else { return .init() }; return .init(value: Int(ceil(stated)), origin: stated.rounded() == stated ? .provided : .derived, evidence: statement(raw, key: key)) }
            guard p.origin != .unknown, let value = p.value, (0...10080).contains(value) else { return .init() }
            if polished && p.origin == .estimated { return .init(value: value, origin: .estimated, evidence: String(raw.prefix(500))) }
            guard evidence(p.evidence) else { return .init() }
            let stated = explicit(raw, key: key)
            if let stated, Double(value) != stated { return .init() }
            if p.origin == .provided && (stated == nil || Double(value) != stated) { return .init() }
            if p.origin == .derived {
                let ns = durations(p.evidence!)
                let parts = [m.prepMinutes.value,m.cookMinutes.value].compactMap { $0 }
                let parallel = p.evidence!.range(of: "parallel|while|meanwhile", options: [.regularExpression,.caseInsensitive]) != nil
                let supported = ns.contains(Double(value)) || (!parallel && ns.reduce(0,+) == Double(value)) || (key == "totalMinutes" && !parts.isEmpty && (parts.reduce(0,+) == value || parts.max() == value))
                if !supported { return .init() }
            }
            return p
        }
        m.yield = text(m.yield, key: "yield")
        m.prepMinutes = time(m.prepMinutes, key: "prepMinutes"); m.cookMinutes = time(m.cookMinutes, key: "cookMinutes")
        m.totalMinutes = time(m.totalMinutes, key: "totalMinutes"); m.cuisine = text(m.cuisine, key: "cuisine")
        if m.totalMinutes.value == nil, let prep = m.prepMinutes.value, let cook = m.cookMinutes.value, prep+cook <= 10080, raw.range(of: "parallel|while|meanwhile", options: [.regularExpression,.caseInsensitive]) == nil {
            m.totalMinutes = .init(value: prep+cook, origin: .derived, evidence: String(raw.prefix(500)))
        }
        if let total = m.totalMinutes.value, total < max(m.prepMinutes.value ?? 0,m.cookMinutes.value ?? 0) { m.totalMinutes = .init() }
        m.allergenHints = Array(Set(m.allergenHints.filter { Allergen(rawValue: $0) != nil })).sorted()
        return m
    }
    static func construct(_ value: RecipeExtraction, raw: String) -> RecipeExtraction? {
        var copy = value
        if let metadata = copy.metadata { copy.metadata = normalize(metadata, raw: raw, polished: copy.editorialVersion == 3) }
        for i in copy.components.indices {
            let quantity = #"(?:\d+(?:[./]\d+)?|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|quarter|half)"#
            let unit = #"(?:(?:tablespoons?|tbsp|teaspoons?|tsp|cups?|cloves?|oz|ounces?|g|grams?|kg|ml|lb|pounds?)\s+)?"#
            let word = #"(?!(?:and|or|until|then|with|to|for|add|cook|boil|mix|blend|minutes?|hours?|servings?|people)\b)[a-z]+"#
            let pattern = #"\b"# + quantity + #"\s+"# + unit + word + #"(?:\s+"# + word + "){0,2}"
            for step in copy.components[i].steps {
                for match in RecipeEditorialEvidence.matches(pattern, step) {
                    let line = match[0]
                    guard RecipeSourceEvidence.grounded(line, raw: raw, kind: .ingredient) else { continue }
                    let identity = RecipeSourceEvidence.tokens(line).filter { !($0.hasPrefix("n") && $0.dropFirst().first?.isNumber == true) && !["cup","tbsp","tsp","clove","oz","g","kg","ml","lb"].contains($0) }
                    if let j = copy.components[i].ingredients.firstIndex(where: { ingredient in identity.allSatisfy { RecipeSourceEvidence.tokens(ingredient).contains($0) } }) {
                        if !RecipeSourceEvidence.tokens(copy.components[i].ingredients[j]).contains(where: { $0.hasPrefix("n") && $0.dropFirst().first?.isNumber == true }) { copy.components[i].ingredients[j] = line }
                    } else { copy.components[i].ingredients.append(line) }
                }
            }
        }
        if ["unknown","not provided","none"].contains(copy.source?.lowercased() ?? "") { copy.source = nil }
        if copy.components.count == 1 { copy.components[0].title = nil }
        var ordered: [Int] = [], pending = Array(copy.components.indices)
        while !pending.isEmpty {
            guard let next = pending.first(where: { i in
                let after = copy.components[i].after ?? []
                return after.count <= 20 && after.allSatisfy { $0 >= 0 && $0 < copy.components.count && $0 != i && ordered.contains($0) }
            }) else { return nil }
            pending.removeAll { $0 == next }; ordered.append(next)
        }
        copy.components = ordered.map { i in
            var p = copy.components[i]; var seen = Set<String>()
            p.ingredients = p.ingredients.filter { line in
                if RecipeSourceEvidence.tokens(line).contains(where: { $0.hasPrefix("n") && $0.dropFirst().first?.isNumber == true }) { return true }
                return seen.insert(RecipeImportValidation.normalized(line)).inserted
            }
            p.after = []; return p
        }
        return copy
    }
}
