import SwiftUI
import SwiftData
import Supabase

/// Stage F: one Add Recipe flow for Food Bible and Dish Detail (FOOD_ARCHITECTURE §7.1).
/// Dish and Recipe are one Dish, so every path ends with the Recipe on exactly one Dish:
/// - Food Bible: New Dish + Recipe (Paste / Add Manually, then Rank Now or Not Now), or
///   Add to a Ranked Dish (choose a ranked Dish without a Recipe, then Paste / Add Manually).
/// - Dish Detail: Paste / Add Manually, or Use a Food Bible Recipe (its uncooked Dish merges
///   into this Dish's identity).
struct AddRecipeFlow: View {
    enum Context { case library, dish(Dish) }
    let context: Context
    var entries: [CookbookEntry] = []
    var onFinish: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.socialRequest) private var request
    @Query(sort: \Dish.name) private var dishes: [Dish]
    @State private var target: Dish?
    @State private var choosingDish = false
    @State private var mode: RecipeCreationMode?
    @State private var usingExisting = false
    @State private var saved: Recipe?
    @State private var claim: SocialCookingClaim?
    @State private var list: RankingList?
    @State private var busy = false
    @State private var failed = false

    private var dish: Dish? { if case .dish(let value) = context { return value }; return target }
    private var isLibrary: Bool { if case .library = context { return true }; return false }
    /// Ranked Dishes that do not have a Recipe yet (a Dish has at most one Recipe).
    private var rankedWithoutRecipe: [Dish] {
        let withRecipe = Set(entries.compactMap(\.dishID))
        return dishes.filter { !$0.attempts.isEmpty && !withRecipe.contains($0.id) }
    }

    var body: some View {
        if choosingDish {
            DishSelectionView(dishes: rankedWithoutRecipe, onSelect: { target = $0; choosingDish = false }, onCancel: { choosingDish = false })
        } else {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: SGTheme.Space.large) {
                        if let saved { rankPrompt(saved) } else if let dish { dishSources(dish) } else { librarySources }
                        if failed { Text("Couldn’t start ranking. Try again from the Recipe.").font(.footnote).accessibilityIdentifier("add-recipe-error") }
                    }.padding(SGTheme.Space.readingMargin).frame(maxWidth: SGTheme.Size.contentMaximum).frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(SGTheme.ColorToken.background)
                .navigationTitle(saved == nil ? "Add Recipe" : "Recipe Saved").navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $mode) { mode in composer(mode) }
                .navigationDestination(isPresented: $usingExisting) {
                    if let dish { ExistingRecipePicker(dish: dish) { finish() } }
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { finish() }.disabled(busy).accessibilityIdentifier("add-recipe-done") } }
                .sheet(item: $claim, onDismiss: { finish() }) { claim in
                    if let list { AddCookingView(list: list, dish: localDish(saved), origin: claim) }
                }
            }
        }
    }

    // MARK: Steps

    @ViewBuilder private var librarySources: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            SGSectionHeader(title: "New Dish + Recipe")
            Text("Keep a recipe, whether you’ve cooked it yet or not.").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            sourceButtons(importID: "bible-import", manualID: "bible-manual")
        }
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            SGSectionHeader(title: "Add to a Ranked Dish")
            Button { choosingDish = true } label: {
                SGDestinationLabel(title: "Choose a Ranked Dish", subtitle: rankedWithoutRecipe.isEmpty ? "Every ranked Dish already has a Recipe" : "Give a Dish you’ve cooked its Recipe", symbol: "fork.knife")
            }.buttonStyle(.plain).disabled(rankedWithoutRecipe.isEmpty).accessibilityIdentifier("bible-ranked-dish")
        }
    }

    @ViewBuilder private func dishSources(_ dish: Dish) -> some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            SGEyebrow(text: "Recipe for")
            Text(dish.name).font(SGTheme.TypeRole.title).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("add-recipe-dish")
            if isLibrary {
                Button("Choose Another Dish") { target = nil; choosingDish = true }.font(.subheadline).frame(minHeight: SGTheme.Size.minimumTap)
            }
        }
        sourceButtons(importID: "dish-recipe-import", manualID: "dish-recipe-manual")
        if !isLibrary {
            Button { usingExisting = true } label: {
                SGDestinationLabel(title: "Use a Food Bible Recipe", subtitle: "One you saved but haven’t cooked yet", symbol: "book")
            }.buttonStyle(.plain).accessibilityIdentifier("dish-recipe-existing")
        }
    }

    private func sourceButtons(importID: String, manualID: String) -> some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            Button { mode = .imported } label: {
                VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                    Label("Paste Recipe", systemImage: "doc.text").font(.headline)
                    Text("Paste a full recipe and organize it for review.").font(.subheadline)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(SGTheme.Space.medium)
            }.buttonStyle(SGButtonStyle()).accessibilityIdentifier(importID)
            Button { mode = .manual } label: {
                Label("Add Manually", systemImage: "square.and.pencil").frame(maxWidth: .infinity, alignment: .leading).padding(SGTheme.Space.medium)
            }.buttonStyle(SGButtonStyle()).accessibilityIdentifier(manualID)
        }
    }

    @ViewBuilder private func composer(_ mode: RecipeCreationMode) -> some View {
        if mode == .imported {
            RecipeImportView(dish: dish, done: { self.mode = nil }, onSaved: { recipeSaved($0) })
        } else {
            RecipeEditor(dishID: dish?.id, title: dish?.name ?? "", course: dish?.defaultCategoryCode, cuisine: dish?.cuisineLabel) { recipeSaved($0) }
        }
    }

    /// New Dish + Recipe: offer to rank it now. A Recipe for an existing Dish is finished.
    private func rankPrompt(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            SGEyebrow(text: "Saved to Food Bible")
            Text(localDish(recipe)?.name ?? recipe.content.title).font(SGTheme.TypeRole.title).fixedSize(horizontal: false, vertical: true)
            Text("Cooked it already? Rank it now to place it in your Grub Rank.").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            Button { Task { await rankNow(recipe) } } label: { Label("Rank Now", systemImage: "fork.knife").frame(maxWidth: .infinity) }
                .buttonStyle(SGButtonStyle(prominent: true)).disabled(busy).accessibilityIdentifier("rank-prompt-rank")
            Button("Not Now") { finish() }.frame(maxWidth: .infinity, minHeight: SGTheme.Size.minimumTap).disabled(busy).accessibilityIdentifier("rank-prompt-not-now")
        }.accessibilityElement(children: .contain).accessibilityIdentifier("rank-prompt")
    }

    // MARK: Actions

    private func recipeSaved(_ recipe: Recipe) {
        mode = nil
        if dish == nil { saved = recipe } else { finish() }
    }
    private func localDish(_ recipe: Recipe?) -> Dish? {
        guard let id = recipe?.dishID else { return nil }
        return dishes.first { $0.id == id }
    }
    private func rankNow(_ recipe: Recipe) async {
        guard let request else { failed = true; return }
        busy = true; defer { busy = false }
        do {
            let next = try await RecipeService.begin(id: recipe.id, reservation: UUID(), request: request)
            try Task.checkCancellation()
            list = try CookingStore.globalRanking(context: modelContext); failed = false; claim = next
        } catch is CancellationError {} catch { failed = true }
    }
    private func finish() { onFinish(); dismiss() }
}

/// Dish Detail → Use a Food Bible Recipe: an owned Recipe whose Dish has no cooks yet becomes this
/// Dish's Recipe. The Recipe keeps its content and history; only its Dish identity moves, and the
/// empty Dish it leaves is removed. A cooked Dish's Recipe is never moved (that would orphan its cooks).
struct ExistingRecipePicker: View {
    let dish: Dish
    let done: () -> Void
    @Environment(\.socialRequest) private var request
    @Environment(\.modelContext) private var modelContext
    @Query private var dishes: [Dish]
    @State private var entries: [CookbookEntry] = []
    @State private var query = ""
    @State private var loading = true
    @State private var failure: String?
    @State private var choosing: CookbookEntry?
    @State private var busy = false

    private var candidates: [CookbookEntry] {
        let local = Dictionary(uniqueKeysWithValues: dishes.map { ($0.id, $0) })
        return entries.filter { entry in
            guard let id = entry.dishID, id != dish.id, let owner = local[id] else { return false }
            return owner.attempts.isEmpty
        }.filter { CookbookSearch.matches($0.searchableText, query: query) }
            .sorted { $0.recipeTitle.localizedStandardCompare($1.recipeTitle) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SGTheme.Space.small) {
                if loading { SGLoadingState(label: "Loading your Recipes") }
                if !loading && candidates.isEmpty {
                    SGContentState(title: query.isEmpty ? "No uncooked Recipes" : "No matching Recipes", symbol: "book.closed",
                                   message: query.isEmpty ? "Recipes you’ve saved but not cooked yet appear here." : "Try another search.") { EmptyView() }
                }
                ForEach(candidates) { entry in
                    Button { choosing = entry } label: {
                        SGDestinationLabel(title: entry.recipeTitle, subtitle: entry.cuisine ?? "", symbol: "book")
                    }.buttonStyle(.plain).disabled(busy).accessibilityIdentifier("existing-recipe-\(entry.recipeID)")
                }
                if let failure { Text(failure).font(.footnote).accessibilityIdentifier("existing-recipe-error") }
            }.padding(SGTheme.Space.medium)
        }
        .safeAreaInset(edge: .top) {
            SGSearchField(placeholder: "Search Recipes", text: $query, identifier: "existing-recipe-search")
                .padding(SGTheme.Space.medium).background(SGTheme.ColorToken.background)
        }
        .scrollDismissesKeyboard(.interactively).background(SGTheme.ColorToken.background)
        .navigationTitle("Use a Recipe").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .confirmationDialog("Use this Recipe for \(dish.name)?", isPresented: Binding(get: { choosing != nil }, set: { if !$0 { choosing = nil } }), titleVisibility: .visible) {
            Button("Use Recipe") { if let choosing { Task { await use(choosing) } } }.accessibilityIdentifier("existing-recipe-confirm")
        } message: { Text("It becomes this Dish’s Recipe and leaves Food Bible’s not-cooked list. Its content and Recipe History stay the same.") }
    }

    private func load() async {
        guard let request else { loading = false; failure = DishRecipeService.message(for: URLError(.notConnectedToInternet)); return }
        loading = true; defer { loading = false }
        do { entries = try await CookbookIndex.load(request: request); failure = nil }
        catch is CancellationError {} catch { failure = DishRecipeService.message(for: error) }
    }
    private func use(_ entry: CookbookEntry) async {
        guard let request else { return }
        busy = true; defer { busy = false }
        do {
            var payload = SocialPayload(); payload.recipeID = entry.recipeID; payload.recipeDishID = dish.id
            let moved = try JSONDecoder().decode(Recipe.self, from: await request("recipes", "set_dish", payload))
            guard moved.dishID == dish.id else { throw URLError(.cannotParseResponse) }
            // The Recipe's previous, never-cooked Dish identity is now empty; remove it locally (synced).
            try? DishIdentityStore.removeIfUncooked(id: entry.dishID, context: modelContext)
            NotificationCenter.default.post(name: .socialContentChanged, object: nil)
            done()
        } catch { failure = DishRecipeService.message(for: error) }
    }
}
