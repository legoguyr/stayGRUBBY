import SwiftUI

struct RecipeImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.recipeImportRequest) private var request
    let dish: Dish
    var done: () -> Void
    @State private var raw = ""
    @State private var cloudConsent = false
    @State private var formatting = false
    @State private var failure: RecipeImportFailure?
    @State private var result: ImportReview?
    @State private var operation: Task<Void,Never>?
    @State private var generation = UUID()
    @State private var discard = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Describe how you make it. StayGrubby will create a recipe with organized ingredients, a cooking plan and suggested details for you to review.").foregroundStyle(.secondary)
                    TextEditor(text: $raw).font(.body).frame(minHeight: 260).padding(8)
                        .scrollContentBackground(.hidden).background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Recipe text").accessibilityIdentifier("recipe-import-text").disabled(formatting)
                    Toggle("Allow Cloud Formatting", isOn: $cloudConsent).accessibilityIdentifier("recipe-import-consent").disabled(formatting)
                    Text("With your permission, Cloud Formatting sends your recipe text through Supabase to Google Gemini. Google’s free service may use it to improve its products and may have human reviewers. Avoid confidential or personal information. Nothing is saved until you review and tap Save.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if !cloudConsent { Text("Cloud permission is needed to create this recipe automatically. You can always continue manually.").font(.footnote) }
                    if formatting {
                        ProgressView("Formatting Recipe…").accessibilityIdentifier("recipe-import-progress")
                        Button("Stop Formatting") { cancel() }.frame(minHeight: 44)
                    } else {
                        Button("Format Recipe") { format() }.buttonStyle(SGButtonStyle(prominent: true))
                            .disabled(raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !cloudConsent)
                            .accessibilityIdentifier("recipe-import-format")
                        if let failure { Text(failure.message).font(.subheadline).accessibilityIdentifier("recipe-import-error") }
                        Button("Continue Manually") { review(RecipeImportValidation.manual(raw, dishTitle: dish.name)) }.buttonStyle(SGButtonStyle())
                            .accessibilityIdentifier("recipe-import-manual")
                    }
                }.padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively).background(SGTheme.ColorToken.background)
                .navigationTitle("Import Recipe").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if raw.isEmpty { cancel(); dismiss() } else { discard = true } }.accessibilityIdentifier("recipe-import-cancel") } }
                .interactiveDismissDisabled(!raw.isEmpty || formatting)
                .alert("Discard the pasted recipe?", isPresented: $discard) {
                    Button("Discard", role: .destructive) { cancel(); dismiss() }; Button("Keep Editing", role: .cancel) {}
                }
                .sheet(item: $result) { item in
                    RecipeEditor(dishID: dish.id, draft: item.value.draft, importReview: .init(raw: raw, warnings: item.value.warnings)) { _ in done() }
                }
                .onAppear {
                    #if DEBUG
                    RecipeIntelligenceDiagnostics.shared.cloudAllowed = cloudConsent
                    #endif
                }
                .onChange(of: cloudConsent) { _, allowed in
                    #if DEBUG
                    RecipeIntelligenceDiagnostics.shared.cloudAllowed = allowed
                    #endif
                }
                .onDisappear { cancel() }
        }
    }
    private func review(_ value: RecipeImportResult) { result = ImportReview(value: value) }
    private func cancel() { generation = UUID(); operation?.cancel(); operation = nil; formatting = false }
    private func format() {
        let token = UUID(); generation = token; formatting = true; failure = nil
        let original = raw
        var fallback: RecipeImportRequest?
        if cloudConsent, let request { fallback = { raw in try await request(raw) } }
        operation = Task { @MainActor in
            do {
                let value = try await RecipeIntelligenceService.format(original, dishTitle: dish.name, apple: AppleRecipeIntelligenceProvider(), fallback: GeminiRecipeIntelligenceProvider(request: fallback), preferOnDevice: false)
                guard !Task.isCancelled, generation == token else { return }
                formatting = false; review(value)
            } catch is CancellationError {} catch {
                guard !Task.isCancelled, generation == token else { return }
                formatting = false; failure = (error as? RecipeImportFailure) ?? .network
            }
        }
    }
}
private struct ImportReview: Identifiable { let id = UUID(); var value: RecipeImportResult }
nonisolated struct RecipeImportReview { var raw: String; var warnings: [String] }

enum RecipeCreationMode: String, Identifiable { case manual, imported; var id: String { rawValue } }
struct RecipeCreationChoice: View {
    @Environment(\.dismiss) private var dismiss
    var entries: [CookbookEntry]
    @State private var mode: RecipeCreationMode?
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("Keep a recipe for a dish you’ve cooked.").foregroundStyle(.secondary)
                Button { mode = .imported } label: { VStack(alignment: .leading, spacing: 6) { Label("Import Recipe", systemImage: "doc.text").font(.headline); Text("Paste a full recipe and organize it for review.").font(.subheadline) }.frame(maxWidth: .infinity, alignment: .leading).padding(16) }.buttonStyle(SGButtonStyle()).accessibilityIdentifier("bible-import")
                Button { mode = .manual } label: { Label("Add Manually", systemImage: "square.and.pencil").frame(maxWidth: .infinity, alignment: .leading).padding(16) }.buttonStyle(SGButtonStyle()).accessibilityIdentifier("bible-manual")
                Spacer()
            }.padding(20).background(SGTheme.ColorToken.background).navigationTitle("Add Recipe")
                .navigationDestination(item: $mode) { mode in CookedDishPicker(entries: entries, mode: mode, onComplete: { dismiss() }) }
                .toolbar { ToolbarItem(placement: .cancellationAction) { RecipeCreationDone() } }
        }
    }
}
private struct RecipeCreationDone: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View { Button("Done") { dismiss() } }
}
