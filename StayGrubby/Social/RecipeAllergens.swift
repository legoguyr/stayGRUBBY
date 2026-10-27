import Foundation

/// Ingredient information, never an absence/cross-contact or medical guarantee.
nonisolated struct RecipeAllergenAssessment: Codable, Equatable, Sendable {
    var contains: [String] = []
    var possible: [String] = []
    var reviewIngredients: [String] = []
    static let safetyText = "Ingredient-based information only. Optional ingredients, substitutions and product labels can change allergens. Not an allergen-free or cross-contact guarantee. Verify every ingredient."
    static let rules: [String:String] = [
        "milk": #"\b(?:milk|butter|cream|cheese|parmesan|yogurt|yoghurt|whey|casein|ghee)\b"#,
        "egg": #"\b(?:eggs?|mayonnaise|mayo|meringue)\b"#,
        "peanuts": #"\bpeanuts?\b"#,
        "treeNuts": #"\b(?:almonds?|walnuts?|pecans?|cashews?|pistachios?|hazelnuts?|macadamias?|brazil nuts?|pine nuts?)\b"#,
        "sesame": #"\b(?:sesame|tahini)\b"#,
        "soy": #"\b(?:soy|soya|tofu|edamame|miso|tempeh)\b"#,
        "fish": #"\b(?:fish|anchov(?:y|ies)|salmon|tuna|cod|haddock|sardines?|bass|trout)\b"#,
        "shellfish": #"\b(?:shellfish|shrimp|prawns?|crab|lobster|clams?|mussels?|oysters?|scallops?)\b"#,
        "wheat": #"\b(?:wheat|semolina|bulgur|couscous|seitan)\b"#
    ]
    static func derive(_ lines: [String], hints: [String] = []) -> Self {
        // Provider hints never create an unsupported allergen claim.
        let supported = hints.filter { code in rules[code].map { pattern in lines.contains { $0.range(of: pattern, options: [.regularExpression,.caseInsensitive]) != nil } } ?? false }
        var known = Set<String>(), possible = Set(supported), review = Set<String>()
        for line in lines {
            let lower = line.lowercased()
            let optional = lower.range(of: #"\b(?:or|optional|if desired|if you want|maybe)\b"#, options: .regularExpression) != nil
            for (code, pattern) in rules where lower.range(of: pattern, options: .regularExpression) != nil {
                let ambiguousMilk = code == "milk" && lower.range(of: #"(?:almond|soy|oat|rice|coconut|plant|vegan|dairy.free).*\b(?:milk|butter|cream|cheese)\b"#, options: .regularExpression) != nil
                if optional || ambiguousMilk { possible.insert(code) } else { known.insert(code) }
            }
            if lower.range(of: #"\b(?:pasta|flour|bread|breadcrumbs|soy sauce)\b"#, options: .regularExpression) != nil { possible.insert("wheat"); review.insert(line) }
            if lower.range(of: #"\b(?:sauce|stock|broth|spice mix|seasoning|uncertain|unknown)\b"#, options: .regularExpression) != nil { review.insert(line) }
            if optional { review.insert(line) }
        }
        possible.subtract(known)
        return .init(contains: known.sorted(), possible: possible.sorted(), reviewIngredients: review.sorted())
    }
}
