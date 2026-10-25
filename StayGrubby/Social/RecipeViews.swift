import SwiftUI
import SwiftData

/// Preserved standalone recipes are explicitly separate from the derived cookbook.
struct RecipeLibraryView: View {
    var dishID: UUID? = nil
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var generation = UUID()
    @State private var recipes: [Recipe] = []
    @State private var creating = false
    @State private var failed = false
    @State private var loading = true
    var body: some View {
        SGEditorialList {
            Text(dishID == nil ? "Recipes not yet linked to a cooked dish stay safe here. Make one, or link it from Dish Detail, to add it to your cookbook." : "Choose a saved recipe for this dish. Nothing in your cooking history will change.")
            ForEach(recipes) { recipe in
                if dishID != nil { Button(recipe.content.title) { Task { await attach(recipe) } } }
                else { NavigationLink { RecipeDetailView(id: recipe.id) } label: { RecipeSummaryRow(recipe: recipe, ticket: false) }.accessibilityLabel(recipe.content.title) }
            }
            if loading { ProgressView() }
            if failed { Text("Recipes unavailable. Check your connection."); Button("Retry") { Task { await load() } } }
            if !loading && recipes.isEmpty { Text("No saved recipes yet.") }

        }.navigationTitle(dishID == nil ? "Saved Recipes" : "Choose Recipe").navigationBarTitleDisplayMode(.inline)
            .task { await load() }.refreshable { await load() }
            .onChange(of: phase) { _, next in generation = UUID(); recipes = []; if next == .active { Task { await load() } } }
            .onDisappear { generation = UUID() }
            .sheet(isPresented: $creating, onDismiss: { Task { await load() } }) { RecipeEditor { _ in } }
            .toolbar { if dishID != nil { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } } }
    }
    private func load() async {
        guard let request else { loading = false; failed = true; return }; let token = UUID(); generation = token; loading = true
        defer { if generation == token { loading = false } }
        do { let page = try JSONDecoder().decode(RecipesPage.self, from: await request("recipes", "list", .init())); guard !Task.isCancelled, token == generation else { return }; recipes = page.recipes; failed = false }
        catch is CancellationError {} catch { if generation == token { recipes = []; failed = true } }
    }
    private func attach(_ recipe: Recipe) async {
        guard let request, let dishID else { return }
        do { _ = try await request("recipes", "attach", .init(dishID: dishID, recipeID: recipe.id)); try Task.checkCancellation(); NotificationCenter.default.post(name: .socialContentChanged, object: nil); dismiss() } catch { failed = true }
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
            SGPageIntro(title: "Want to cook", subtitle: "Save the next good idea. Only a completed cook enters Grub Rank.", eyebrow: "Tickets")
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
        }.navigationTitle("Tickets").navigationBarTitleDisplayMode(.inline).task { await load() }.refreshable { await load() }
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

struct RecipeDetailView: View {
    let id: UUID
    var dishID: UUID? = nil
    @Query private var dishes: [Dish]
    @Environment(\.socialRequest) private var request
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var recipe: Recipe?
    @State private var claim: SocialCookingClaim?
    @State private var list: RankingList?
    @State private var editingRecipe: Recipe? = nil
    @State private var deleting = false
    @State private var detaching = false
    @State private var failed = false
    @State private var busy = false
    @State private var reservation = UUID()
    @State private var generation = UUID()
    private var linkedDish: Dish? { dishes.first { $0.id == (dishID ?? recipe?.linkedDishID) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let recipe { reader(recipe) }
                else if !failed { ProgressView("Loading recipe").frame(maxWidth: .infinity) }
                if failed {
                    Text(recipe?.isOwner == true ? "Offline. Showing your previously opened recipe. Changes need a connection to save." : "Recipe unavailable, changed, or offline. Your cooking history is unchanged.").font(.subheadline).accessibilityIdentifier("recipe-error")
                    Button("Retry") { Task { await load() } }.buttonStyle(SGButtonStyle())
                }
            }.padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.background(SGTheme.ColorToken.background).navigationTitle("Recipe").navigationBarTitleDisplayMode(.inline)
            .toolbar { if let recipe, recipe.isOwner { ToolbarItem(placement: .primaryAction) { Button("Edit Recipe", systemImage: "pencil") { editingRecipe = recipe }.accessibilityIdentifier("recipe-edit") } } }
            .task(id: id) { await load() }.refreshable { await load() }
            .onChange(of: phase) { _, next in generation = UUID(); if recipe?.isOwner != true { recipe = nil }; if next == .active { Task { await load() } } }
            .onDisappear { generation = UUID() }
            .sheet(item: $editingRecipe, onDismiss: { Task { await load() } }) { snapshot in RecipeEditor(recipe: snapshot, dishID: dishID ?? snapshot.linkedDishID) { self.recipe = $0 } }
            .sheet(item: $claim, onDismiss: { reservation = UUID() }) { claim in if let list { AddCookingView(list: list, dish: linkedDish, origin: claim) } }
            .confirmationDialog("Remove Recipe from this Dish?", isPresented: $detaching, titleVisibility: .visible) {
                Button("Remove Recipe from Dish", role: .destructive) { Task { await detach() } }
            } message: { Text("The saved recipe stays available. This Dish leaves Food Bible; cooking history, photos and ranking stay intact.") }
            .confirmationDialog("Delete this recipe?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete Recipe", role: .destructive) { Task { await delete() } }
            } message: { Text("This deletes the saved recipe and its references. Dishes, cooks, rankings and photos stay intact; saved cook snapshots remain.") }
    }
    private func reader(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            Group {
                if let media = linkedDish?.cookbookRepresentativeCook?.primaryImage { DishPhoto(media: media, name: recipe.content.title) }
                else { CookbookPhoto(dish: nil, name: recipe.content.title) }
            }.frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 16)).accessibilityIdentifier("recipe-hero")
            VStack(alignment: .leading, spacing: 12) {
                SGEyebrow(text: linkedDish == nil ? "Recipe" : "From your Food Bible")
                Text(recipe.content.title).font(SGTheme.TypeRole.hero).accessibilityAddTraits(.isHeader).accessibilityIdentifier("recipe-title")
                Text([recipe.content.cuisine,recipe.content.course.flatMap { DishCategory(rawValue: $0)?.label }].compactMap { $0 }.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
                if let introduction = recipe.content.description, !introduction.isEmpty { Text(introduction).font(.body).lineSpacing(6) }
            }
            RecipeReadingBody(content: recipe.content)
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                if let creator = recipe.content.originalCreator, !creator.isEmpty { Text("Original creator · \(creator)") }
                if let source = recipe.content.source, !source.isEmpty { Text("Source · \(source)") }
                if let url = recipe.content.externalURL.flatMap(URL.init(string:)) { Link("Original source", destination: url) }
                if let creator = recipe.creator { Text("Added by \(creator.displayName)") }
                Text("Revision \(recipe.revision) · \(recipe.visibility == "friends" ? "Shared with current Sous Chefs" : "Private recipe")").font(.caption).foregroundStyle(.secondary)
                if let attempt = linkedDish?.cookbookRepresentativeCook { NavigationLink("View Dish & Versions") { AttemptDetailView(attempt: attempt) }.frame(minHeight: 44) }
            }.font(.subheadline)
            Button { Task { await begin() } } label: { Label(linkedDish == nil ? "Make This" : "Cook It Again", systemImage: "fork.knife").frame(maxWidth: .infinity) }.buttonStyle(SGButtonStyle(prominent: true)).disabled(busy).accessibilityIdentifier("recipe-make")
            Text("Review your cook, then rank it. Your recipe stays just as you saved it.").font(.footnote).foregroundStyle(.secondary)
            if dishID != nil { Button("Remove Recipe from Dish", role: .destructive) { detaching = true }.frame(minHeight: 44).accessibilityIdentifier("recipe-detach") }
            if recipe.isOwner { Button("Delete Recipe", role: .destructive) { deleting = true }.frame(minHeight: 44).disabled(busy) }
        }
    }
    private func load() async {
        guard let request else { failed = true; return }; let token = UUID(); generation = token; failed = false
        do { let next = try await RecipeService.recipe("get", id: id, request: request); guard !Task.isCancelled, generation == token else { return }; recipe = next }
        catch is CancellationError {} catch {
            if generation == token {
                let offline = (error as? URLError).map { [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed].contains($0.code) } ?? false
                if recipe?.isOwner != true || !offline { recipe = nil }
                failed = true
            }
        }
    }
    private func begin() async {
        guard let request else { return }; busy = true; defer { busy = false }
        do { let next = try await RecipeService.begin(id: id, reservation: reservation, request: request); try Task.checkCancellation(); list = try CookingStore.globalRanking(context: context); claim = next }
        catch is CancellationError {} catch { failed = true }
    }
    private func detach() async {
        guard let request, let dishID else { return }
        do { _ = try await request("recipes", "detach", .init(dishID: dishID, recipeID: id)); try Task.checkCancellation(); NotificationCenter.default.post(name: .socialContentChanged, object: nil); dismiss() } catch { failed = true }
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
        VStack(alignment: .leading, spacing: 6) {
            ForEach(cooks) { cook in
                Text("Recipe · \(cook.snapshot.title)").font(.headline)
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
