import Foundation

nonisolated enum RecipeUnitMode: String, CaseIterable, Identifiable {
    case original = "As Written", us = "US", metric = "Metric"
    var id: String { rawValue }
}

/// Reader-only values, never saved. Cross-dimension conversion requires an explicit ingredient mapping.
/// US customary factors, rounded for cooking and marked approximate.
/// https://www.nist.gov/pml/owm/metric-si/unit-conversion/approximate-conversions-us-customary-measures-metric
nonisolated enum RecipeUnits {
    // V1: retained for post-release improvements, absent from normal Recipe UI.
    static let showsControl = false
    private static let factors: [String: (volume: Bool, metric: Decimal)] = [
        "tsp": (true, Decimal(string: "4.92892159375")!), "tbsp": (true, Decimal(string: "14.78676478125")!),
        "cup": (true, Decimal(string: "236.5882365")!), "fl oz": (true, Decimal(string: "29.5735295625")!),
        "mL": (true, 1), "L": (true, 1000), "oz": (false, Decimal(string: "28.349523125")!),
        "lb": (false, Decimal(string: "453.59237")!), "g": (false, 1), "kg": (false, 1000)
    ]
    private static func unit(_ text: String) -> String? {
        if ["fl oz", "fluid ounce", "fluid ounces"].contains(text.lowercased()) { return "fl oz" }
        return IngredientUnit.canonical(text)
    }
    private static func quantity(_ text: String) -> (IngredientQuantity, String)? {
        if let q = IngredientQuantity.parse(text) { return (q, "") }
        for prefix in ["approximately ", "approx. ", "about ", "≈ ", "≈", "~"] where text.lowercased().hasPrefix(prefix) {
            if let q = IngredientQuantity.parse(String(text.dropFirst(prefix.count))) { return (q, String(text.prefix(prefix.count))) }
        }
        return nil
    }
    static func ingredient(_ original: RecipeIngredient, mode: RecipeUnitMode, base: Int?, servings: Int?) -> RecipeIngredient {
        if mode == .original && servings == nil { return original }
        // Older/manual rows may keep a complete measured line in name or quantity.
        // Reuse the accepted parser only for an unambiguous reader projection.
        var original = original
        if original.unit.isEmpty && quantity(original.quantity) == nil {
            let parsed = IngredientParser.parse([original.quantity, original.name].filter { !$0.isEmpty }.joined(separator: " "))
            if parsed.confidence == .high, parsed.quantity != nil, unit(parsed.unit) != nil {
                original.quantity = parsed.quantity!.canonical; original.unit = parsed.unit; original.name = parsed.name
                original.preparation = [original.preparation, parsed.preparation].filter { !$0.isEmpty }.joined(separator: ", ")
                original.note = [original.note, parsed.note].filter { !$0.isEmpty }.joined(separator: ", ")
            }
        }
        guard let (quantity, prefix) = quantity(original.quantity),
              ![original.quantity,original.unit,original.name,original.preparation,original.note].contains(where: {
                  $0.range(of: #"(?i)\b(to taste|as needed|per[- ]person|per[- ]serving|each serving)\b"#, options: .regularExpression) != nil
              }) else { return original }
        let scaled: IngredientQuantity
        if let base, let servings {
            guard let result = RecipeScaling.scaled(quantity, from: base, to: servings) else { return original }; scaled = result
        } else { scaled = quantity }
        var row = original; row.quantity = prefix + scaled.canonical
        guard mode != .original, let source = unit(row.unit), let factor = factors[source] else { return row }
        let isMetric = ["mL","L","g","kg"].contains(source)
        let density = RecipeIngredientMeasures.gramsPerUSCup(row)
        let crossDimension = density != nil && ((mode == .us && !factor.volume) || (mode == .metric && factor.volume))
        guard crossDimension || (mode == .metric) != isMetric else { return row }
        func decimal(_ value: IngredientNumber) -> Decimal {
            let amount = Decimal(value.numerator) / Decimal(value.denominator) * factor.metric
            guard crossDimension, let density else { return amount }
            return factor.volume ? amount / factors["cup"]!.metric * density : amount / density * factors["cup"]!.metric
        }
        let volume = crossDimension ? !factor.volume : factor.volume
        let low = decimal(scaled.lower), high = scaled.upper.map(decimal)
        let largest = high ?? low
        let target: String
        if mode == .metric { target = volume ? (largest >= 1000 ? "L" : "mL") : (largest >= 1000 ? "kg" : "g") }
        else if volume { target = largest >= factors["cup"]!.metric / 4 ? "cup" : largest >= factors["tbsp"]!.metric ? "tbsp" : "tsp" }
        else { target = largest >= factors["lb"]!.metric ? "lb" : "oz" }
        let divisor = factors[target]!.metric
        func formatted(_ amount: Decimal) -> String {
            let value = amount / divisor
            let places = (target == "mL" || target == "g") && value >= 10 ? 0 : 2
            var input = value, output = Decimal(); NSDecimalRound(&output, &input, places, .plain)
            // Preserve positive tiny values rather than rounding them away.
            if output == 0 && value > 0 { return NSDecimalNumber(decimal: value).stringValue }
            if ["cup","tbsp","tsp","lb"].contains(target) {
                let whole = NSDecimalNumber(decimal: output).intValue
                let rest = output - Decimal(whole)
                for (fraction, glyph) in [(Decimal(string: "0.125")!, "⅛"),(Decimal(string: "0.25")!, "¼"),(Decimal(string: "0.333333")!, "⅓"),(Decimal(string: "0.5")!, "½"),(Decimal(string: "0.666667")!, "⅔"),(Decimal(string: "0.75")!, "¾")] {
                    if abs(rest - fraction) < Decimal(string: "0.005")! { return (whole > 0 ? String(whole) : "") + glyph }
                }
            }
            return NSDecimalNumber(decimal: output).stringValue
        }
        row.unit = target; row.quantity = "≈ " + formatted(low) + (high.map { "–" + formatted($0) } ?? "")
        return row
    }
    static func content(_ value: RecipeContent, mode: RecipeUnitMode, servings: Int?) -> RecipeContent {
        var result = value
        let base = RecipeScaling.canonicalServings(value.yield)
        result.components = value.orderedComponents.map { part in
            var part = part; part.ingredients = part.ingredients.map { ingredient($0, mode: mode, base: base, servings: servings) }; return part
        }
        if base != nil, let servings, (1...100).contains(servings) { result.yield = "\(servings) servings" }
        return result
    }
}
