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

/// Grub Rank's single Filters sheet. Each group keeps its existing semantics:
/// Course single-select, Cuisine single-select, Dietary matches any, Avoid excludes any.
struct CookingFiltersSheet: View {
    @Binding var filters: CookingFilters
    @Query private var dishes: [Dish]
    private var cuisineLabel: String? {
        guard let id = filters.cuisineID else { return nil }
        return CuisineCatalog.options(saved: dishes.compactMap(\.cuisine)).first { $0.id == id }?.label
    }

    var body: some View {
        SGFilterSheet(isActive: filters.isActive, clear: { filters = CookingFilters() }) {
            ForEach(CookingFilterGroup.allCases) { group in
                SGFilterGroupLink(title: group.title, summary: summary(group), count: group.count(in: filters),
                                  identifier: "ranking-filter-\(group.rawValue)") {
                    page(group)
                }
            }
            Text("Groups and search must all match. Ranks stay global.")
                .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, SGTheme.Space.small)
        }
    }
    private func summary(_ group: CookingFilterGroup) -> String? {
        switch group {
        case .course: filters.category?.label
        case .cuisine: cuisineLabel
        case .dietary, .avoid: nil
        }
    }
    @ViewBuilder private func page(_ group: CookingFilterGroup) -> some View {
        if group == .cuisine {
            CuisineOptions(selection: Binding(
                get: { CuisineCatalog.options(saved: dishes.compactMap(\.cuisine)).first { $0.id == filters.cuisineID } },
                set: { filters.cuisineID = $0?.id }), allowsCreation: false)
        } else {
            SGFilterGroupPage(title: group.title, isActive: group.count(in: filters) > 0,
                              clear: { clear(group) }, clearIdentifier: group == .avoid ? "clear-avoid" : "filter-group-clear") {
                CookingFilterOptions(filters: $filters, group: group)
            }
        }
    }
    private func clear(_ group: CookingFilterGroup) {
        switch group {
        case .course: filters.category = nil
        case .cuisine: filters.cuisineID = nil
        case .dietary: filters.dietary = []
        case .avoid: filters.avoidedAllergens = []
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
            ForEach(CookingProductOptions.dietary) { tag in
                SGSelectionRow(title: tag.label, selected: filters.dietary.contains(tag)) {
                    if filters.dietary.contains(tag) { filters.dietary.remove(tag) }
                    else { filters.dietary.insert(tag) }
                }.accessibilityIdentifier("filter-dietary-\(tag.rawValue)")
            }
            SGOptionNote("Shows cooks with any selected label.")
        case .avoid:
            SGAllergenChoices(selection: $filters.avoidedAllergens, identifierPrefix: "filter-avoid")
            SGOptionNote(CookingProductOptions.allergenSafetyText).accessibilityIdentifier("allergen-safety")
        }
    }
}

/// Editing a cook's Dietary labels. Same canonical options as the filter, but editing
/// language: these describe the cook; they do not search anything.
struct DietarySelector: View {
    @Binding var selection: Set<DietaryTag>
    var body: some View {
        SGOptionSheet(title: "Dietary", doneIdentifier: "dietary-done") {
            ForEach(CookingProductOptions.dietary) { tag in
                SGSelectionRow(title: tag.label, selected: selection.contains(tag)) {
                    if selection.contains(tag) { selection.remove(tag) } else { selection.insert(tag) }
                }.accessibilityIdentifier("filter-dietary-\(tag.rawValue)")
            }
            SGOptionNote("Your own labels for this cook. Not a certification or allergy guarantee.")
        }
    }
}

/// Short secondary note under an option list.
struct SGOptionNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, SGTheme.Space.small)
    }
}
