import SwiftUI

struct RecipeFilterView: View {
    @Binding var filters: RecipeFilters
    let group: RecipeFilterGroup
    let entries: [CookbookEntry]
    @State private var search = ""
    var body: some View {
        SGSelectionSheet(title: group.rawValue) {
            switch group {
            case .course:
                option("Not specified", RecipeFilters.unspecified, $filters.courses)
                ForEach(CookingProductOptions.courses) { option($0.label, $0.rawValue, $filters.courses) }
            case .cuisine, .source:
                SGSearchField(placeholder: "Search \(group.rawValue.lowercased())", text: $search, identifier: "bible-filter-search")
                option("Not specified", RecipeFilters.unspecified, selection)
                ForEach(values.filter { CookbookSearch.matches($0, query: search) }, id: \.self) { option($0, $0, selection) }
            case .contains, .avoid:
                SGAllergenChoices(selection: allergenSelection, identifierPrefix: group == .contains ? "bible-contains" : "bible-avoid")
                Text(group == .avoid ? "Excludes listed Contains or Possible matches. Missing information is not an allergen-free guarantee." : RecipeAllergenAssessment.safetyText)
                    .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            case .photo:
                SGSelectionRow(title: "Any photo", selected: filters.photo == nil) { filters.photo = nil }
                SGSelectionRow(title: "Recipe photo", selected: filters.photo == true) { filters.photo = true }
                SGSelectionRow(title: "No Recipe photo", selected: filters.photo == false) { filters.photo = false }
            }
            Button("Clear \(group.rawValue)") { clear() }.buttonStyle(SGButtonStyle()).accessibilityIdentifier("bible-filter-clear")
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
        switch group { case .course: filters.courses = []; case .cuisine: filters.cuisines = []; case .source: filters.sources = []; case .contains: filters.contains = []; case .avoid: filters.avoid = []; case .photo: filters.photo = nil }
    }
}
