import SwiftUI
import SwiftData

/// Cook Again start (FOOD_ARCHITECTURE §7.2). When the Dish has a Recipe, the first step offers
/// "Cook from [Recipe]" (a Recipe-origin cook that records the exact revision used) or "Without the
/// Recipe". Nothing is preselected or recorded as used unless chosen. A Dish without a Recipe goes
/// straight to the cook form, which then offers "Add a Recipe?" after ranking.
struct CookAgainFlow: View {
    let list: RankingList
    let dish: Dish
    /// The Dish's Recipe when the host already knows it; otherwise it is loaded here.
    var knownRecipe: Recipe? = nil
    /// True when the host knows whether the Dish has a Recipe (skips the lookup).
    var recipeKnown = false
    var onResultClose: () -> Void = {}
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @State private var recipe: Recipe?
    @State private var loaded = false
    @State private var choice: Choice?
    @State private var claim: SocialCookingClaim?
    @State private var busy = false
    @State private var failed = false
    private enum Choice { case recipe, without }

    var body: some View {
        Group {
            if choice == .without || (loaded && recipe == nil) {
                AddCookingView(list: list, dish: dish, offersRecipe: recipe == nil, onResultClose: onResultClose)
            } else if choice == .recipe, let claim {
                AddCookingView(list: list, dish: dish, origin: claim, onResultClose: onResultClose)
            } else if loaded, let recipe {
                start(recipe)
            } else {
                NavigationStack { SGLoadingState(label: "Checking this Dish’s Recipe").frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(SGTheme.ColorToken.background)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } } }
            }
        }
        .task { await load() }
    }

    private func start(_ recipe: Recipe) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
                    SGEyebrow(text: "Cook Again")
                    Text(dish.name).font(SGTheme.TypeRole.title).fixedSize(horizontal: false, vertical: true)
                    Button { Task { await cookFromRecipe(recipe) } } label: {
                        SGDestinationLabel(title: "Cook from the Recipe", subtitle: recipe.content.title + " · records the revision you used", symbol: "book")
                    }.buttonStyle(.plain).disabled(busy).accessibilityIdentifier("cook-again-recipe")
                    Button { choice = .without } label: {
                        SGDestinationLabel(title: "Without the Recipe", subtitle: "Cook it your way this time", symbol: "fork.knife")
                    }.buttonStyle(.plain).disabled(busy).accessibilityIdentifier("cook-again-without")
                    if failed { Text("Couldn’t start from the Recipe. Try again or cook without it.").font(.footnote).accessibilityIdentifier("cook-again-error") }
                }.padding(SGTheme.Space.readingMargin).frame(maxWidth: SGTheme.Size.contentMaximum).frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(SGTheme.ColorToken.background)
            .navigationTitle("Cook Again").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) } }
        }
    }

    private func load() async {
        guard !loaded else { return }
        if recipeKnown || request == nil { recipe = knownRecipe; loaded = true; return }
        do {
            struct DishResponse: Decodable { var recipe: Recipe? }
            var payload = SocialPayload(); payload.dishID = dish.id
            recipe = try JSONDecoder().decode(DishResponse.self, from: await request!("recipes", "dish", payload)).recipe
        } catch { recipe = nil } // Offline or unavailable: cook without the Recipe, as before.
        loaded = true
    }
    private func cookFromRecipe(_ recipe: Recipe) async {
        guard let request else { failed = true; return }
        busy = true; defer { busy = false }
        do {
            claim = try await RecipeService.begin(id: recipe.id, reservation: UUID(), request: request)
            failed = false; choice = .recipe
        } catch { failed = true }
    }
}
