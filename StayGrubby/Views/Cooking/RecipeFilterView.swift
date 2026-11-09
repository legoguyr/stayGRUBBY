import SwiftUI

/// Food Bible's single Filters sheet.
/// One Recipe filter group, opened directly from its chip in `SGFilterGroupSheet` (same as Grub Rank).
struct RecipeFilterView: View {
    @Binding var filters: RecipeFilters
    let group: RecipeFilterGroup
    let entries: [CookbookEntry]
    @State private var search = ""
    var body: some View {
        SGFilterGroupPage(title: group.rawValue, isActive: filters.count(group) > 0, clear: clear, clearIdentifier: "bible-filter-clear") {
            switch group {
            case .course:
                option("Not specified", RecipeFilters.unspecified, $filters.courses)
                ForEach(CookingProductOptions.courses) { option($0.label, $0.rawValue, $filters.courses) }
            case .cuisine, .source:
                SGSearchField(placeholder: "Search \(group.rawValue.lowercased())", text: $search, identifier: "bible-filter-search")
                option("Not specified", RecipeFilters.unspecified, selection)
                ForEach(values.filter { CookbookSearch.matches($0, query: search) }, id: \.self) { option($0, $0, selection) }
            case .diet:
                // Same Diet rows as Grub Rank/cook editing (`DietaryChoices`), Diet only for Recipes.
                DietaryChoices(selection: Binding(get: { Set(filters.diets.compactMap(DietaryTag.init(rawValue:))) },
                                                  set: { filters.diets = Set($0.map(\.rawValue)) }), dietOnly: true)
                SGOptionNote("Diet as written by the Recipe. Check product labels when you cook.")
            case .cooked:
                option("Cooked", RecipeFilters.cookedValue, $filters.cooked)
                option("Not cooked yet", RecipeFilters.notCookedValue, $filters.cooked)
                SGOptionNote("Cooked means the Recipe’s Dish has at least one cook in your Grub Rank.")
            case .contains, .avoid:
                SGAllergenChoices(selection: allergenSelection, identifierPrefix: group == .contains ? "bible-contains" : "bible-avoid")
                SGOptionNote(group == .avoid ? "Excludes listed Contains or Possible matches. Missing information is not an allergen-free guarantee." : RecipeAllergenAssessment.safetyText)
            }
        }
    }
    private var selection: Binding<Set<String>> { group == .cuisine ? $filters.cuisines : $filters.sources }
    private var values: [String] { Array(Set(entries.compactMap { group == .cuisine ? $0.cuisine : $0.source }.filter { !$0.isEmpty })).sorted { $0.localizedStandardCompare($1) == .orderedAscending } }
    private var allergenSelection: Binding<Set<Allergen>> {
        Binding(get: { Set((group == .contains ? filters.contains : filters.avoid).compactMap(Allergen.init(rawValue:))) }, set: {
            if group == .contains { filters.contains = Set($0.map(\.rawValue)) } else { filters.avoid = Set($0.map(\.rawValue)) }
        })
    }
    private func option(_ title: String, _ id: String, _ selection: Binding<Set<String>>) -> some View {
        SGSelectionRow(title: title, selected: selection.wrappedValue.contains(id)) {
            if selection.wrappedValue.contains(id) { selection.wrappedValue.remove(id) } else { selection.wrappedValue.insert(id) }
        }.accessibilityIdentifier("bible-filter-option-\(id)")
    }
    private func clear() {
        switch group { case .course: filters.courses = []; case .cuisine: filters.cuisines = []; case .source: filters.sources = []; case .contains: filters.contains = []; case .avoid: filters.avoid = []; case .cooked: filters.cooked = []; case .diet: filters.diets = [] }
    }
}
