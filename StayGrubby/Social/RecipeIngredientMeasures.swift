import Foundation

/// Approximate grams per US cup. Exact, curated aliases only; never a universal density.
/// Add new ingredients here with a primary source and preparation-specific limits.
nonisolated enum RecipeIngredientMeasures {
    // RiceSelect Arborio: 1/4 US cup dry = 45 g.
    // Product: https://www.riceselect.com/products/arborio
    // Label: https://www.shoprite.com/sm/planning/rsid/814/product/riceselect-arborio-italianstyle-rice-32-oz-id-00074401910411
    // King Arthur ingredient weight chart: US cups (honey/cocoa scaled from tbsp/half cup).
    // https://www.kingarthurbaking.com/learn/ingredient-weight-chart
    private static let measures: [(grams: Decimal, aliases: Set<String>)] = [
        (180, ["arborio rice", "risotto rice", "arborio risotto rice"]),
        (120, ["all purpose flour", "unbleached all purpose flour", "ap flour", "bread flour"]),
        (198, ["granulated sugar", "white granulated sugar", "granulated white sugar"]),
        (227, ["butter", "unsalted butter", "salted butter"]),
        (336, ["honey"]),
        (84, ["cocoa powder", "unsweetened cocoa powder", "dutch process cocoa powder", "natural cocoa powder"])
    ]
    static func gramsPerUSCup(_ row: RecipeIngredient) -> Decimal? {
        let qualifiers = row.name + " " + row.preparation
        guard qualifiers.range(of: #"(?i)\b(cooked|cooking|prepared|puffed|ground|sifted|packed|browned|whipped|heaping|heaped)\b"#, options: .regularExpression) == nil else { return nil }
        var name = row.name.folding(options: [.caseInsensitive,.diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        name = name.replacingOccurrences(of: #"[-/]"#, with: " ", options: .regularExpression)
        name = name.replacingOccurrences(of: #"\b(dry|uncooked)\b"#, with: "", options: .regularExpression)
        name = name.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return measures.first { $0.aliases.contains(name) }?.grams
    }
}
