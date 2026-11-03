import SwiftUI
import SwiftData

/// A scoped owner editor, not the later New Dish redesign.
struct DishTextEditor: View {
    let dish: Dish
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var description: String
    @State private var notes: String
    @State private var failed = false
    init(dish: Dish) {
        self.dish = dish
        _description = State(initialValue: dish.publicDescription ?? "")
        _notes = State(initialValue: dish.privateNotes ?? "")
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Public Description") {
                    TextField("About this dish", text: $description, axis: .vertical).lineLimit(3...8).accessibilityIdentifier("dish-text-public")
                    Text("Can be used when you choose to share this Dish. Existing posts stay unchanged.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Private Notes") {
                    TextField("For your kitchen only", text: $notes, axis: .vertical).lineLimit(3...10).accessibilityIdentifier("dish-text-private")
                    Text("Only you can read these Dish notes. Your individual cooks keep their existing private notes separately.").font(.footnote).foregroundStyle(.secondary)
                }
                if failed { Text("Couldn’t save these details. Your changes are still here.").foregroundStyle(.secondary) }
            }.scrollDismissesKeyboard(.interactively).navigationTitle("Dish Details").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            do { try CookingStore.editDishText(dish, publicDescription: description, privateNotes: notes, context: context); dismiss() }
                            catch { failed = true }
                        }.disabled(!DishTextPolicy.valid(description: description, notes: notes)).accessibilityIdentifier("dish-text-save")
                    }
                }
        }
    }
}
