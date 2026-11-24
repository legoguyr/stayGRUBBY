import SwiftUI
import SwiftData

/// The Dish's Private Notes (November 21, 2026). Public text now belongs to each cook (Edit Cook →
/// Description), so this editor never touches a description or any post. The legacy Dish description is
/// kept unchanged for cooks that have no description of their own yet.
struct DishTextEditor: View {
    let dish: Dish
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var notes: String
    @State private var failed = false
    init(dish: Dish) {
        self.dish = dish
        _notes = State(initialValue: dish.privateNotes ?? "")
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Private Notes") {
                    TextField("For your kitchen only", text: $notes, axis: .vertical).lineLimit(3...10).accessibilityIdentifier("dish-text-private")
                    Text("Only you can read these Dish notes. Each cook's description is edited with that cook.").font(SGTheme.TypeRole.footnote).foregroundStyle(.secondary)
                }
                if failed { Text("Couldn’t save these notes. Your changes are still here.").foregroundStyle(.secondary) }
            }.scrollDismissesKeyboard(.interactively).navigationTitle("Dish Notes").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            do { try CookingStore.editDishText(dish, publicDescription: dish.publicDescription ?? "", privateNotes: notes, context: context); dismiss() }
                            catch { failed = true }
                        }.disabled(!DishTextPolicy.valid(description: dish.publicDescription ?? "", notes: notes)).accessibilityIdentifier("dish-text-save")
                    }
                }
        }
    }
}
