import SwiftUI
import SwiftData

nonisolated enum CookingFilterGroup: String, Identifiable, CaseIterable {
    case course, cuisine, dietary, avoid
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cuisine: "Cuisine"
        case .course: CookingProductOptions.courseTitle
        case .dietary: "Dietary"
        case .avoid: "Avoid"
        }
    }
    func count(in filters: CookingFilters) -> Int {
        switch self {
        case .course: filters.category == nil ? 0 : 1
        case .cuisine: filters.cuisineID == nil ? 0 : 1
        case .dietary: filters.dietary.count
        case .avoid: filters.avoidedAllergens.count
        }
    }
}

extension CookingFilters {
    var activeCount: Int { CookingFilterGroup.allCases.reduce(0) { $0 + $1.count(in: self) } }
}

/// One Grub Rank filter group, opened directly from its chip. Each group keeps its
/// existing semantics: Course and Cuisine single-select, Dietary matches any, Avoid excludes any.
struct CookingFilterGroupSheet: View {
    @Binding var filters: CookingFilters
    let group: CookingFilterGroup
    @Query private var dishes: [Dish]
    var body: some View {
        SGFilterGroupSheet {
            if group == .cuisine {
                CuisineOptions(selection: Binding(
                    get: { CuisineCatalog.options(saved: dishes.compactMap(\.cuisine)).first { $0.id == filters.cuisineID } },
                    set: { filters.cuisineID = $0?.id }), allowsCreation: false)
            } else {
                SGFilterGroupPage(title: group.title, isActive: group.count(in: filters) > 0,
                                  clear: clear, clearIdentifier: group == .avoid ? "clear-avoid" : "filter-group-clear") {
                    CookingFilterOptions(filters: $filters, group: group)
                }
            }
        }
    }
    private func clear() {
        switch group {
        case .course: filters.category = nil
        case .cuisine: filters.cuisineID = nil
        case .dietary: filters.dietary = []
        case .avoid: filters.avoidedAllergens = []
        }
    }
}

extension CookingFilterGroup {
    /// Spoken value for the group's chip; visible chips show title + count only.
    func summary(in filters: CookingFilters, dishes: [Dish]) -> String? {
        switch self {
        case .course: filters.category?.label
        case .cuisine: filters.cuisineID.flatMap { id in CuisineCatalog.options(saved: dishes.compactMap(\.cuisine)).first { $0.id == id }?.label }
        case .dietary: filters.dietary.isEmpty ? nil : CookingProductOptions.dietary.filter(filters.dietary.contains).map(\.label).joined(separator: ", ")
        case .avoid: filters.avoidedAllergens.isEmpty ? nil : CookingProductOptions.allergens.filter(filters.avoidedAllergens.contains).map(\.label).joined(separator: ", ")
        }
    }
}

/// Option rows for one filter group (no chrome). Identifiers are stable for UI automation.
struct CookingFilterOptions: View {
    @Binding var filters: CookingFilters
    let group: CookingFilterGroup
    var body: some View {
        switch group {
        case .cuisine: EmptyView() // Uses the shared searchable Cuisine options.
        case .course:
            SGSelectionRow(title: "All courses", selected: filters.category == nil) { filters.category = nil }
            ForEach(CookingProductOptions.courses) { course in
                SGSelectionRow(title: course.label, selected: filters.category == course) {
                    filters.category = filters.category == course ? nil : course
                }.accessibilityIdentifier("filter-course-\(course.rawValue)")
            }
        case .dietary:
            DietaryChoices(selection: $filters.dietary)
            SGOptionNote("Shows cooks with any selected label.")
        case .avoid:
            SGAllergenChoices(selection: $filters.avoidedAllergens, identifierPrefix: "filter-avoid")
            SGOptionNote(CookingProductOptions.allergenSafetyText).accessibilityIdentifier("allergen-safety")
        }
    }
}

/// Dietary options in two alphabetical groups. Shared by the Grub Rank filter and
/// cook editing; identifiers are stable for UI automation.
struct DietaryChoices: View {
    @Binding var selection: Set<DietaryTag>
    var body: some View {
        SGOptionGroupLabel("Diet")
        ForEach(CookingProductOptions.diets) { row($0) }
        SGOptionGroupLabel("Certification")
        ForEach(CookingProductOptions.certifications) { row($0) }
    }
    private func row(_ tag: DietaryTag) -> some View {
        SGSelectionRow(title: tag.label, selected: selection.contains(tag)) {
            if selection.contains(tag) { selection.remove(tag) } else { selection.insert(tag) }
        }.accessibilityIdentifier("filter-dietary-\(tag.rawValue)")
    }
}

/// Editing a cook's Dietary labels. Same canonical options as the filter.
struct DietarySelector: View {
    @Binding var selection: Set<DietaryTag>
    var body: some View {
        SGOptionSheet(title: "Dietary", doneIdentifier: "dietary-done") { DietaryChoices(selection: $selection) }
    }
}
