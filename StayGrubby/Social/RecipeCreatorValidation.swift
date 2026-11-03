import Foundation

/// Technical compatibility only. Gemini owns content; the user reviews it.
nonisolated enum RecipeCreatorValidation {
    static func normalize(_ m: RecipeCreatorMetadata, raw: String = "", polished: Bool = false) -> RecipeCreatorMetadata {
        var out = m
        func text(_ p: RecipeTextProposal, cuisine: Bool = false) -> RecipeTextProposal {
            guard let v = p.value, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, v.count <= 100 else { return .init() }
            let value: String
            if cuisine { guard let c = CuisineCatalog.predefined.first(where: { $0.label.lowercased() == v.lowercased() }) else { return .init() }; value = c.label } else { value = v }
            return .init(value: value, origin: p.origin == .unknown ? .estimated : p.origin, evidence: p.evidence.flatMap { $0.count <= 500 ? $0 : nil })
        }
        func time(_ p: RecipeTimeProposal) -> RecipeTimeProposal {
            guard let v = p.value, (0...10080).contains(v) else { return .init() }
            return .init(value: v, origin: p.origin == .unknown ? .estimated : p.origin, evidence: p.evidence.flatMap { $0.count <= 500 ? $0 : nil })
        }
        out.yield = text(m.yield); out.cuisine = text(m.cuisine, cuisine: true)
        out.prepMinutes = time(m.prepMinutes); out.cookMinutes = time(m.cookMinutes); out.totalMinutes = time(m.totalMinutes)
        if let total = out.totalMinutes.value, total < max(out.prepMinutes.value ?? 0,out.cookMinutes.value ?? 0) { out.totalMinutes = .init() }
        out.allergenHints = Array(Set(m.allergenHints.filter { Allergen(rawValue: $0) != nil })).sorted()
        return out
    }
    static func invalidQuantity(_ line: String) -> Bool {
        if line.range(of: #"^\s*-\s*\d|\b\d+\s*/\s*0\b|^\s*\d+(?:\.\d+)?e[+-]?\d+|^\s*(?:NaN|Infinity)\s+(?:cups?|tbsp|tsp|g|kg|ml|l)\b"#, options: [.regularExpression,.caseInsensitive]) != nil { return true }
        if let s = IngredientParser.capture(#"^\s*(\d+(?:\.\d+)?)"#,line)?.first, let n = Double(s), n > 1_000_000_000 { return true }
        return false
    }
    /// Representation-only quantity words at the start of a supplied ingredient.
    /// Never searches source/methods or infers an amount.
    static func ingredientLine(_ raw: String) -> String {
        var s = raw
        for (pattern,replacement) in [(#"^(?:a |one )?quarter\b"#,"1/4"),(#"^(?:a |one )?half\b"#,"1/2")] { s = s.replacingOccurrences(of: pattern, with: replacement, options: [.regularExpression,.caseInsensitive]) }
        for (i,word) in ["one","two","three","four","five","six","seven","eight","nine","ten","eleven","twelve"].enumerated() { s = s.replacingOccurrences(of: "^"+word+"\\b", with: String(i+1), options: [.regularExpression,.caseInsensitive]) }
        s = s.replacingOccurrences(of: #"^(\d+) and (?:a )?half\b"#, with: "$1 1/2", options: [.regularExpression,.caseInsensitive])
        return s
    }
    static func construct(_ value: RecipeExtraction, raw: String = "") -> RecipeExtraction? {
        guard (1...20).contains(value.components.count) else { return nil }
        var copy = value
        if let m = copy.metadata { copy.metadata = normalize(m) }
        if let d = copy.description, d.count > 1200 || d.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || d.range(of: #"[\x00-\x08\x0B\x0C\x0E-\x1F]"#, options: .regularExpression) != nil { copy.description = nil }
        var done: [Int] = []
        while done.count < copy.components.count {
            guard let i = copy.components.indices.first(where: { i in
                let a = copy.components[i].after ?? []
                return !done.contains(i) && a.count <= 20 && a.allSatisfy { $0 >= 0 && $0 < copy.components.count && $0 != i && done.contains($0) }
            }) else { return nil }
            done.append(i)
        }
        copy.components = done.map { i in var p = copy.components[i]; p.after = []; return p }
        return copy
    }
}

// Missing or unusable optional metadata cannot prevent a core Recipe draft.
extension RecipeTextProposal {
    private enum Keys: String, CodingKey { case value, origin, evidence }
    init(from decoder: Decoder) throws {
        self.init(); guard let c = try? decoder.container(keyedBy: Keys.self) else { return }
        value = try? c.decodeIfPresent(String.self, forKey: .value)
        origin = (try? c.decodeIfPresent(RecipeInformationOrigin.self, forKey: .origin)) ?? (value == nil ? .unknown : .estimated)
        evidence = try? c.decodeIfPresent(String.self, forKey: .evidence)
    }
}
extension RecipeTimeProposal {
    private enum Keys: String, CodingKey { case value, origin, evidence }
    init(from decoder: Decoder) throws {
        self.init(); guard let c = try? decoder.container(keyedBy: Keys.self) else { return }
        value = try? c.decodeIfPresent(Int.self, forKey: .value)
        origin = (try? c.decodeIfPresent(RecipeInformationOrigin.self, forKey: .origin)) ?? (value == nil ? .unknown : .estimated)
        evidence = try? c.decodeIfPresent(String.self, forKey: .evidence)
    }
}
extension RecipeCreatorMetadata {
    private enum Keys: String, CodingKey { case yield, prepMinutes, cookMinutes, totalMinutes, cuisine, allergenHints }
    init(from decoder: Decoder) throws {
        self.init(); guard let c = try? decoder.container(keyedBy: Keys.self) else { return }
        yield = (try? c.decodeIfPresent(RecipeTextProposal.self, forKey: .yield)) ?? .init()
        prepMinutes = (try? c.decodeIfPresent(RecipeTimeProposal.self, forKey: .prepMinutes)) ?? .init()
        cookMinutes = (try? c.decodeIfPresent(RecipeTimeProposal.self, forKey: .cookMinutes)) ?? .init()
        totalMinutes = (try? c.decodeIfPresent(RecipeTimeProposal.self, forKey: .totalMinutes)) ?? .init()
        cuisine = (try? c.decodeIfPresent(RecipeTextProposal.self, forKey: .cuisine)) ?? .init()
        allergenHints = (try? c.decodeIfPresent([String].self, forKey: .allergenHints)) ?? []
    }
}
extension RecipeExtraction {
    private enum Keys: String, CodingKey { case editorialVersion, title, description, yield, source, components, metadata }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        components = try c.decode([RecipeExtractionComponent].self, forKey: .components)
        editorialVersion = try c.decodeIfPresent(Int.self, forKey: .editorialVersion)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        description = try? c.decodeIfPresent(String.self, forKey: .description)
        yield = try c.decodeIfPresent(String.self, forKey: .yield)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        metadata = try? c.decodeIfPresent(RecipeCreatorMetadata.self, forKey: .metadata)
    }
}
