import Foundation

/// Reader-only projection. No provider calls, unit conversion or writes to canonical content.
nonisolated enum RecipeScaling {
    static func canonicalServings(_ yield: String?) -> Int? {
        guard let yield else { return nil }
        let text = yield.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let count = Int(text), (1...100).contains(count) { return count }
        let patterns = [#"^(?:serves|servings\s*:?)\s+(\d{1,3})(?:\s+(?:servings|people|portions))?$"#,
                        #"^(?:makes\s+)?(\d{1,3})\s+(?:servings|people|portions)$"#]
        for pattern in patterns {
            if let values = IngredientParser.capture(pattern, text), let count = Int(values[0]), (1...100).contains(count) { return count }
        }
        return nil
    }
    static func scaled(_ quantity: IngredientQuantity, from base: Int, to target: Int) -> IngredientQuantity? {
        guard (1...100).contains(base), (1...100).contains(target) else { return nil }
        func scale(_ number: IngredientNumber) -> IngredientNumber? {
            // Int64-sized intermediate bounds; the existing rational initializer rejects oversized results.
            IngredientNumber(number.numerator * target, number.denominator * base)
        }
        guard let low = scale(quantity.lower) else { return nil }
        if let upper = quantity.upper {
            guard let high = scale(upper) else { return nil }
            return .init(lower: low, upper: high)
        }
        return .init(lower: low)
    }
    static func ingredient(_ row: RecipeIngredient, from base: Int, to target: Int) -> RecipeIngredient {
        guard base != target, let quantity = IngredientQuantity.parse(row.quantity),
              ![row.quantity, row.unit, row.name, row.note, row.preparation].contains(where: {
                  $0.range(of: #"(?i)\b(to taste|as needed|per[- ]person|per[- ]serving|each serving)\b"#, options: .regularExpression) != nil
              }), let scaled = scaled(quantity, from: base, to: target) else { return row }
        var copy = row; copy.quantity = scaled.canonical; return copy
    }
    static func content(_ content: RecipeContent, servings: Int?) -> RecipeContent {
        guard let base = canonicalServings(content.yield), let servings, (1...100).contains(servings), servings != base else { return content }
        var copy = content
        copy.components = content.orderedComponents.map { part in
            var part = part; part.ingredients = part.ingredients.map { ingredient($0, from: base, to: servings) }; return part
        }
        copy.yield = "\(servings) servings"
        return copy
    }
}
