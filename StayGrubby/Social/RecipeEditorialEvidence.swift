import Foundation

/// Transient, bounded source obligations, aligned with the Edge editorial contract.
/// This preserves qualifiers without replacing professionally edited method prose.
nonisolated enum RecipeEditorialEvidence {
    struct Lock { var identity: String; var prefix: String?; var suffix: String?; var method = false }
    static func matches(_ pattern: String, _ raw: String) -> [[String]] {
        guard let r = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        return r.matches(in: raw, range: NSRange(raw.startIndex..., in: raw)).map { m in
            (0..<m.numberOfRanges).map { Range(m.range(at: $0), in: raw).map { String(raw[$0]) } ?? "" }
        }
    }
    static func locks(_ raw: String) -> [Lock] {
        let end = #"(?=[,.;\n]|\b(?:or|and|add|blend|cook|boil|mix|top|put|take|heat|until)\b|$)"#
        var result = matches(#"\b(a little|some|optional|maybe)\s+([a-z][a-z -]{0,70}?)\s*"# + end, raw).map { Lock(identity: $0[2].trimmingCharacters(in: .whitespaces), prefix: $0[1]) }
        result += matches(#"\b([a-z]+(?:\s+[a-z]+){0,2})\s+(to taste|if (?:you )?(?:want(?: spice)?|desired)|per (?:person|serving))\b"#, raw).map { Lock(identity: $0[1].replacingOccurrences(of: #"^.*\b(?:and|with|or)\b"#, with: "", options: [.regularExpression,.caseInsensitive]).trimmingCharacters(in: .whitespaces), suffix: $0[2]) }
        result += matches(#"\b(about|approximately)\s+((?:(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)|\d+(?:\.\d+)?)\s+(?:minutes?|mins?|hours?|hrs?))\b"#, raw).map { Lock(identity: $0[2], prefix: $0[1], method: true) }
        return result
    }
    struct Field { var part: Int; var index: Int; var method: Bool }
    static func preserve(_ value: RecipeExtraction, raw: String) -> RecipeExtraction? {
        var copy = value
        let fields = copy.components.enumerated().flatMap { p, c in
            c.ingredients.indices.map { Field(part: p, index: $0, method: false) } + c.steps.indices.map { Field(part: p, index: $0, method: true) }
        }
        func get(_ f: Field) -> String { f.method ? copy.components[f.part].steps[f.index] : copy.components[f.part].ingredients[f.index] }
        func set(_ f: Field, _ s: String) { if f.method { copy.components[f.part].steps[f.index] = s } else { copy.components[f.part].ingredients[f.index] = s } }
        func weight(_ f: Field) -> Int { (f.method ? 1 : 0) + (RecipeSourceEvidence.tokens(get(f)).contains { $0.hasPrefix("n") && $0.dropFirst().first?.isNumber == true } ? 1 : 0) }
        let sourceLocks = locks(raw)
        guard sourceLocks.count <= 200 else { return nil } // Fail closed, never truncate evidence.
        for lock in sourceLocks {
            let identity = RecipeSourceEvidence.tokens(lock.identity)
            if identity.isEmpty { continue }
            let candidates = fields.filter { f in (!lock.method || f.method) && identity.allSatisfy { RecipeSourceEvidence.tokens(get(f)).contains($0) } }.sorted { weight($0) < weight($1) }
            let marker = lock.prefix ?? lock.suffix!
            let markerTokens = RecipeSourceEvidence.editorialTokens(marker, raw: raw, kind: .step)
            if candidates.contains(where: { f in
                markerTokens.allSatisfy { RecipeSourceEvidence.editorialTokens(get(f), raw: raw, kind: .step).contains($0) } &&
                (marker.range(of: "some|about|approximately", options: [.regularExpression,.caseInsensitive]) == nil || get(f).range(of: "\\b" + (marker.lowercased() == "about" || marker.lowercased() == "approximately" ? "(?:about|approximately)" : NSRegularExpression.escapedPattern(for: marker)) + "\\b", options: [.regularExpression,.caseInsensitive]) != nil)
            }) { continue }
            guard let f = candidates.first else { return nil }
            if let prefix = lock.prefix {
                let pattern = "\\b" + lock.identity.split(separator: " ").map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: "\\s+") + "\\b"
                if get(f).range(of: pattern, options: [.regularExpression,.caseInsensitive]) != nil {
                    set(f, RecipeSourceEvidence.replacing(get(f), pattern: pattern) { prefix + " " + $0 })
                } else if lock.method {
                    guard let span = matches(#"\b(?:\d+(?:\.\d+)?|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s+(?:minutes?|mins?|hours?|hrs?)\b"#, get(f)).first?.first, RecipeSourceEvidence.tokens(span) == identity else { return nil }
                    set(f, get(f).replacingOccurrences(of: span, with: prefix + " " + span))
                } else if !f.method { set(f, prefix + " " + get(f)) }
                else { return nil }
            } else {
                var text = get(f); if text.hasSuffix(".") { text.removeLast() }
                set(f, text + " (" + lock.suffix! + ")" + (f.method ? "." : ""))
            }
        }
        let output = RecipeSourceEvidence.editorialTokens(fields.map(get).joined(separator: "\n"), raw: raw, kind: .step)
        for word in RecipeSourceEvidence.tokens(raw) {
            let numeric = word.hasPrefix("n") && word.dropFirst().first?.isNumber == true
            if (numeric || ["cold","cubed","fresh","minced","chopped","grated","peeled","trimmed","softened"].contains(word)) && !output.contains(word) { return nil }
        }
        let separator = #"[.,;:\n]|\b(?:add|blend|cook|boil|mix|top|take|with|and)\b"#
        let clauses = raw.replacingOccurrences(of: separator, with: "\n", options: [.regularExpression,.caseInsensitive]).components(separatedBy: "\n")
        for clause in clauses where clause.range(of: #"\bor\b"#, options: [.regularExpression,.caseInsensitive]) != nil {
            let group = clause.replacingOccurrences(of: #"\bif\b.*$"#, with: "", options: [.regularExpression,.caseInsensitive])
            let wanted = RecipeSourceEvidence.tokens(group).filter { !["little","optional","maybe"].contains($0) }
            if !wanted.isEmpty && !fields.contains(where: { f in wanted.allSatisfy { RecipeSourceEvidence.tokens(get(f)).contains($0) } }) { return nil }
        }
        return copy
    }
}
