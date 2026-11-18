import SwiftUI
import SwiftData

/// The standalone Recipe reader (deep links, Saved Recipes, other creators' Recipes, The Pass). An owner's Recipe with a local Dish also opens in that Dish's page.
struct RecipeDetailView: View {
    let id: UUID
    var dishID: UUID? = nil // Compatibility for historical entry points; server card is authoritative.
    @Query private var dishes: [Dish]
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var model = RecipeReaderModel()
    @State private var openingDish: Dish?
    private var recipe: Recipe? { model.recipe }
    private var linkedCook: CookingAttempt? { guard let id = recipe?.linkedAttemptID else { return nil }; return dishes.lazy.flatMap(\.attempts).first { $0.id == id } }
    /// D2: the Dish this Recipe is shown for: the Dish it was opened from (Dish Detail, or the Dish
    /// Food Bible named), else its exact-linked cook's Dish, else the legacy family Dish.
    private var relatedDish: Dish? {
        if let id = recipe?.dishID ?? dishID, let dish = dishes.first(where: { $0.id == id }) { return dish }
        if let dish = linkedCook?.dish { return dish }
        return recipe?.linkedDishID.flatMap { id in dishes.first { $0.id == id } }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGTheme.Space.section) {
                if let recipe {
                    // Connected UI: an owner's Recipe with a local Dish opens into that Dish's page.
                    if recipe.isOwner, let dish = relatedDish {
                        Button { openingDish = dish } label: { Label("Open \(dish.name)", systemImage: "rectangle.stack") }
                            .frame(minHeight: 44).accessibilityIdentifier("recipe-open-dish")
                    }
                    RecipeReaderContent(model: model, recipe: recipe, relatedDish: relatedDish, linkedCook: linkedCook)
                }
                else if !model.failed { SGLoadingState(label: "Loading Recipe") }
                if model.failed {
                    Text(recipe?.isOwner == true ? "Offline. Showing your previously opened Recipe. Changes need a connection to save." : "Recipe unavailable, changed, or offline. Your cooking history is unchanged.").font(SGTheme.TypeRole.body).accessibilityIdentifier("recipe-error")
                    Button("Retry") { Task { await load() } }.buttonStyle(SGButtonStyle())
                }
            }.padding(SGTheme.Space.medium).frame(maxWidth: SGTheme.Size.contentMaximum).frame(maxWidth: .infinity)
        }.background(SGTheme.ColorToken.background).navigationTitle("Recipe").navigationBarTitleDisplayMode(.inline)
            .toolbar { RecipeReaderToolbar(model: model) }
            .task(id: id) { await load() }.refreshable { await load() }
            .onSocialRefresh { if !model.busy && recipe?.isOwner != true { await load() } }
            .onChange(of: phase) { _, next in model.cancelPending(); if recipe?.isOwner != true { model.recipe = nil }; if next == .active { Task { await load() } } }
            .onChange(of: model.deleted) { _, deleted in if deleted { dismiss() } }
            .onDisappear { model.cancelPending() }
            .navigationDestination(item: $openingDish) { DishView(dish: $0, tab: .recipe) }
            .recipeReaderPresentation(model, relatedDish: relatedDish) { await load() }
    }
    private func load() async { await model.load(id: id, request: request) }
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
                Text("Recipe · \(cook.snapshot.title)").font(SGTheme.TypeRole.headline)
                if let creator = cook.creatorName { Text("Created by \(creator)").font(SGTheme.TypeRole.body) }
                if let source = cook.snapshot.source { Text("Source · \(source)").font(SGTheme.TypeRole.body) }
                Text("Recipe revision \(cook.revision) when this cook began").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
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
            if let creator = cook.creatorName { Text("Created by \(creator)").font(SGTheme.TypeRole.body).accessibilityIdentifier("recipe-snapshot-creator") }
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
