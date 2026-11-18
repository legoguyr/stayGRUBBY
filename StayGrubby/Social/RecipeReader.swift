import SwiftUI
import SwiftData

/// One Recipe reader, shared by the standalone `RecipeDetailView` and the Dish page's Recipe tab
/// (Connected UI Phase 1, November 15, 2026). The model owns loading, Rank My Version, Save and the
/// owner's management actions; hosts choose the header and the navigation chrome.
@MainActor @Observable final class RecipeReaderModel {
    var recipe: Recipe?
    var loaded = false
    var failed = false
    var busy = false
    var management: RecipeManagementSheet?
    var reportTarget: RecipeReportTarget?
    var claim: SocialCookingClaim?
    var list: RankingList?
    var deleting = false
    var deleted = false
    @ObservationIgnored var reservation = UUID()
    @ObservationIgnored private var generation = UUID()

    func cancelPending() { generation = UUID() }

    /// The Recipe by identity (standalone reader, deep links, Saved Recipes).
    func load(id: UUID, request: SocialRequest?) async {
        guard let request else { failed = true; return }
        await fetch { try await RecipeService.recipe("get", id: id, request: request) }
    }
    /// The Dish's own Recipe (`recipes.dish_id`); nil means the Dish has no Recipe yet.
    func load(dishID: UUID, request: SocialRequest?) async {
        guard let request else { failed = true; return }
        await fetch {
            var payload = SocialPayload(); payload.dishID = dishID
            return try JSONDecoder().decode(DishRecipeResponse.self, from: await request("recipes", "dish", payload)).recipe
        }
    }
    private func fetch(_ work: () async throws -> Recipe?) async {
        let token = UUID(); generation = token; failed = false
        do {
            let next = try await work()
            guard !Task.isCancelled, generation == token else { return }
            recipe = next; loaded = true
        } catch is CancellationError {} catch {
            guard generation == token else { return }
            let offline = (error as? URLError).map { [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed].contains($0.code) } ?? false
            // An owner's last-opened Recipe stays readable offline; anything else is withdrawn.
            if recipe?.isOwner != true || !offline { recipe = nil }
            failed = true
        }
    }
    func begin(context: ModelContext, request: SocialRequest?) async {
        guard let request, let recipe else { return }; busy = true; defer { busy = false }
        do {
            let next = try await RecipeService.begin(id: recipe.id, reservation: reservation, request: request)
            try Task.checkCancellation(); list = try CookingStore.globalRanking(context: context); claim = next
        } catch is CancellationError {} catch { failed = true }
    }
    /// Save keeps a private reference to another creator's Recipe; it never copies it or changes owner.
    func toggleSaved(request: SocialRequest?) async {
        guard let request, let current = recipe, !current.isOwner else { return }; busy = true; defer { busy = false }
        do {
            var payload = SocialPayload(); payload.recipeID = current.id
            _ = try await request("recipes", current.saved ? "unticket" : "ticket", payload)
            try Task.checkCancellation()
            recipe?.saved.toggle()
            NotificationCenter.default.post(name: .recipeSavesChanged, object: nil)
        } catch is CancellationError {} catch { failed = true }
    }
    func delete(context: ModelContext, relatedDish: Dish?, request: SocialRequest?) async {
        guard let request, let recipe else { return }
        let uncookedDish = recipe.isOwner ? (recipe.dishID ?? relatedDish?.id) : nil
        do {
            var payload = SocialPayload(); payload.recipeID = recipe.id
            _ = try await request("recipes", "delete", payload); try Task.checkCancellation()
            // A Dish that only existed for this Recipe goes with it; cooked Dishes stay in Grub Rank.
            try? DishIdentityStore.removeIfUncooked(id: uncookedDish, context: context)
            self.recipe = nil; deleted = true
            NotificationCenter.default.post(name: .socialContentChanged, object: nil)
        } catch { failed = true }
    }
}

enum RecipeManagementSheet: Identifiable {
    case edit(Recipe), history(Recipe), link(Recipe), duplicate(Recipe)
    var id: String { switch self { case .edit: "edit"; case .history: "history"; case .link: "link"; case .duplicate: "duplicate" } }
}

extension Notification.Name { static let recipeSavesChanged = Notification.Name("StayGrubby.recipeSavesChanged") }

/// The reader body. `showsHeader` is false inside the Dish page, whose shared header already shows
/// the photo and Dish name; the Recipe title then appears only when it differs from the Dish name.
struct RecipeReaderContent: View {
    let model: RecipeReaderModel
    let recipe: Recipe
    var relatedDish: Dish?
    var linkedCook: CookingAttempt?
    var showsHeader = true
    @Environment(\.socialRequest) private var request
    @Environment(\.modelContext) private var context
    private var cooks: Int { relatedDish?.attempts.count ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.section) {
            if showsHeader {
                RecipePhoto(id: recipe.content.photoID, dish: relatedDish, name: recipe.content.title, cook: linkedCook, exactCookLink: recipe.linkedAttemptID != nil)
                    .sgPhotoFrame(.hero).accessibilityIdentifier("recipe-hero")
            }
            VStack(alignment: .leading, spacing: SGTheme.Space.stack) {
                if cooks == 0 && recipe.isOwner { SGEyebrow(text: "Not cooked yet").accessibilityIdentifier("recipe-not-cooked") }
                if showsHeader || recipe.content.title != relatedDish?.name {
                    Text(recipe.content.title).font(showsHeader ? SGTheme.TypeRole.hero : SGTheme.TypeRole.title)
                        .accessibilityAddTraits(.isHeader).accessibilityIdentifier("recipe-title")
                }
                let metadata = [recipe.content.cuisine, recipe.content.course.flatMap { DishCategory(rawValue: $0)?.label }].compactMap { $0 }.joined(separator: " · ")
                if !metadata.isEmpty { Text(metadata).font(.subheadline).foregroundStyle(.secondary) }
                if let creator = RecipeSharingPolicy.creatorCredit(recipe) {
                    Text("Created by \(creator)").font(.subheadline).accessibilityIdentifier("recipe-attribution")
                    if !recipe.isOwner, let added = recipe.creator, added.displayName.caseInsensitiveCompare(creator) != .orderedSame { Text("Added by \(added.displayName)").font(.subheadline) }
                }
                // The Dish's cook count sits in the Dish header beside score and rank; the standalone
                // reader shows the same noninteractive count.
                if showsHeader, recipe.isOwner, cooks > 0 { DishCookCount(count: cooks) }
                if let description = recipe.content.description, !description.isEmpty { Text(description).font(.body).lineSpacing(6) }
            }
            Button { Task { await model.begin(context: context, request: request) } } label: { Label("Rank My Version", systemImage: "fork.knife").frame(maxWidth: .infinity) }
                .buttonStyle(SGButtonStyle(prominent: true)).disabled(model.busy).accessibilityIdentifier("recipe-make")
            if !recipe.isOwner {
                Button { Task { await model.toggleSaved(request: request) } } label: {
                    Label(recipe.saved ? "Saved to Food Bible" : "Save Recipe", systemImage: recipe.saved ? "bookmark.fill" : "bookmark").frame(maxWidth: .infinity)
                }.buttonStyle(SGButtonStyle()).disabled(model.busy)
                    .accessibilityHint(recipe.saved ? "Removes it from Saved Recipes" : "Keeps a reference in Saved Recipes; the creator keeps ownership")
                    .accessibilityIdentifier("recipe-save")
            }
            RecipeReadingBody(content: recipe.content, allowScaling: true)
            if showsHeader, let dish = relatedDish, cooks > 0 {
                Divider()
                DishCooksSection(dish: dish, linksByDestination: true, title: "Your cooks of \(dish.name)")
            }
            Divider()
            VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                if let source = recipe.content.source, !source.isEmpty { Text("Source · \(source)") }
                if let url = recipe.content.externalURL.flatMap(URL.init(string:)) { Link("Original source", destination: url) }
                if recipe.isOwner { RecipeForkAttribution(recipeID: recipe.id) }
                Text("Revision \(recipe.revision) · \(recipe.visibility == "friends" ? "Shared with current Sous Chefs" : "Private Recipe")").font(.caption).foregroundStyle(.secondary)
            }.font(.subheadline)
        }
    }
}

/// Owner management and sharing in the navigation bar, for any host showing a Recipe.
struct RecipeReaderToolbar: ToolbarContent {
    let model: RecipeReaderModel
    var body: some ToolbarContent {
        if let recipe = model.recipe {
            RecipeToolbarActions(url: recipe.visibility == "friends" ? AppRoute.recipeURL(recipe.id) : nil, sendContent: recipe.visibility == "friends" ? .recipe(recipe.id) : nil, disabled: model.busy) {
                if recipe.isOwner {
                    Button("Edit Recipe", systemImage: "pencil") { model.management = .edit(recipe) }.accessibilityIdentifier("recipe-edit")
                    Button("Recipe History", systemImage: "clock") { model.management = .history(recipe) }.accessibilityIdentifier("recipe-history")
                    Button("Save as New Recipe", systemImage: "document.on.document") { model.management = .duplicate(recipe) }.accessibilityIdentifier("recipe-save-new")
                    Button("Delete Recipe", systemImage: "trash", role: .destructive) { model.deleting = true }.accessibilityIdentifier("recipe-delete")
                } else {
                    Button("Report Recipe", systemImage: "flag") {
                        model.reportTarget = .init(id: recipe.id, revision: recipe.revision)
                    }.accessibilityIdentifier("social-report-recipe")
                }
            }
        }
    }
}

/// Sheets and confirmations for the reader's actions.
private struct RecipeReaderPresentation: ViewModifier {
    @Bindable var model: RecipeReaderModel
    var relatedDish: Dish?
    var reload: () async -> Void
    @Environment(\.socialRequest) private var request
    @Environment(\.modelContext) private var context
    func body(content: Content) -> some View {
        content
            .recipeReportSheet($model.reportTarget, reload: reload)
            .sheet(item: $model.management, onDismiss: { Task { await reload() } }) { sheet in
                switch sheet {
                case .edit(let r): RecipeEditor(recipe: r) { model.recipe = $0 }
                case .history(let r): RecipeHistoryView(recipe: r) { model.recipe = $0 }
                case .link(let r): RecipeDishLinker(recipe: r) {}
                case .duplicate(let r): RecipeEditor(draft: r.content, initiallyShared: false) { _ in }
                }
            }
            .sheet(item: $model.claim, onDismiss: { model.reservation = UUID() }) { claim in
                // Rank My Version cooks into this Recipe's own Dish (its identity even before a Dish row exists).
                if let list = model.list {
                    AddCookingView(list: list, dish: relatedDish,
                                   newDishID: relatedDish == nil && model.recipe?.isOwner == true ? model.recipe?.dishID : nil, origin: claim)
                }
            }
            .confirmationDialog("Delete this Recipe?", isPresented: $model.deleting, titleVisibility: .visible) {
                Button("Delete Recipe", role: .destructive) { Task { await model.delete(context: context, relatedDish: relatedDish, request: request) } }
            } message: { Text("This removes the Recipe and can’t be undone. Your cooks, rankings and saved cook snapshots stay intact.") }
    }
}
extension View {
    func recipeReaderPresentation(_ model: RecipeReaderModel, relatedDish: Dish?, reload: @escaping () async -> Void) -> some View {
        modifier(RecipeReaderPresentation(model: model, relatedDish: relatedDish, reload: reload))
    }
}
