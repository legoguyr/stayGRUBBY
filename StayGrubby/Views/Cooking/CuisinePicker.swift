import SwiftUI
import SwiftData

/// Standalone Cuisine choice for editors (sheet with Cancel).
struct CuisinePicker: View {
    @Binding var selection: Cuisine?
    var allowsCreation = true
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            CuisineOptions(selection: $selection, allowsCreation: allowsCreation)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

/// Searchable Cuisine list shared by editors and the Grub Rank Cuisine filter.
/// Editing: single choice that dismisses its sheet. Filtering (`filterSelection`):
/// multi-select toggles that never dismiss; the user taps Done.
struct CuisineOptions: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sgCloseFilterSheet) private var closeFilters
    @Query private var dishes: [Dish]
    @Binding var selection: Cuisine?
    var allowsCreation = true
    private var filterSelection: Binding<Set<String>>?
    @State private var search = ""

    init(selection: Binding<Cuisine?>, allowsCreation: Bool = true) {
        _selection = selection; self.allowsCreation = allowsCreation
    }
    init(filterSelection: Binding<Set<String>>) {
        _selection = .constant(nil); allowsCreation = false; self.filterSelection = filterSelection
    }
    private func isSelected(_ cuisine: Cuisine) -> Bool {
        filterSelection.map { $0.wrappedValue.contains(cuisine.id) } ?? (selection?.id == cuisine.id)
    }

    private var saved: [Cuisine] { dishes.compactMap(\.cuisine) }
    private var options: [Cuisine] {
        let all = CuisineCatalog.options(saved: saved + [selection].compactMap { $0 })
        let key = CuisineCatalog.key(search)
        if key.isEmpty { return all }
        let exact = CuisineCatalog.existing(search, saved: saved)
        return all.filter { CuisineCatalog.key($0.label).contains(key) || $0.id == exact?.id }
    }
    var body: some View {
            List {
                if filterSelection == nil {
                    Button(allowsCreation ? "No cuisine" : "All cuisines") { choose(nil) }
                        .accessibilityIdentifier("cuisine-clear")
                }
                Section(search.isEmpty ? "Cuisines" : "Results") {
                    ForEach(options) { cuisine in
                        Button { choose(cuisine) } label: {
                            HStack {
                                Text(cuisine.label).foregroundStyle(SGTheme.ColorToken.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                if isSelected(cuisine) { Image(systemName: "checkmark").accessibilityLabel("Selected") }
                            }.frame(minHeight: SGTheme.Size.minimumTap)
                        }
                        .accessibilityAddTraits(isSelected(cuisine) ? .isSelected : [])
                        .accessibilityIdentifier("cuisine-option-\(cuisine.id)")
                    }
                }
                if allowsCreation, CuisineCatalog.existing(search, saved: saved) == nil,
                   let custom = CuisineCatalog.resolve(search, saved: saved) {
                    Button { choose(custom) } label: { Label("Add “\(custom.label)”", systemImage: "plus") }
                        .accessibilityIdentifier("cuisine-add")
                }
                if CuisineCatalog.display(search).unicodeScalars.count > CuisineCatalog.maximumLabelLength {
                    Text("Use 80 characters or fewer.").foregroundStyle(.secondary)
                }
            }
            .searchable(text: $search, prompt: "Search cuisines")
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Cuisine").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let filterSelection {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Clear") { filterSelection.wrappedValue = [] }
                            .disabled(filterSelection.wrappedValue.isEmpty).accessibilityIdentifier("filter-group-clear")
                    }
                }
                if let closeFilters {
                    ToolbarItem(placement: .confirmationAction) { Button("Done", action: closeFilters).accessibilityIdentifier("filters-done") }
                }
            }
    }
    private func choose(_ cuisine: Cuisine?) {
        if let filterSelection, let cuisine {
            if filterSelection.wrappedValue.contains(cuisine.id) { filterSelection.wrappedValue.remove(cuisine.id) }
            else { filterSelection.wrappedValue.insert(cuisine.id) }
            return
        }
        selection = cuisine; dismiss()
    }
}
