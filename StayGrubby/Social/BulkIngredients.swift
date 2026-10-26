import SwiftUI

/// List cleanup is deliberately separate from the accepted single-line parser.
nonisolated enum BulkIngredients {
    struct Line: Equatable { var original: String; var text: String }
    static func lines(_ text: String) -> [Line] {
        text.components(separatedBy: .newlines).compactMap { original in
            var value = IngredientParser.trim(original)
            // Require whitespace after punctuation: keep -1, 1.5, 1/2 and 7 spice intact.
            value = value.replacingOccurrences(of: #"^(?:[-•*‣]\s+|\d{1,3}[.)]\s+)"#, with: "", options: .regularExpression)
            return value.isEmpty ? nil : Line(original: original, text: value)
        }
    }
}

struct PasteIngredientsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var discard = false
    var capacity = 100
    var insert: (String) -> Void
    var body: some View {
        let oversized = text.utf8.count > 32_000
        let rows = oversized ? [] : BulkIngredients.lines(text)
        let invalid = oversized || rows.count > capacity || rows.contains(where: { $0.text.count > 500 })
        return NavigationStack {
            ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Paste or type one ingredient per line. Bullets and numbered lists are welcome.").foregroundStyle(.secondary)
                TextEditor(text: $text).font(.body).frame(minHeight: 240).padding(8)
                    .scrollContentBackground(.hidden).background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Ingredient list").accessibilityIdentifier("bulk-ingredient-text")
                Text("Formatted on your device. No AI or connection needed.").font(.footnote).foregroundStyle(.secondary)
                Button("Format Ingredients") { insert(text); dismiss() }.buttonStyle(SGButtonStyle(prominent: true))
                    .disabled(rows.isEmpty || invalid)
                    .accessibilityIdentifier("bulk-ingredient-format")
                if invalid { Text("Use up to \(capacity) more ingredients in this section, at most 500 characters per line (32 KB total).").font(.footnote) }
            }.padding(20)
            }.scrollDismissesKeyboard(.interactively).background(SGTheme.ColorToken.background)
                .navigationTitle("Paste Ingredients").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if text.isEmpty { dismiss() } else { discard = true } } } }
                .interactiveDismissDisabled(!text.isEmpty)
                .alert("Discard this ingredient list?", isPresented: $discard) {
                    Button("Discard", role: .destructive) { dismiss() }; Button("Keep Editing", role: .cancel) {}
                }
        }
    }
}
