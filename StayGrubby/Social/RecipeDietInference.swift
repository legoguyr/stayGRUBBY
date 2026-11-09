import Foundation

/// Recipe Diet "as written", suggested from ingredient evidence when a Recipe is imported/organized
/// (FOOD_ARCHITECTURE §5, owner decision Nov 9). Deterministic and conservative: a tag is suggested only
/// when every ingredient line is free of the excluded foods and of anything ambiguous (stock, sauces,
/// seasoning blends, rennet cheeses, plain flour, oats…). Unknown stays unknown. Kosher and Halal are
/// never inferred (they depend on products, supervision and kitchen). The user can always edit the result.
nonisolated enum RecipeDietInference {
    private static let meat = #"\b(?:chicken|beef|pork|lamb|veal|mutton|goat|venison|bacon|ham|prosciutto|pancetta|guanciale|sausages?|chorizo|salami|pepperoni|turkey|duck|goose|steaks?|mince|meatballs?|meat|lard|suet|gelatin|gelatine|bone broth|oxtail|liver|anchov(?:y|ies)|fish sauce)\b"#
    private static let fish = RecipeAllergenAssessment.rules["fish"]!
    private static let shellfish = RecipeAllergenAssessment.rules["shellfish"]!
    private static let dairy = RecipeAllergenAssessment.rules["milk"]!
    private static let plantDairy = #"\b(?:almond|soy|soya|oat|rice|coconut|cashew|plant|vegan|dairy[- ]free|non[- ]dairy|nut)\b[^,;]*\b(?:milk|butter|cream|cheese|yogurt|yoghurt)\b"#
    private static let egg = RecipeAllergenAssessment.rules["egg"]!
    private static let honey = #"\b(?:honey)\b"#
    /// Not clearly meat-free (could be animal-derived): blocks Vegetarian and Vegan.
    private static let vegetarianUnclear = #"\b(?:stock|broth|bouillon|consomm[eé]|worcestershire|rennet|parmesan|parmigiano|pecorino|grana padano|gorgonzola|bouillon cubes?)\b"#
    private static let vegetableStock = #"\b(?:vegetable|veggie|mushroom|vegan)\b[^,;]*\b(?:stock|broth|bouillon)\b"#
    /// Not clearly dairy-free: blocks Dairy-Free and Vegan.
    private static let dairyUnclear = #"\b(?:chocolate|caramel|pesto|creamy|naan|brioche|margarine)\b"#
    private static let gluten = #"\b(?:wheat|semolina|bulgur|couscous|seitan|barley|rye|spelt|farro|malt|bread|breadcrumbs|panko|pasta|spaghetti|noodles|orzo|ramen|udon|tortillas?|pita|crackers?|beer|biscuits?|cake|pastry|phyllo|filo)\b"#
    private static let glutenUnclear = #"\b(?:flour|soy sauce|shoyu|oats?|stock|broth|bouillon|seasoning|spice mix|sauce|worcestershire|miso|teriyaki|hoisin|gravy|batter)\b"#
    private static let glutenFreeQualified = #"\b(?:gluten[- ]free|tamari|rice flour|almond flour|corn ?flour|cornstarch|chickpea flour|coconut flour|buckwheat|tapioca|potato starch|rice noodles|corn tortillas?)\b"#

    static func derive(_ lines: [String]) -> Set<DietaryTag> {
        let rows = lines.map { $0.lowercased() }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !rows.isEmpty else { return [] }
        func any(_ pattern: String, unless exempt: String? = nil) -> Bool {
            rows.contains { row in
                row.range(of: pattern, options: .regularExpression) != nil
                    && !(exempt.map { row.range(of: $0, options: .regularExpression) != nil } ?? false)
            }
        }
        let hasMeatOrFish = any(meat) || any(fish) || any(shellfish)
        let vegetarianBlocked = hasMeatOrFish || any(vegetarianUnclear, unless: vegetableStock)
        let dairyBlocked = any(dairy, unless: plantDairy) || any(dairyUnclear)
        let veganBlocked = vegetarianBlocked || dairyBlocked || any(egg) || any(honey)
        let glutenBlocked = any(gluten, unless: glutenFreeQualified) || any(glutenUnclear, unless: glutenFreeQualified)
        var tags = Set<DietaryTag>()
        if !vegetarianBlocked { tags.insert(.vegetarian) }
        if !veganBlocked { tags.insert(.vegan) }
        if !dairyBlocked { tags.insert(.dairyFree) }
        if !glutenBlocked { tags.insert(.glutenFree) }
        return tags
    }
}
