import SwiftUI

/// One ingredient presentation for the reader and the editor's resolved rows.
struct RecipeIngredientLabel: View {
    let row: RecipeIngredient
    @Environment(\.dynamicTypeSize) private var size
    var body: some View {
        let amount = IngredientLineFormatter.amount(row)
        Group {
            if size.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 5) { if !amount.isEmpty { Text(amount).font(.body.bold()) }; name }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    if !amount.isEmpty { Text(amount).font(.body.bold()).frame(width: 88, alignment: .leading).fixedSize(horizontal: false, vertical: true) }
                    name.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    private var name: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.name).font(.body).foregroundStyle(SGTheme.ColorToken.primaryText).fixedSize(horizontal: false, vertical: true)
            if !row.preparation.isEmpty { Text(row.preparation).font(.subheadline).foregroundStyle(.secondary) }
            if !row.note.isEmpty { Text(row.note).font(.subheadline).foregroundStyle(.secondary) }
        }
    }
}

/// Local correction escape hatch. Done changes only the enclosing Recipe draft.
struct IngredientDetailsEditor: View {
    let ingredient: RecipeIngredient
    let apply: (RecipeIngredient) -> Void
    @State private var value: RecipeIngredient
    @State private var discard = false
    @Environment(\.dismiss) private var dismiss
    init(ingredient: RecipeIngredient, apply: @escaping (RecipeIngredient) -> Void) {
        self.ingredient = ingredient; self.apply = apply; _value = State(initialValue: ingredient)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Ingredient") {
                    TextField("Quantity", text: $value.quantity).accessibilityIdentifier("ingredient-detail-quantity").accessibilityLabel("Ingredient quantity")
                    TextField("Unit", text: $value.unit).accessibilityIdentifier("ingredient-detail-unit").accessibilityLabel("Ingredient unit")
                    TextField("Ingredient name", text: $value.name, axis: .vertical).accessibilityIdentifier("ingredient-detail-name").accessibilityLabel("Ingredient name")
                }
                Section("Preparation & note") {
                    TextField("Preparation", text: $value.preparation, axis: .vertical).accessibilityIdentifier("ingredient-detail-preparation").accessibilityLabel("Ingredient preparation")
                    TextField("Note", text: $value.note, axis: .vertical).accessibilityIdentifier("ingredient-detail-note").accessibilityLabel("Ingredient note")
                }
            }.navigationTitle("Edit Ingredient Details").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if value != ingredient { discard = true } else { dismiss() } } }
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { apply(value); dismiss() }.disabled(IngredientParser.trim(value.name).isEmpty).accessibilityIdentifier("ingredient-details-done") }
                }
        }.interactiveDismissDisabled(value != ingredient)
            .alert("Discard ingredient changes?", isPresented: $discard) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
    }
}
