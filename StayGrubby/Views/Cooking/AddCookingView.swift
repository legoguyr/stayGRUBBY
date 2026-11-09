import SwiftUI
import SwiftData

struct AddCookingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.cookingMediaRoot) private var mediaRoot
    @Environment(\.socialRequest) private var socialRequest
    @Environment(\.socialPublication) private var publication
    @Environment(\.sharedCooking) private var sharedCooking
    @Query private var attempts: [CookingAttempt]
    let list: RankingList
    let dish: Dish?
    /// A Recipe's Dish identity to use when this cook creates its Dish (Rank My Version).
    var newDishID: UUID? = nil
    /// Whether the result offers "Add a Recipe?" (the Dish has no Recipe). Nil: only a brand-new Dish
    /// ranked without a Recipe is known to have none.
    var offersRecipe: Bool? = nil
    let origin: SocialCookingClaim?
    let onResultClose: () -> Void
    @State private var draft: CookingDraft
    @State private var sharing = CookingSharingSelection()
    @State private var sharingChoice: Bool?
    @State private var sharingUnavailable = false
    @State private var choosingReaction = false
    @State private var session: RankingEngine?
    @State private var error: String?
    @State private var savedAttempt: CookingAttempt?
    @State private var saving = false
    @State private var saveFailed = false
    @State private var completionSnapshot: RankingCompletionSnapshot?
    @State private var cookedWith = Set<UUID>()
    @State private var recipePromptClosed = false
    @State private var addingRecipe = false
    private var promptsForRecipe: Bool { (offersRecipe ?? (origin == nil && dish == nil)) && socialRequest != nil && !recipePromptClosed }

    init(list: RankingList, dish: Dish? = nil, newDishID: UUID? = nil, offersRecipe: Bool? = nil, origin: SocialCookingClaim? = nil, onResultClose: @escaping () -> Void = {}) {
        self.list = list; self.dish = dish; self.newDishID = newDishID; self.offersRecipe = offersRecipe; self.origin = origin; self.onResultClose = onResultClose
        var initial = origin?.draft() ?? dish.map { CookingDraft(dish: $0) } ?? CookingDraft()
        // A Recipe claim can prefill this cook, but it does not replace the linked Dish's own text.
        if let dish {
            // One Dish identity: a Recipe-origin cook of an existing Dish keeps the Dish's name.
            initial.dishName = dish.name
            initial.publicDescription = dish.publicDescription ?? ""
            initial.privateNotes = dish.privateNotes ?? ""
        }
        _draft = State(initialValue: initial)
    }
    /// A lone unnamed first cook shows no "Version 1" (`CookName.label`); Cook Again on an
    /// existing Dish shows its fallback name. Presentation only.
    private var newVersionLabel: String? {
        draft.cleanTitle ?? (dish?.attempts.isEmpty ?? true ? nil : CookName.fallback(sequence: (dish?.attempts.map(\.sequenceNumber).max() ?? 0) + 1))
    }
    private var displayName: String {
        [draft.cleanDishName, newVersionLabel].compactMap { $0 }.joined(separator: " — ")
    }
    var body: some View {
        NavigationStack {
            Group {
                if let savedAttempt {
                    CookingRankingResultView(attempt: savedAttempt, event: completionSnapshot,
                                             onClose: { onResultClose(); dismiss() })
                        .safeAreaInset(edge: .top) {
                            if sharingUnavailable { Text("Your cook is saved privately. Sharing couldn’t be queued; use Share with Sous Chefs below to retry.").font(.footnote).padding() }
                            SharedCookingPending(itemID: savedAttempt.rankedItemID)
                            if promptsForRecipe, savedAttempt.dish != nil { recipePrompt }
                        }
                        .sheet(isPresented: $addingRecipe, onDismiss: { recipePromptClosed = true }) {
                            if let dish = savedAttempt.dish { AddRecipeFlow(context: .dish(dish)) }
                        }
                } else if let session {
                    if let opponent = list.items.first(where: { $0.id == session.nextOpponent }) {
                        let opponentAttempt = attempts.first { $0.rankedItemID == opponent.id }
                        ComparisonView(newName: draft.cleanDishName,
                                       existingName: opponentAttempt?.dish?.name ?? opponent.name,
                                       newVersion: newVersionLabel,
                                       existingVersion: opponentAttempt?.meaningfulVersionLabel,
                                       newPreparedPhoto: draft.pendingPhoto,
                                       existingPhoto: opponentAttempt?.primaryImage,
                                       canUndo: session.canUndo,
                                       onAnswer: { self.session?.answer($0) }, onUndo: { self.session?.undo() })
                    } else {
                        VStack(spacing: SGTheme.Space.medium) {
                            if !saveFailed { ProgressView("Finishing your cook…") }
                            else {
                                Text("Your cook hasn’t been saved yet.")
                                Button("Retry", action: save).buttonStyle(SGButtonStyle(prominent: true))
                            }
                        }
                    }
                } else if choosingReaction {
                    InitialReactionView(name: displayName) { reaction in
                        do {
                            session = RankingEngine(itemID: origin?.itemID ?? UUID(), orderedIDs: list.orderedItems.map(\.id), reaction: reaction, context: try list.rankingContext())
                        } catch { self.error = error.localizedDescription }
                    }
                } else {
                    CookingFormScroll(draft: $draft, existingDish: dish != nil, sharingSelection: socialRequest == nil ? nil : $sharing, cookedWith: socialRequest != nil && sharing.configured == true ? $cookedWith : nil,
                                      fallbackCookName: dish?.attempts.isEmpty ?? true ? nil : CookName.fallback(sequence: (dish?.attempts.map(\.sequenceNumber).max() ?? 0) + 1))
                }
            }
            .navigationTitle(savedAttempt != nil ? "Ranking Result" : session == nil ? (origin?.kind == "recipe" || origin?.recipeSnapshot != nil ? "Rank My Version" : dish == nil ? "New Dish" : "Cook Again") : "Rank this cook")
            .navigationBarTitleDisplayMode(.inline)
            .background(SGTheme.ColorToken.background)
            .toolbar {
                if savedAttempt == nil { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                if choosingReaction && session == nil {
                    ToolbarItem(placement: .confirmationAction) { Button("Edit Details") { choosingReaction = false; sharingChoice = nil } }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if savedAttempt == nil && !choosingReaction && session == nil {
                    Button { sharingChoice = sharing.selected; choosingReaction = true } label: {
                        Text("Continue").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SGButtonStyle(prominent: true)).disabled(!draft.validForRanking)
                    .padding(SGTheme.Space.medium).background(SGTheme.ColorToken.background)
                }
            }
            .interactiveDismissDisabled(session != nil)
            .task(id: session?.isComplete) { if session?.isComplete == true { save() } }
            .alert("Couldn't save cook", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("Retry", action: save)
                Button("Cancel", role: .cancel) { dismiss() }
            } message: { Text(error ?? "") }
        }
        .deferRemoteCookingUpdates()
        .task {
            guard let socialRequest else { return }
            do {
                let identity = try JSONDecoder().decode(SocialIdentity.self, from: await socialRequest("social_identity", "get", .init()))
                try Task.checkCancellation(); sharing.receive(identity)
            } catch is CancellationError { } catch { sharing.unavailable() }
        }
    }
    /// Lightweight post-ranking prompt for a Dish without a Recipe (FOOD_ARCHITECTURE §7.1).
    private var recipePrompt: some View {
        HStack(spacing: SGTheme.Space.small) {
            Label("Add a Recipe?", systemImage: "book").font(SGTheme.TypeRole.headline).frame(maxWidth: .infinity, alignment: .leading)
            Button("Not Now") { recipePromptClosed = true }.frame(minHeight: SGTheme.Size.minimumTap).accessibilityIdentifier("recipe-prompt-not-now")
            Button("Add Recipe") { addingRecipe = true }.buttonStyle(SGButtonStyle(prominent: true)).accessibilityIdentifier("recipe-prompt-add")
        }
        .padding(SGTheme.Space.medium).sgCard().padding(.horizontal, SGTheme.Space.medium).padding(.vertical, SGTheme.Space.xSmall)
        .background(SGTheme.ColorToken.background)
        .accessibilityElement(children: .contain).accessibilityIdentifier("recipe-prompt")
    }

    private func save() {
        guard let session, session.isComplete, savedAttempt == nil, !saving else { return }
        saving = true; error = nil; saveFailed = false
        defer { saving = false }
        do {
            let before = RankingCompletionSnapshot.capture(from: list)
            if !cookedWith.isEmpty || origin != nil {
                guard let sharedCooking else { throw AccountFoundationError.accountNotResolved }
                try sharedCooking.record(itemID: session.itemID, participants: cookedWith.sorted { $0.uuidString < $1.uuidString }, originID: origin?.kind == "recipe" ? nil : origin?.id, recipeOriginID: origin?.recipeOriginID)
            }
            if sharingChoice == true {
                sharingUnavailable = publication?.record(itemID: session.itemID, includePhoto: draft.hasPhoto) != true
            } else {
                try publication?.cancelUnsavedCreation(session.itemID)
            }
            savedAttempt = try CookingStore.create(draft: draft, existingDish: dish, newDishID: newDishID, session: session, context: context, mediaDirectory: mediaRoot)
            completionSnapshot = before
            if let savedAttempt { publication?.privateSaveFinished(savedAttempt) }
            publication?.retry()
            sharedCooking?.retry()
        }
        catch { saveFailed = true; self.error = error.localizedDescription }
    }
}
