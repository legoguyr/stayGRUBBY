import Foundation

/// Import-only, bounded lexical normalization. Never changes the accepted IngredientParser grammar.
nonisolated enum RecipeSourceEvidence {
    static let aliases: [String:String] = ["tablespoon": "tbsp", "tablespoons": "tbsp", "tbsp": "tbsp", "tbs": "tbsp", "teaspoon": "tsp", "teaspoons": "tsp", "tsp": "tsp", "cup": "cup", "cups": "cup", "oz": "oz", "ounce": "oz", "ounces": "oz", "lb": "lb", "lbs": "lb", "pound": "lb", "pounds": "lb", "g": "g", "gram": "g", "grams": "g", "kg": "kg", "kilogram": "kg", "kilograms": "kg", "ml": "ml", "milliliter": "ml", "milliliters": "ml", "millilitre": "ml", "millilitres": "ml", "l": "l", "liter": "l", "liters": "l", "litre": "l", "litres": "l", "clove": "clove", "cloves": "clove", "minute": "min", "minutes": "min", "min": "min", "mins": "min", "hour": "hour", "hours": "hour", "hr": "hour", "hrs": "hour", "pinch": "pinch", "pinches": "pinch", "fahrenheit": "f", "celsius": "c", "salted": "salt", "blanche": "blanch", "blanched": "blanch", "blanching": "blanch", "boiling": "boil", "boiled": "boil", "cooking": "cook", "cooked": "cook", "baking": "bake", "baked": "bake", "blending": "blend", "blended": "blend", "mixing": "mix", "mixed": "mix", "crispy": "crisp", "till": "until"]
    static let numbers: [String:String] = ["one": "1", "two": "2", "three": "3", "four": "4", "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10", "eleven": "11", "twelve": "12"]
    static let stops = Set(["a", "an", "the", "of", "to", "with", "in", "into", "on", "it", "its", "is", "are", "be", "by", "for", "then", "and", "some", "about", "this", "that", "your", "as"])
    static let preparation = Set(["cubed", "cold", "fresh", "minced", "chopped", "grated", "peeled", "trimmed", "softened", "finely", "roughly", "small", "large"])
    static let units = Set(["tbsp", "tsp", "cup", "oz", "lb", "g", "kg", "ml", "l", "clove", "min", "hour", "f", "c"])

    enum Kind { case metadata, title, ingredient, step }
    static func replacing(_ text: String, pattern: String, transform: (String) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return text }
        var value = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let original = Range(match.range, in: text), let range = Range(match.range, in: value) else { continue }
            value.replaceSubrange(range, with: transform(String(text[original])))
        }
        return value
    }
    static func ingredientLine(_ input: String) -> String {
        var text = input.replacingOccurrences(of: "¼", with: " 1/4 ").replacingOccurrences(of: "½", with: " 1/2 ").replacingOccurrences(of: "¾", with: " 3/4 ")
        text = replacing(text, pattern: #"\b(?:a |one )?quarter\b"#) { _ in "1/4" }
        text = replacing(text, pattern: #"\b(?:a |one )?half\b"#) { _ in "1/2" }
        text = replacing(text, pattern: #"\b(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b"#) { numbers[$0.lowercased()] ?? $0 }
        return text.replacingOccurrences(of: #"\b(\d+) and (?:a )?(1/2|1/4)\b"#, with: "$1 $2", options: .regularExpression)
    }
    static func tokens(_ input: String) -> [String] {
        let text = ingredientLine(input).lowercased().replacingOccurrences(of: #"\bdegrees?\s+(?:fahrenheit|f)\b"#, with: "f", options: .regularExpression).replacingOccurrences(of: #"\bdegrees?\s+(?:celsius|c)\b"#, with: "c", options: .regularExpression)
        let regex = try! NSRegularExpression(pattern: #"\d+\s+\d+/\d+|\d+(?:/\d+|\.\d+)?|[a-z]+"#)
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let word = String(text[range]); let token: String
            if let q = IngredientQuantity.parse(word), q.upper == nil { token = "n\(q.lower.numerator)/\(q.lower.denominator)" }
            else { token = aliases[word] ?? word }
            return stops.contains(token) ? nil : token
        }
    }
    static func contains(_ source: [String], _ value: [String]) -> Bool {
        !value.isEmpty && (" " + source.joined(separator: " ") + " ").contains(" " + value.joined(separator: " ") + " ")
    }
    static func grounded(_ value: String, raw: String, kind: Kind) -> Bool {
        if case .ingredient = kind, value.range(of: #"^\s*-\s*\d|\b\d+\s*/\s*0\b"#, options: .regularExpression) != nil { return false }
        let source = tokens(raw), output = tokens(value)
        guard !output.isEmpty else { return false }
        if contains(source, output) { return true }
        guard output.allSatisfy({ source.contains($0) }) else { return false }
        for i in output.indices where output[i].hasPrefix("n") && output[i].dropFirst().first?.isNumber == true {
            if i+1 < output.count && units.contains(output[i+1]) && !contains(source, Array(output[i...i+1])) { return false }
        }
        switch kind {
        case .metadata: return false
        case .title, .step: return true
        case .ingredient:
            let core = output.filter { !preparation.contains($0) }, origin = source.filter { !preparation.contains($0) }
            if contains(origin, core) { return true }
            if core.count > 2, core[0].hasPrefix("n"), units.contains(core[1]) { return contains(origin, Array(core.dropFirst(2))+Array(core.prefix(2))) }
            return false
        }
    }
}
