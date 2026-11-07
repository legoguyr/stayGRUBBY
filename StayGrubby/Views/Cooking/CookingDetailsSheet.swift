import SwiftUI

/// Edits only the enclosing value draft. Dismissing the cook still discards all changes.
struct CookingDetailsSheet: View {
    @Binding var draft: CookingDraft
    var inherited = false
    @State private var hasExistingCookNotes: Bool
    @FocusState private var notesFocused: Bool
    init(draft: Binding<CookingDraft>, inherited: Bool = false) {
        _draft = draft; self.inherited = inherited
        _hasExistingCookNotes = State(initialValue: !draft.wrappedValue.notes.isEmpty)
    }
    @Environment(\.dismiss) private var dismiss
    @State private var cuisine = false
    @State private var source = false
    @State private var dietary = false
    @State private var contains = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Course", selection: $draft.category) {
                        ForEach(CookingProductOptions.courses) { Text($0.label).tag($0) }
                    }.pickerStyle(.navigationLink).accessibilityIdentifier("cook-course")
                    if inherited {
                        LabeledContent("Cuisine", value: draft.cuisine?.label ?? "None").accessibilityIdentifier("inherited-dish-cuisine")
                        LabeledContent("Source", value: draft.source?.summary ?? "None")
                    } else {
                        row("Cuisine", value: draft.cuisine?.label ?? "None") { cuisine = true }.accessibilityIdentifier("dish-cuisine")
                        row("Source", value: draft.source?.summary ?? "None") { source = true }.accessibilityIdentifier("dish-source-type")
                    }
                }
                Section {
                    row("Dietary", value: draft.dietary.intersection(CookingProductOptions.dietary).map(\.label).sorted().joined(separator: ", ")) { dietary = true }.accessibilityIdentifier("cook-dietary")
                    row("Contains", value: draft.contains.map(\.label).sorted().joined(separator: ", ")) { contains = true }.accessibilityIdentifier("cook-contains")
                }
                if hasExistingCookNotes {
                    Section("Existing notes for this cook") {
                        TextField("Cook-specific notes", text: $draft.notes, axis: .vertical)
                            .lineLimit(1...6).focused($notesFocused).accessibilityIdentifier("cook-notes")
                        Text("Only this version. Separate from Dish Private Notes.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if !draft.allergy.isEmpty {
                    Section("Legacy free-of labels") {
                        Text(draft.allergy.map(\.label).sorted().joined(separator: ", "))
                        Text("User-entered claims; separate from Contains.").font(.footnote).foregroundStyle(.secondary)
                        Button("Remove legacy free-of labels", role: .destructive) { draft.allergy = [] }.accessibilityIdentifier("clear-legacy-free-labels")
                    }
                }
            }.scrollContentBackground(.hidden).background(SGTheme.ColorToken.background)
                .navigationTitle("Details").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("cook-details-done") }
                    ToolbarItemGroup(placement: .keyboard) { if notesFocused { Spacer(); Button("Done") { notesFocused = false } } }
                }
                .sheet(isPresented: $cuisine) { CuisinePicker(selection: $draft.cuisine) }
                .sheet(isPresented: $source) { DishSourceEditor(source: $draft.source) }
                .sheet(isPresented: $dietary) { DietarySelector(selection: $draft.dietary) }
                .sheet(isPresented: $contains) { ContainsSelector(selection: $draft.contains) }
        }
    }
    private func row(_ title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            metadataLabel(title, value: value)
        }.buttonStyle(.plain)
    }
    private func metadataLabel(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(SGTheme.ColorToken.primaryText)
            Spacer()
            Text(value.isEmpty ? "None" : value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary).accessibilityHidden(true)
        }.frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
    }
}
