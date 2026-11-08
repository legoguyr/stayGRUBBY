import SwiftUI

struct RecipeImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.recipeImportRequest) private var request
    @Environment(\.scoreMilestoneScope) private var scope
    let dish: Dish?
    var done: () -> Void
    /// Receives the saved Recipe before `done` (Stage F Add Recipe flow).
    var onSaved: ((Recipe) -> Void)? = nil
    @State private var raw = ""
    @State private var cloudConsent = false
    @State private var formatting = false
    @State private var failure: RecipeImportFailure?
    @State private var result: ImportReview?
    @State private var operation: Task<Void,Never>?
    @State private var generation = UUID()
    @State private var discard = false
    @State private var privacy = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
                    if !cloudConsent {
                        disclosure
                    } else {
                    Text("Describe how you make it. StayGrubby will create a recipe with organized ingredients, a cooking plan and suggested details for you to review.").foregroundStyle(.secondary)
                    TextEditor(text: $raw).font(.body).frame(minHeight: 260).padding(8)
                        .scrollContentBackground(.hidden).background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Recipe text").accessibilityIdentifier("recipe-import-text").disabled(formatting)
                    if formatting {
                        ProgressView("Formatting Recipe…").accessibilityIdentifier("recipe-import-progress")
                        Button("Stop Formatting") { cancel() }.frame(minHeight: 44)
                    } else {
                        Button("Create Recipe") { format() }.buttonStyle(SGButtonStyle(prominent: true))
                            .disabled(raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !cloudConsent)
                            .accessibilityIdentifier("recipe-import-format")
                        if let failure { Text(failure.message).font(.subheadline).accessibilityIdentifier("recipe-import-error") }
                        Button("Continue Manually") { review(RecipeImportValidation.manual(raw, dishTitle: dish?.name ?? "Recipe")) }.buttonStyle(SGButtonStyle())
                            .accessibilityIdentifier("recipe-import-manual")
                    }
                    }
                }.padding(SGTheme.Space.readingMargin).frame(maxWidth: SGTheme.Size.contentMaximum).frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively).background(SGTheme.ColorToken.background)
                .navigationTitle("Paste Recipe").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if raw.isEmpty { cancel(); dismiss() } else { discard = true } }.accessibilityIdentifier("recipe-import-cancel") } }
                .interactiveDismissDisabled(!raw.isEmpty || formatting)
                .alert("Discard the pasted recipe?", isPresented: $discard) {
                    Button("Discard", role: .destructive) { cancel(); dismiss() }; Button("Keep Editing", role: .cancel) {}
                }
                .sheet(item: $result) { item in
                    RecipeEditor(dishID: dish?.id, draft: item.value.draft, importReview: .init(raw: raw, warnings: item.value.warnings)) { recipe in onSaved?(recipe); done() }
                }
                .sheet(isPresented: $privacy) { PrivacyPolicyView() }
                .onAppear {
                    cloudConsent = RecipeImportConsent.acknowledged(scope: scope)
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
    private var disclosure: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.group) {
            Text("Turn your words into a recipe").font(SGTheme.TypeRole.headline)
            Text("Paste Recipe sends the text you submit through Supabase to Google Gemini, an external AI service, to create an editable recipe. Google’s unpaid service may use text and responses to improve its products, and human reviewers may review them. Avoid confidential or personal information.")
            Text("You’ll review everything before saving. Add Manually works without this AI service.").foregroundStyle(.secondary)
            Button("Continue") { RecipeImportConsent.acknowledge(scope: scope); cloudConsent = true }.buttonStyle(SGButtonStyle(prominent: true)).accessibilityIdentifier("recipe-disclosure-continue")
            Button("Add Manually") { review(RecipeImportValidation.manual(raw, dishTitle: dish?.name ?? "Recipe")) }.buttonStyle(SGButtonStyle()).accessibilityIdentifier("recipe-disclosure-manual")
            Button("Privacy Policy") { privacy = true }.frame(minHeight: 44)
        }
    }
    private func review(_ value: RecipeImportResult) { result = ImportReview(value: value) }
    private func cancel() { generation = UUID(); operation?.cancel(); operation = nil; formatting = false }
    private func format() {
        guard cloudConsent else { return }
        let token = UUID(); generation = token; formatting = true; failure = nil
        let original = raw
        var fallback: RecipeImportRequest?
        if cloudConsent, let request { fallback = { raw in try await request(raw) } }
        operation = Task { @MainActor in
            do {
                let value = try await RecipePasteRequest.format(original, dishTitle: dish?.name ?? "", acknowledged: cloudConsent, request: fallback)
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
