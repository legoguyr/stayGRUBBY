import SwiftUI
import SwiftData
import Supabase

struct AttemptDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.cookingMediaRoot) private var mediaRoot
    let attempt: CookingAttempt
    @Environment(\.socialRequest) private var request
    @State private var sharingSocial = false
    @State private var editing = false
    @State private var editingDishText = false
    @State private var reranking = false
    @State private var addingVersion = false
    @State private var versionFinalized = false
    @Environment(\.returnToRankings) private var returnToRankings
    @State private var deleting = false
    @State private var renaming: CookingAttempt?
    @State private var cookName = ""
    @State private var error: String?
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .caption) private var tagColumnWidth = SGTheme.Size.tagColumnWidth

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SGTheme.Space.medium) {
                SGHeroMedia(media: attempt.primaryImage, name: attempt.dish?.name ?? attempt.displayName)
                DishIdentityHeader(attempt: attempt)
                metadata
                if let dish = attempt.dish {
                    if let description = dish.publicDescription { Text(description).font(SGTheme.TypeRole.body).accessibilityIdentifier("dish-public-description") }
                    if let notes = dish.privateNotes {
                        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                            SGSectionHeader(title: "Dish Notes · private")
                            Text(notes).accessibilityIdentifier("dish-private-notes")
                        }
                    }
                }
                // Provenance is usually empty but still a stack child; grouping it keeps an
                // empty block from doubling the section gap.
                VStack(alignment: .leading, spacing: SGTheme.Space.compact) {
                    if let dish = attempt.dish { DishRecipesSection(dish: dish, attempt: attempt) }
                    CookingProvenanceView(itemID: attempt.rankedItemID, includesRecipe: false)
                }
                if let source = attempt.dish?.source {
                    VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                        SGSectionHeader(title: "Source")
                        SourceSummary(source: source)
                    }
                }
                if let notes = attempt.notes {
                    VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                        SGSectionHeader(title: "Personal Notes · private")
                        Text(notes)
                    }
                }
                if let dish = attempt.dish {
                    DishCooksSection(dish: dish, current: attempt,
                                     cookAgain: attempt.rankedItem?.list == nil ? nil : { addingVersion = true },
                                     rename: { beginRename($0) })
                }
            }
            .frame(maxWidth: SGTheme.Size.contentMaximum)
            .padding(.horizontal, SGTheme.Space.medium).padding(.bottom, SGTheme.Space.xLarge)
            .frame(maxWidth: .infinity)
        }
        .background(SGTheme.ColorToken.background)
        .navigationTitle("Dish Details").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                DishShareAction(model: .make(for: attempt), toolbar: true, currentModel: { .make(for: attempt) })
                DishActions(editCook: { editing = true }, rename: { beginRename(attempt) }, rerank: { reranking = true },
                            shareWithSousChefs: request == nil ? nil : { sharingSocial = true },
                            editDishText: { editingDishText = true }, delete: { deleting = true })
            }.sgIndependentToolbarBackground()
        }
        .sheet(isPresented: $sharingSocial) { SocialPostComposer(attempt: attempt, close: { sharingSocial = false }) }
        .sheet(isPresented: $editingDishText) { if let dish = attempt.dish { DishTextEditor(dish: dish) } }
        .sheet(isPresented: $editing) { EditCookingView(attempt: attempt) }
        .sheet(isPresented: $reranking) { ReRankView(attempt: attempt) }
        .sheet(isPresented: $addingVersion, onDismiss: {
            if versionFinalized { versionFinalized = false; returnToRankings() }
        }) {
            if let list = attempt.rankedItem?.list, let dish = attempt.dish {
                AddCookingView(list: list, dish: dish, onResultClose: { versionFinalized = true })
            }
        }
        .alert("86 this Cook?", isPresented: $deleting) {
            Button("86 Cook", role: .destructive) {
                do { try CookingStore.delete(attempt, context: context, mediaDirectory: mediaRoot); dismiss() }
                catch { self.error = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This removes this cook and can’t be undone. Other cooks stay saved. If this is the Dish’s last cook, the Dish is also removed.") }
        .alert("Rename Cook", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField(renaming.map { CookName.fallback(sequence: $0.sequenceNumber) } ?? "Cook Name", text: $cookName)
                .accessibilityIdentifier("rename-cook-field")
            Button("Save") { if let renaming { rename(renaming) } }.accessibilityIdentifier("rename-cook-save")
            Button("Cancel", role: .cancel) { }
        } message: { Text("Only the name changes. Its rank, score and history stay the same. Leave blank to use the automatic name.") }
        .alert("Couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
        .deferRemoteCookingUpdates()
    }

    private func beginRename(_ cook: CookingAttempt) {
        cookName = cook.versionTitle ?? ""; renaming = cook
    }
    private func rename(_ cook: CookingAttempt) {
        do { try CookingStore.rename(cook, to: cookName, context: context) }
        catch { self.error = error.localizedDescription }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            HStack {
                Label(attempt.category.label, systemImage: "fork.knife")
                Spacer()

            }.font(.subheadline.weight(.semibold))
            Label(attempt.cookedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Date unknown",
                  systemImage: "calendar")
                .font(.subheadline).foregroundStyle(.secondary)
            if !allTags.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: SGTheme.Space.xSmall) { ForEach(allTags, id: \.self) { TagChip(title: $0) } }
                        .fixedSize(horizontal: true, vertical: false)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: tagColumnWidth), alignment: .leading)], alignment: .leading, spacing: SGTheme.Space.xSmall) {
                        ForEach(allTags, id: \.self) { TagChip(title: $0) }
                    }
                }
            }
            if !attempt.containedAllergens.isEmpty {
                Text("Contains: " + attempt.containedAllergens.map(\.label).sorted().joined(separator: ", "))
                    .accessibilityIdentifier("detail-contains")
                Text(CookingProductOptions.allergenSafetyText)
                    .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            }
            if !attempt.allergyTags.isEmpty {
                Text("Legacy free-of labels: " + attempt.allergyTags.map(\.label).sorted().joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, SGTheme.Space.medium)
    }

    private var allTags: [String] {
        attempt.dietaryTags.map(\.label).sorted()
    }


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
                selectionFailed = (error as? PostgrestError)?.code == "40001"
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
