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
        case .course: filters.categories.count
        case .cuisine: filters.cuisineIDs.count
        case .dietary: filters.dietary.count
        case .avoid: filters.avoidedAllergens.count
        }
    }
}

extension CookingFilters {
    var activeCount: Int { CookingFilterGroup.allCases.reduce(0) { $0 + $1.count(in: self) } }
}

/// One Grub Rank filter group, opened directly from its chip. Every group is multi-select;
/// choosing never closes the sheet — the user taps Done. Course, Cuisine and Dietary
/// match any selected value; Avoid excludes any selected allergen.
struct CookingFilterGroupSheet: View {
    @Binding var filters: CookingFilters
    let group: CookingFilterGroup
    @Query private var dishes: [Dish]
    var body: some View {
        SGFilterGroupSheet {
            if group == .cuisine {
                CuisineOptions(filterSelection: $filters.cuisineIDs)
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
        case .course: filters.categories = []
        case .cuisine: filters.cuisineIDs = []
        case .dietary: filters.dietary = []
        case .avoid: filters.avoidedAllergens = []
        }
    }
}

extension CookingFilterGroup {
    /// Spoken value for the group's chip; visible chips show the title only (active = red).
    func summary(in filters: CookingFilters, dishes: [Dish]) -> String? {
        switch self {
        case .course: filters.categories.isEmpty ? nil : CookingProductOptions.courses.filter(filters.categories.contains).map(\.label).joined(separator: ", ")
        case .cuisine: filters.cuisineIDs.isEmpty ? nil : CuisineCatalog.options(saved: dishes.compactMap(\.cuisine)).filter { filters.cuisineIDs.contains($0.id) }.map(\.label).joined(separator: ", ")
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
            ForEach(CookingProductOptions.courses) { course in
                SGSelectionRow(title: course.label, selected: filters.categories.contains(course)) {
                    if filters.categories.contains(course) { filters.categories.remove(course) } else { filters.categories.insert(course) }
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
