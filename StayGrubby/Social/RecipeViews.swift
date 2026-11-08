import SwiftUI
import SwiftData

/// Select the same complete, authorized Recipe index used by Food Bible.
struct RecipeLibraryView: View {
    var dishID: UUID? = nil
    var attemptID: UUID? = nil
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [CookbookEntry] = []
    @State private var loading = true
    @State private var failed = false
    @State private var busy = false
    @State private var query = ""
    var body: some View {
        SGEditorialList {
            if loading { ProgressView("Loading Recipes") }
            ForEach(entries.filter { CookbookSearch.matches($0.searchableText, query: query) }) { entry in
                Button { Task { await attach(entry.recipeID) } } label: { SGDestinationLabel(title: entry.recipeTitle, subtitle: entry.cuisine ?? "", symbol: "book") }
                    .disabled(busy).accessibilityIdentifier("choose-recipe-\(entry.recipeID)")
            }
            if failed { Text("Recipes unavailable. Check your connection or existing link."); Button("Retry") { Task { await load() } } }
            if !loading && entries.isEmpty { Text("No Recipes yet") }
        }.navigationTitle("Choose Recipe").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search Recipes").task { await load() }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) } }
            .interactiveDismissDisabled(busy)
    }
    private func load() async {
        guard let request else { loading = false; failed = true; return }; loading = true
        defer { loading = false }
        do { let result = try await CookbookIndex.load(request: request); try Task.checkCancellation(); entries = result; failed = false }
        catch is CancellationError {} catch { entries = []; failed = true }
    }
    private func attach(_ id: UUID) async {
        guard let request else { return }; busy = true; defer { busy = false }
        do {
            let recipe = try await RecipeService.recipe("get", id: id, request: request)
            var payload = SocialPayload(); payload.dishID = dishID; payload.recipeID = id; payload.attemptID = attemptID; payload.previousAttemptID = recipe.linkedAttemptID
            _ = try await request("recipes", attemptID == nil ? "attach" : "link_cook", payload)
            try Task.checkCancellation(); NotificationCenter.default.post(name: .socialContentChanged, object: nil); dismiss()
        } catch is CancellationError {} catch { failed = true }
    }
}

struct TicketsView: View {
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @State private var tickets: [RecipeTicket] = []
    @State private var failed = false
    @State private var loading = true
    @State private var generation = UUID()
    var body: some View {
        SGEditorialList {
            SGPageIntro(title: "Want to cook", subtitle: "Save the next good idea. Only a completed cook enters Grub Rank.", eyebrow: "Food Bible")
            if loading { ProgressView() }
            ForEach(tickets) { ticket in
                if let recipe = ticket.recipe {
                    NavigationLink { RecipeDetailView(id: recipe.id) } label: { RecipeSummaryRow(recipe: recipe, ticket: true) }.accessibilityLabel(recipe.content.title)
                } else { Text("Recipe unavailable").foregroundStyle(.secondary) }
                Button("Remove Ticket", role: .destructive) { Task { await remove(ticket.id) } }.frame(minHeight: 44)
            }
            if !loading && !failed && tickets.isEmpty { Text("No Tickets yet. Save a recipe you want to cook.").accessibilityIdentifier("tickets-empty") }
            NavigationLink("Browse Saved Recipes") { RecipeLibraryView() }
            if failed { Text("Tickets unavailable. Check your connection."); Button("Retry") { Task { await load() } } }
        }.navigationTitle("Want to Cook").navigationBarTitleDisplayMode(.inline).task { await load() }.refreshable { await load() }
            .onChange(of: phase) { _, next in generation = UUID(); tickets = []; if next == .active { Task { await load() } } }
            .onDisappear { generation = UUID() }
    }
    private func load() async {
        guard let request else { failed = true; loading = false; return }; let token = UUID(); generation = token; loading = true
        defer { if generation == token { loading = false } }
        do { let page = try JSONDecoder().decode(TicketsPage.self, from: await request("recipes", "tickets", .init())); guard !Task.isCancelled, token == generation else { return }; tickets = page.tickets; failed = false }
        catch is CancellationError {} catch { if token == generation { tickets = []; failed = true } }
    }
    private func remove(_ id: UUID) async {
        guard let request else { return }; do { _ = try await request("recipes", "unticket", .init(recipeID: id)); await load() } catch { failed = true }
    }
}

private enum RecipeManagementSheet: Identifiable {
    case edit(Recipe), history(Recipe), link(Recipe), duplicate(Recipe)
    var id: String { switch self { case .edit: "edit"; case .history: "history"; case .link: "link"; case .duplicate: "duplicate" } }
}
struct RecipeDetailView: View {
    let id: UUID
    var dishID: UUID? = nil // Compatibility for historical entry points; server card is authoritative.
    @Query private var dishes: [Dish]
    @Environment(\.socialRequest) private var request
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var recipe: Recipe?
    @State private var management: RecipeManagementSheet?
    @State private var claim: SocialCookingClaim?
    @State private var list: RankingList?
    @State private var deleting = false
    @State private var detaching = false
    @State private var failed = false
    @State private var busy = false
    @State private var copiedRecipeID: UUID?
    @State private var copyReservation = UUID()
    @State private var reservation = UUID()
    @State private var generation = UUID()
    private var linkedDish: Dish? { dishes.first { $0.id == recipe?.linkedDishID } }
    private var linkedCook: CookingAttempt? { guard let id = recipe?.linkedAttemptID else { return nil }; return dishes.lazy.flatMap(\.attempts).first { $0.id == id } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGTheme.Space.section) {
                if let recipe { reader(recipe) }
                else if !failed { ProgressView("Loading Recipe").frame(maxWidth: .infinity) }
                if failed {
                    Text(recipe?.isOwner == true ? "Offline. Showing your previously opened Recipe. Changes need a connection to save." : "Recipe unavailable, changed, or offline. Your cooking history is unchanged.").font(.subheadline).accessibilityIdentifier("recipe-error")
                    Button("Retry") { Task { await load() } }.buttonStyle(SGButtonStyle())
                }
            }.padding(SGTheme.Space.medium).frame(maxWidth: SGTheme.Size.contentMaximum).frame(maxWidth: .infinity)
        }.background(SGTheme.ColorToken.background).navigationTitle("Recipe").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let recipe {
                    RecipeToolbarActions(url: recipe.visibility == "friends" ? AppRoute.recipeURL(recipe.id) : nil, sendContent: recipe.visibility == "friends" ? .recipe(recipe.id) : nil, disabled: busy) {
                            if recipe.isOwner {
                                Button("Edit Recipe", systemImage: "pencil") { management = .edit(recipe) }.accessibilityIdentifier("recipe-edit")
                                Button("Recipe History", systemImage: "clock") { management = .history(recipe) }.accessibilityIdentifier("recipe-history")
                                Button("Save as New Recipe", systemImage: "document.on.document") { management = .duplicate(recipe) }.accessibilityIdentifier("recipe-save-new")
                            }
                            Button(recipe.linkedAttemptID == nil ? "Link a Dish" : "Change Linked Dish", systemImage: "link") { management = .link(recipe) }.accessibilityIdentifier("recipe-link")
                            if recipe.linkedAttemptID != nil || linkedDish != nil {
                                Button(recipe.linkedAttemptID == nil ? "Unlink Dish Family" : "Unlink Dish", systemImage: "link.badge.plus", role: .destructive) { detaching = true }.accessibilityIdentifier("recipe-detach")
                            }
                            if recipe.isOwner { Button("86 Recipe (Delete)", systemImage: "trash", role: .destructive) { deleting = true }.accessibilityIdentifier("recipe-delete") }
                        }

                }
            }
            .task(id: id) { await load() }.refreshable { await load() }
            .onSocialRefresh { if !busy && recipe?.isOwner != true { await load() } }
            .onChange(of: phase) { _, next in generation = UUID(); if recipe?.isOwner != true { recipe = nil }; if next == .active { Task { await load() } } }
            .onDisappear { generation = UUID() }
            .navigationDestination(item: $copiedRecipeID) { RecipeDetailView(id: $0) }
            .sheet(item: $management, onDismiss: { Task { await load() } }) { sheet in
                switch sheet {
                case .edit(let r): RecipeEditor(recipe: r) { recipe = $0 }
                case .history(let r): RecipeHistoryView(recipe: r) { recipe = $0 }
                case .link(let r): RecipeDishLinker(recipe: r) {}
                case .duplicate(let r): RecipeEditor(draft: r.content, initiallyShared: false) { _ in }
                }
            }
            .sheet(item: $claim, onDismiss: { reservation = UUID() }) { claim in if let list { AddCookingView(list: list, dish: linkedDish, origin: claim) } }
            .confirmationDialog("Unlink this Recipe?", isPresented: $detaching, titleVisibility: .visible) {
                Button("Unlink", role: .destructive) { Task { await detach() } }
            } message: { Text("Only the current link is removed. The Recipe, cooks, photos and saved Recipe-used snapshots stay intact.") }
            .confirmationDialog("86 this Recipe?", isPresented: $deleting, titleVisibility: .visible) {
                Button("86 Recipe", role: .destructive) { Task { await delete() } }
            } message: { Text("This removes the Recipe and its current links and can’t be undone. Dishes, cooks, rankings and saved cook snapshots stay intact.") }
    }
    private func reader(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.section) {
            RecipePhoto(id: recipe.content.photoID, dish: linkedDish, name: recipe.content.title, cook: linkedCook, exactCookLink: recipe.linkedAttemptID != nil)
                .sgPhotoFrame(.hero).accessibilityIdentifier("recipe-hero")
            VStack(alignment: .leading, spacing: SGTheme.Space.stack) {
                Text(recipe.content.title).font(SGTheme.TypeRole.hero).accessibilityAddTraits(.isHeader).accessibilityIdentifier("recipe-title")
                let metadata = [recipe.content.cuisine,recipe.content.course.flatMap { DishCategory(rawValue: $0)?.label }].compactMap { $0 }.joined(separator: " · ")
                if !metadata.isEmpty { Text(metadata).font(.subheadline).foregroundStyle(.secondary) }
                if let creator = RecipeSharingPolicy.creatorCredit(recipe) {
                    Text("Created by \(creator)").font(.subheadline).accessibilityIdentifier("recipe-attribution")
                    if !recipe.isOwner, let added = recipe.creator, added.displayName.caseInsensitiveCompare(creator) != .orderedSame { Text("Added by \(added.displayName)").font(.subheadline) }
                }
                if let description = recipe.content.description, !description.isEmpty { Text(description).font(.body).lineSpacing(6) }
            }
            Button { Task { await begin() } } label: { Label("Rank My Version", systemImage: "fork.knife").frame(maxWidth: .infinity) }
                .buttonStyle(SGButtonStyle(prominent: true)).disabled(busy).accessibilityIdentifier("recipe-make")
            if !recipe.isOwner { Button("Save a Private Copy") { Task { await copyRecipe() } }.frame(minHeight: 44).disabled(busy).accessibilityIdentifier("recipe-fork") }
            if let cook = linkedCook {
                NavigationLink { AttemptDetailView(attempt: cook) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) { Text(cook.dish?.name ?? cook.displayName); CookVersionIdentity(cook: cook) }
                        Image(systemName: "chevron.right")
                    }
                }.accessibilityIdentifier("recipe-linked-cook")
            } else if recipe.linkedAttemptID != nil { Text("Linked Dish unavailable").foregroundStyle(.secondary) }
            else if let dish = linkedDish {
                Text("Dish family · \(dish.name)").font(.subheadline)
            }
            RecipeReadingBody(content: recipe.content, allowScaling: true)
            Divider()
            VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                if let source = recipe.content.source, !source.isEmpty { Text("Source · \(source)") }
                if let url = recipe.content.externalURL.flatMap(URL.init(string:)) { Link("Original source", destination: url) }
                if recipe.isOwner { RecipeForkAttribution(recipeID: recipe.id) }
                Text("Revision \(recipe.revision) · \(recipe.visibility == "friends" ? "Shared with current Sous Chefs" : "Private Recipe")").font(.caption).foregroundStyle(.secondary)
            }.font(.subheadline)
        }
    }
    private func load() async {
        guard let request else { failed = true; return }; let token = UUID(); generation = token; failed = false
        do { let next = try await RecipeService.recipe("get", id: id, request: request); guard !Task.isCancelled, generation == token else { return }; recipe = next }
        catch is CancellationError {} catch {
            if generation == token {
                let offline = (error as? URLError).map { [.notConnectedToInternet,.networkConnectionLost,.timedOut,.cannotConnectToHost,.cannotFindHost,.dnsLookupFailed].contains($0.code) } ?? false
                if recipe?.isOwner != true || !offline { recipe = nil }; failed = true
            }
        }
    }
    private func begin() async {
        guard let request else { return }; busy = true; defer { busy = false }
        do { let next = try await RecipeService.begin(id: id, reservation: reservation, request: request); try Task.checkCancellation(); list = try CookingStore.globalRanking(context: context); claim = next }
        catch is CancellationError {} catch { failed = true }
    }
    private func detach() async {
        guard let request, let recipe else { return }; busy = true; defer { busy = false }
        do {
            var payload = SocialPayload(); payload.recipeID = id
            if let cookID = recipe.linkedAttemptID { payload.previousAttemptID = cookID; _ = try await request("recipes", "unlink_cook", payload) }
            else if let linkedID = linkedDish?.id { payload.dishID = linkedID; _ = try await request("recipes", "detach", payload) }
            try Task.checkCancellation(); NotificationCenter.default.post(name: .socialContentChanged, object: nil); await load()
        } catch is CancellationError {} catch { failed = true }
    }
    private func copyRecipe() async {
        guard let request else { return }; busy = true; defer { busy = false }
        do {
            let copy = try JSONDecoder().decode(Recipe.self, from: await request("recipes", "fork", .init(targetID: copyReservation, confirmed: true, recipeID: id)))
            try Task.checkCancellation(); copiedRecipeID = copy.id; NotificationCenter.default.post(name: .socialContentChanged, object: nil)
        } catch is CancellationError {} catch { failed = true }
    }
    private func delete() async {
        guard let request else { return }
        do { _ = try await request("recipes", "delete", .init(recipeID: id)); try Task.checkCancellation(); NotificationCenter.default.post(name: .socialContentChanged, object: nil); dismiss() } catch { failed = true }
    }
}

struct RecipeCookingProvenance: View {
    let itemID: UUID
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @State private var cooks: [RecipeCookSnapshot] = []
    @State private var failed = false
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            ForEach(cooks) { cook in
                Text("Recipe · \(cook.snapshot.title)").font(.headline)
                if let creator = cook.creatorName { Text("Created by \(creator)").font(.subheadline) }
                if let source = cook.snapshot.source { Text("Source · \(source)").font(.subheadline) }
                Text("Recipe revision \(cook.revision) when this cook began").font(.caption).foregroundStyle(.secondary)
                NavigationLink("View recipe used for this cook") { RecipeSnapshotView(cook: cook) }
            }
            if failed { Button("Retry recipe provenance") { Task { await load() } } }
        }.task(id: itemID) { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
            .onChange(of: phase) { _, next in cooks = []; if next == .active { Task { await load() } } }
    }
    private func load() async {
        guard let request else { return }
        do { let page = try JSONDecoder().decode(RecipeCooksPage.self, from: await request("recipes", "provenance", .init(targetID: itemID))); try Task.checkCancellation(); cooks = page.cooks; failed = false }
        catch is CancellationError {} catch { cooks = []; failed = true }
    }
}
struct RecipeSnapshotView: View {
    let cook: RecipeCookSnapshot
    var body: some View {
        List {
            Text(cook.snapshot.title).font(.title2.bold())
            if let creator = cook.creatorName { Text("Created by \(creator)").font(.subheadline).accessibilityIdentifier("recipe-snapshot-creator") }
            if let description = cook.snapshot.description { Text(description) }
            if let source = cook.snapshot.source { Text("Source · \(source)") }
            RecipeReadingBody(content: cook.snapshot)
            if let id = cook.recipeID { NavigationLink("Current recipe") { RecipeDetailView(id: id) } }
            else { Text("Original recipe is no longer available. This is your historical snapshot.") }
        }.navigationTitle("Recipe used").navigationBarTitleDisplayMode(.inline)
    }
}

struct RecipeSummaryRow: View {
    let recipe: Recipe
    var ticket: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            SGEyebrow(text: ticket ? "Ticket · Want to cook" : "Recipe")
            Text(recipe.content.title).font(SGTheme.TypeRole.title).foregroundStyle(SGTheme.ColorToken.primaryText).fixedSize(horizontal: false, vertical: true)
            if let source = recipe.content.source { Text(source).font(SGTheme.TypeRole.body).foregroundStyle(.secondary) }
            Text("\(recipe.content.ingredients.count) ingredient\(recipe.content.ingredients.count == 1 ? "" : "s") · \(recipe.content.steps.count) step\(recipe.content.steps.count == 1 ? "" : "s")").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
        }.padding(.vertical, SGTheme.Space.medium).contentShape(Rectangle())
    }
}

private struct RecipeTextActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(minHeight: 44).contentShape(Rectangle())
            .foregroundStyle(SGTheme.ColorToken.accent).opacity(configuration.isPressed ? 0.6 : 1)
    }
}
