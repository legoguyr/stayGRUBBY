import SwiftUI
import SwiftData
import Supabase

/// Compatibility entry point used by every cook route (Grub Rank rows, My Kitchen, search, cook lists):
/// the canonical Dish page for this cook's Dish, opened on Dish & Ranking.
struct AttemptDetailView: View {
    let attempt: CookingAttempt
    var tab: DishTab = .ranking
    var body: some View { DishView(dish: attempt.dish, cook: attempt, tab: tab) }
}

struct EditCookingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.cookingMediaRoot) private var mediaRoot
    @Environment(\.socialRequest) private var request
    @Environment(\.sharedCooking) private var sharedCooking
    @Query private var bindings: [SyncStoreBinding]
    let attempt: CookingAttempt
    @State private var draft: CookingDraft
    @State private var error: String?
    @State private var selection: CookParticipantSelection?
    @State private var participants: Set<UUID> = []
    @State private var selectionFailed = false
    @State private var reloadSelection = 0
    @State private var saving = false
    @State private var savedDraft = false
    init(attempt: CookingAttempt) { self.attempt = attempt; _draft = State(initialValue: CookingDraft(attempt: attempt)) }

    private var accepted: Bool {
        CookPublicationReadiness.revision(for: attempt, binding: bindings.first, requireCurrent: false) != nil
    }
    private var tagsPending: Bool {
        sharedCooking?.intents.contains { $0.id == attempt.rankedItemID && !$0.participants.isEmpty } == true
    }
    var body: some View {
        NavigationStack {
            CookingFormScroll(draft: $draft, editing: true,
                              cookedWith: selection == nil ? nil : $participants, editingParticipants: true,
                              selectedPeople: selection?.event?.participants.map(\.person) ?? [],
                              fallbackCookName: CookName.label(custom: nil, sequence: attempt.sequenceNumber, siblingCount: attempt.dish?.attempts.count ?? 1))
                .disabled(saving || savedDraft)
                .navigationTitle("Edit Cook").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(savedDraft ? "Close" : "Cancel") { dismiss() }.disabled(saving)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: SGTheme.Space.small) {
                        if request != nil && selection == nil {
                            if !accepted { Text("Sous Chef tags are available once this cook syncs.").font(.footnote) }
                            else if tagsPending { Button("Retry pending Sous Chef invitations") { sharedCooking?.retry() } }
                            else if selectionFailed { Button("Reload Sous Chef tags") { reloadSelection += 1 } }
                            else { ProgressView("Loading Sous Chef tags") }
                        }
                        if savedDraft && selectionFailed {
                            Button("Reload Sous Chef tags") { reloadSelection += 1 }
                        }
                        Button(savedDraft ? "Retry tag changes" : "Save") { Task { await save() } }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(SGButtonStyle(prominent: true))
                            .disabled(saving || draft.cleanDishName.isEmpty || !draft.validDishText)
                            .accessibilityIdentifier("save-cook-metadata")
                    }.padding(SGTheme.Space.medium).background(SGTheme.ColorToken.background)
                }
                .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("OK") { error = nil }
                } message: { Text(error ?? "") }
        }
        .task(id: "\(accepted):\(tagsPending):\(reloadSelection)") { await loadSelection() }
        .deferRemoteCookingUpdates()
    }

    private func loadSelection() async {
        guard accepted, !tagsPending, let request else { return }
        do {
            let data = try await request("social_cooking", "edit_selection", .init(attemptID: attempt.id))
            let loaded = try JSONDecoder().decode(CookParticipantSelection.self, from: data)
            try Task.checkCancellation()
            selection = loaded; participants = loaded.selectedIDs; selectionFailed = false
            if savedDraft { dismiss() }
        } catch is CancellationError {} catch { selectionFailed = true }
    }
    private func save() async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        do {
            if !savedDraft {
                try CookingStore.edit(attempt, draft: draft, context: context, mediaDirectory: mediaRoot)
                savedDraft = true
            }
            if let request, let selection, participants != selection.selectedIDs {
                var payload = SocialPayload(attemptID: attempt.id, confirmed: true)
                payload.participantIDs = participants.sorted { $0.uuidString < $1.uuidString }
                payload.selectionToken = selection.selectionToken
                _ = try await request("social_cooking", "update_selection", payload)
                try Task.checkCancellation()
                NotificationCenter.default.post(name: .socialContentChanged, object: nil)
            }
            dismiss()
        } catch is CancellationError {} catch {
            if savedDraft {
                selectionFailed = StayGrubbyConflict.matches(error)
                errorMessageForTagFailure()
            } else { self.error = error.localizedDescription }
        }
    }
    private func errorMessageForTagFailure() {
        error = selectionFailed
            ? "Your cook was saved. The tags changed elsewhere. Reload them before editing again."
            : "Your cook was saved. Sous Chef changes couldn’t be confirmed. Retry them here."
    }
}
