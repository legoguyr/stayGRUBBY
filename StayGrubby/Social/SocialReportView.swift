import SwiftUI

nonisolated enum SocialReportReason: String, CaseIterable, Identifiable {
    case harassment, hate, spam, inappropriate, impersonation, other
    var id: String { rawValue }
    var title: String {
        switch self { case .harassment: "Harassment or bullying"; case .hate: "Hate or abuse"; case .spam: "Spam"; case .inappropriate: "Inappropriate content"; case .impersonation: "Impersonation"; case .other: "Other" }
    }
}
struct SocialReportButton: View {
    let kind: String
    let targetID: UUID
    var postID: UUID? = nil
    @State private var showing = false
    var body: some View {
        Button("Report \(kind)") { showing = true }.accessibilityIdentifier("social-report-\(kind)")
            .sheet(isPresented: $showing) { SocialReportEditor(kind: kind, targetID: targetID, postID: postID, close: { showing = false }) }
    }
}

struct RecipeReportTarget: Identifiable {
    let id: UUID
    var postID: UUID? = nil
    let revision: Int
}

extension View {
    func recipeReportSheet(_ target: Binding<RecipeReportTarget?>, reload: @escaping () async -> Void) -> some View {
        sheet(item: target) { recipe in
            SocialReportEditor(kind: "recipe", targetID: recipe.id, postID: recipe.postID, sourceRevision: recipe.revision,
                               refreshRecipe: reload, close: { target.wrappedValue = nil })
        }
    }
}

struct SocialReportEditor: View {
    let kind: String
    let targetID: UUID
    var postID: UUID? = nil
    var sourceRevision: Int? = nil
    var refreshRecipe: (() async -> Void)? = nil
    @Environment(\.socialRequest) private var request
    let close: () -> Void
    @State private var reason = SocialReportReason.other
    @State private var context = ""
    @State private var busy = false
    @State private var failed = false
    @State private var recipeChanged = false
    @State private var sent = false
    var body: some View {
        NavigationStack {
            Form {
                Picker("Reason", selection: $reason) { ForEach(SocialReportReason.allCases) { Text($0.title).tag($0) } }
                TextField("Additional context (optional)", text: $context, axis: .vertical).lineLimit(3...6)
                    .accessibilityIdentifier("social-report-context")
                Text("Up to 500 characters. Reports are private to StayGrubby’s review process; the reported person cannot see your report or reporter details.")
                Text("For privacy or support, contact support@staygrubby.com. Reports do not automatically hide content.").font(SGTheme.TypeRole.footnote).foregroundStyle(.secondary)
                if failed { Text("Couldn’t send this report. The content may no longer be available. You can retry.") }
                if recipeChanged {
                    Text("This Recipe changed. Review it before sending a new report.")
                        .accessibilityIdentifier("social-report-recipe-changed")
                    Button("Reload Recipe") {
                        Task {
                            close()
                            await refreshRecipe?()
                        }
                    }.accessibilityIdentifier("social-report-reload-recipe")
                } else {
                    Button(busy ? "Sending…" : "Send report") { Task { await send() } }
                        .disabled(busy || context.unicodeScalars.count > 500).accessibilityIdentifier("social-report-send")
                }
            }
            .navigationTitle("Report \(kind)").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { close() }.disabled(busy) } }
            .interactiveDismissDisabled(busy)
            .alert("Report sent", isPresented: $sent) { Button("Done") { close() } } message: { Text("Thank you. Your report is available for review.") }
        }
    }
    private func send() async {
        guard let request else { failed = true; return }; busy = true; failed = false
        defer { busy = false }
        do {
            struct Receipt: Decodable { let reported: Bool }
            let data = try await request("social_report", "report", .init(targetType: kind, targetID: targetID, reason: reason.rawValue, context: context, postID: postID, sourceRevision: sourceRevision))
            guard try JSONDecoder().decode(Receipt.self, from: data).reported else { failed = true; return }; sent = true
        } catch is CancellationError {
        } catch where sourceRevision != nil && StayGrubbyConflict.matches(error) {
            recipeChanged = true
        } catch {
            failed = true
        }
    }
}
