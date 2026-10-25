import Foundation

/// Exact, bounded rational cooking quantities; no floating-point scaling or conversion.
nonisolated struct IngredientNumber: Equatable, Sendable {
    let numerator: Int
    let denominator: Int
    init?(_ numerator: Int, _ denominator: Int = 1) {
        guard numerator >= 0, denominator > 0, numerator <= 1_000_000_000, denominator <= 1_000_000 else { return nil }
        var a = numerator, b = denominator
        while b != 0 { (a,b) = (b,a % b) }
        self.numerator = numerator / max(a,1); self.denominator = denominator / max(a,1)
    }
    var canonical: String {
        let whole = numerator / denominator, rest = numerator % denominator
        if rest == 0 { return String(whole) }
        return (whole > 0 ? "\(whole) " : "") + "\(rest)/\(denominator)"
    }
    var display: String {
        let glyphs = ["1/2":"½","1/4":"¼","3/4":"¾","1/3":"⅓","2/3":"⅔","1/8":"⅛","3/8":"⅜","5/8":"⅝","7/8":"⅞"]
        let whole = numerator / denominator, rest = numerator % denominator
        guard let glyph = glyphs["\(rest)/\(denominator)"] else { return canonical }
        return (whole > 0 ? String(whole) : "") + glyph
    }
}
nonisolated struct IngredientQuantity: Equatable, Sendable {
    let lower: IngredientNumber
    var upper: IngredientNumber? = nil
    var canonical: String { lower.canonical + (upper.map { "-" + $0.canonical } ?? "") }
    var display: String { lower.display + (upper.map { "–" + $0.display } ?? "") }
    static func parse(_ input: String) -> Self? {
        let text = IngredientParser.trim(input).replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "—", with: "-")
        let range = text.replacingOccurrences(of: " to ", with: "-", options: .caseInsensitive).components(separatedBy: "-")
        guard (1...2).contains(range.count), let low = number(range[0]) else { return nil }
        if range.count == 1 { return .init(lower: low) }
        guard let high = number(range[1]), low.numerator * high.denominator <= high.numerator * low.denominator else { return nil }
        return .init(lower: low, upper: high)
    }
    private static func number(_ input: String) -> IngredientNumber? {
        var text = IngredientParser.trim(input)
        for (glyph,value) in ["½":"1/2","¼":"1/4","¾":"3/4","⅓":"1/3","⅔":"2/3","⅛":"1/8","⅜":"3/8","⅝":"5/8","⅞":"7/8"] {
            if text.hasSuffix(glyph) { text = String(text.dropLast()) + (text.count > 1 ? " " : "") + value; break }
        }
        if let match = IngredientParser.capture(#"^(?:(\d{1,6})\s+)?(\d{1,6})\s*/\s*(\d{1,6})$"#, text), let n = Int(match[1]), let d = Int(match[2]), d > 0 {
            let whole = Int(match[0]) ?? 0
            return IngredientNumber(whole*d+n,d)
        }
        if let match = IngredientParser.capture(#"^(\d{1,6})\.(\d{1,6})$"#, text), let whole = Int(match[0]), let part = Int(match[1]) {
            let denominator = (0..<match[1].count).reduce(1) { value,_ in value*10 }
            return IngredientNumber(whole*denominator+part,denominator)
        }
        guard text.range(of: #"^\d{1,6}$"#, options: .regularExpression) != nil, let n = Int(text) else { return nil }
        return IngredientNumber(n)
    }
}

nonisolated enum IngredientUnit {
    static let aliases: [String:String] = {
        let groups: [(String,[String])] = [
            ("tbsp",["tablespoon","tablespoons","tbsp","tbs"]), ("tsp",["teaspoon","teaspoons","tsp"]),
            ("cup",["cup","cups","c"]), ("oz",["ounce","ounces","oz"]), ("lb",["pound","pounds","lb","lbs"]),
            ("g",["gram","grams","g"]), ("kg",["kilogram","kilograms","kg"]),
            ("mL",["milliliter","milliliters","millilitre","millilitres","ml"]), ("L",["liter","liters","litre","litres","l"]),
            ("clove",["clove","cloves"]), ("bunch",["bunch","bunches"]), ("can",["can","cans"]),
            ("package",["package","packages","pkg","pkgs"]), ("stick",["stick","sticks"]), ("slice",["slice","slices"]),
            ("piece",["piece","pieces"]), ("head",["head","heads"]), ("sprig",["sprig","sprigs"]),
            ("pinch",["pinch","pinches"]), ("dash",["dash","dashes"])
        ]
        return Dictionary(uniqueKeysWithValues: groups.flatMap { canonical,words in words.map { ($0,canonical) } })
    }()
    static var pattern: String { aliases.keys.sorted { $0.count > $1.count }.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") }
    static func canonical(_ input: String) -> String? { aliases[input.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))] }
    static func display(_ input: String, quantity: String) -> String {
        guard let unit = canonical(input) else { return input }
        let plurals = ["clove":"cloves","bunch":"bunches","can":"cans","package":"packages","stick":"sticks","slice":"slices","piece":"pieces","head":"heads","sprig":"sprigs","pinch":"pinches","dash":"dashes"]
        if let q = IngredientQuantity.parse(quantity), q.upper != nil || q.lower.numerator == 0 || q.lower.numerator > q.lower.denominator { return plurals[unit] ?? unit }
        return unit
    }
}

nonisolated struct ParsedIngredient: Equatable, Sendable {
    enum Confidence: Equatable, Sendable { case high, ambiguous, freeform }
    let rawInput: String
    var quantity: IngredientQuantity?
    var unit = ""
    var name: String
    var preparation = ""
    var note = ""
    var confidence: Confidence
    func ingredient(id: UUID = UUID(), order: Int = 0) -> RecipeIngredient {
        .init(id: id, order: order, quantity: quantity?.canonical ?? "", unit: unit, name: name, preparation: preparation, note: note)
    }
}

/// Deliberately small grammar: boundary measurements, known units, suffix preparations/notes.
/// Unrecognized or ambiguous input remains a saveable ingredient, never an invented amount.
nonisolated enum IngredientParser {
    private static let atom = #"(?:\d{1,6}\s+\d{1,6}\s*/\s*\d{1,6}|\d{1,6}\s*[½¼¾⅓⅔⅛⅜⅝⅞]|\d{1,6}\s*/\s*\d{1,6}|\d{1,6}\.\d{1,6}|\d{1,6}|[½¼¾⅓⅔⅛⅜⅝⅞])"#
    private static let amount = atom + #"(?:\s*(?:-|–|—|to)\s*"# + atom + #")?"#
    private static let prefix = try! NSRegularExpression(pattern: "^(\(amount))\\s*(\(IngredientUnit.pattern))\\.?(?=\\s|$)\\s+(?:of\\s+)?(.+)$", options: .caseInsensitive)
    private static let suffix = try! NSRegularExpression(pattern: "^(.+?)[\\s,]+(\(amount))\\s*(\(IngredientUnit.pattern))\\.?$", options: .caseInsensitive)
    private static let barePrefix = try! NSRegularExpression(pattern: "^(\(amount))\\s+(.+)$", options: .caseInsensitive)
    private static let bareSuffix = try! NSRegularExpression(pattern: "^(.+?)[\\s,]+(\(amount))$", options: .caseInsensitive)
    private static let modifiers = #"(?:(?:finely|roughly|thinly|freshly)\s+)?(?:chopped|minced|diced|sliced|peeled|grated|shredded|crushed|melted|softened|divided|drained|rinsed|trimmed|zested|juiced)|room temperature"#
    private static let preparation = try! NSRegularExpression(pattern: "^(.+?)(?:,\\s*|\\s+)((?:\(modifiers))(?:\\s+and\\s+(?:\(modifiers)))*)$", options: .caseInsensitive)
    static func parse(_ raw: String) -> ParsedIngredient {
        let original = trim(raw)
        var result = ParsedIngredient(rawInput: raw, name: original, confidence: .freeform)
        guard !original.isEmpty, original.count <= 2000, !original.contains(where: { $0.isNewline }) else { return result }
        // Flat parentheticals are retained as notes. Nested/unbalanced forms stay verbatim.
        var text = original, notes: [String] = []
        if text.contains("(") || text.contains(")") {
            guard let regex = try? NSRegularExpression(pattern: #"\(([^()]*)\)"#) else { return result }
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches.reversed() {
                guard let range = Range(match.range, in: text), let inner = Range(match.range(at: 1), in: text) else { return result }
                notes.insert(String(text[inner]), at: 0); text.replaceSubrange(range, with: " ")
            }
            guard !text.contains("("), !text.contains(")") else { return result }
            text = trim(text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression))
        }
        var matched = false
        if let c = captures(prefix,text), let q = IngredientQuantity.parse(c[0]), let u = IngredientUnit.canonical(c[1]) {
            result.quantity = q; result.unit = u; text = c[2]; matched = true
        } else if let c = captures(suffix,text), let q = IngredientQuantity.parse(c[1]), let u = IngredientUnit.canonical(c[2]) {
            result.quantity = q; result.unit = u; text = trimSeparator(c[0]); matched = true
        } else if let c = captures(barePrefix,text), let q = IngredientQuantity.parse(c[0]) {
            // Numbered food names and size/percentage notation are not quantities.
            if capture(#"^\d+\s+(?:spice|grain|seed)(?:\b|\s)"#,text.lowercased()) != nil || c[0].hasPrefix("00") {
                result.confidence = .ambiguous; return result
            }
            result.quantity = q; text = c[1]; matched = true
        } else if let c = captures(bareSuffix,text), let q = IngredientQuantity.parse(c[1]), capture(#"(?:^|\s)(?:fillets|eggs|onions|carrots|lemons|limes|tomatoes)$"#,c[0].lowercased()) != nil {
            result.quantity = q; text = trimSeparator(c[0]); matched = true
        }
        // Invalid or unsupported measurement syntax must not be partially consumed.
        if !matched && original.first?.isNumber == true { result.confidence = .ambiguous; return result }
        if let c = capture(#"^(.+?)(?:,\s*|\s+)((?:to taste|as needed|optional|plus more\b.*))$"#,text, insensitive: true) {
            text = c[0]; notes.insert(c[1], at: 0)
        }
        if let c = captures(preparation,text) { text = c[0]; result.preparation = c[1] }
        // A comma after a meaningful ingredient is explicit secondary text, retained as a note.
        if let comma = text.firstIndex(of: ",") {
            let tail = trim(String(text[text.index(after: comma)...])); text = String(text[..<comma])
            if !tail.isEmpty { notes.insert(tail, at: 0) }
        }
        text = trimSeparator(text)
        guard !text.isEmpty else { return ParsedIngredient(rawInput: raw, name: original, confidence: .ambiguous) }
        result.name = text; result.note = notes.filter { !$0.isEmpty }.joined(separator: "; ")
        result.confidence = matched || !result.preparation.isEmpty || !result.note.isEmpty ? .high : .freeform
        return result
    }
    static func trim(_ input: String) -> String { input.trimmingCharacters(in: .whitespacesAndNewlines) }
    private static func trimSeparator(_ input: String) -> String {
        var value = trim(input).trimmingCharacters(in: CharacterSet(charactersIn: ","))
        if value.hasSuffix(" -") { value = String(value.dropLast(2)) }
        return trim(value)
    }
    static func capture(_ pattern: String, _ text: String, insensitive: Bool = false) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: insensitive ? .caseInsensitive : []) else { return nil }
        return captures(regex,text)
    }
    private static func captures(_ regex: NSRegularExpression, _ text: String) -> [String]? {
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex...,in:text)) else { return nil }
        return (1..<match.numberOfRanges).map { Range(match.range(at:$0),in:text).map { String(text[$0]) } ?? "" }
    }
}
nonisolated enum IngredientLineFormatter {
    static func editableLine(_ row: RecipeIngredient) -> String {
        let primary = [row.quantity,IngredientUnit.display(row.unit,quantity:row.quantity),row.name].filter { !$0.isEmpty }.joined(separator:" ")
        return primary + (row.preparation.isEmpty ? "" : ", " + row.preparation) + (row.note.isEmpty ? "" : " (" + row.note + ")")
    }
    static func accessibilityLine(_ row: RecipeIngredient) -> String {
        let singular = ["tbsp":"tablespoon","tsp":"teaspoon","cup":"cup","oz":"ounce","lb":"pound","g":"gram","kg":"kilogram","mL":"milliliter","L":"liter"]
        let unit = IngredientUnit.canonical(row.unit) ?? row.unit
        let q = IngredientQuantity.parse(row.quantity)
        let spokenUnit: String
        if let word = singular[unit] { spokenUnit = word + (q.map { $0.upper == nil && $0.lower.numerator > 0 && $0.lower.numerator <= $0.lower.denominator } == true ? "" : "s") }
        else { spokenUnit = IngredientUnit.display(row.unit,quantity:row.quantity) }
        return [[q?.display ?? row.quantity,spokenUnit,row.name].filter { !$0.isEmpty }.joined(separator:" "),row.preparation,row.note].filter { !$0.isEmpty }.joined(separator:", ")
    }
    static func amount(_ row: RecipeIngredient) -> String {
        [IngredientQuantity.parse(row.quantity)?.display ?? row.quantity,IngredientUnit.display(row.unit,quantity:row.quantity)].filter { !$0.isEmpty }.joined(separator:" ")
    }
}
