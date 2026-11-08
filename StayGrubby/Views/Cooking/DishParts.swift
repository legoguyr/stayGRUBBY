import SwiftUI
import SwiftData
import Supabase

// D2 Unified Dish Detail parts (FOOD_ARCHITECTURE §8). Each part owns one record and is
// shared by Dish Detail (from Grub Rank) and the Recipe reader (from Food Bible).

/// Dish name, the selected cook's name, its score and global rank.
struct DishIdentityHeader: View {
    let attempt: CookingAttempt
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            SGEyebrow(text: globalRank == 1 ? "Signature Dish" : "From your Grub Rank")
            Text(attempt.dish?.name ?? "Dish").font(SGTheme.TypeRole.hero)
                .fixedSize(horizontal: false, vertical: true)
            if let name = attempt.meaningfulVersionLabel {
                Text(name).font(SGTheme.TypeRole.body).foregroundStyle(.secondary).accessibilityIdentifier("detail-cook-name")
            }
            HStack(spacing: SGTheme.Space.small) {
                if let item = attempt.rankedItem { ScoreBadge(score: item.score) }
                if let globalRank { Text("#\(globalRank) overall").font(SGTheme.TypeRole.body).foregroundStyle(.secondary) }
            }
        }
    }
    private var globalRank: Int? {
        guard let item = attempt.rankedItem, let ordered = item.list?.orderedItems,
              let index = ordered.firstIndex(where: { $0.id == item.id }) else { return nil }
        return index + 1
    }
}

/// Every cook of one Dish with name, global rank, gated score and date. Rename and Cook Again
/// are offered by the host. `current` marks the cook Dish Detail is showing.
struct DishCooksSection: View {
    let dish: Dish
    var current: CookingAttempt? = nil
    /// Destination-based rows for hosts outside the Grub Rank stack (the Recipe reader).
    var linksByDestination = false
    var title = "Cooks"
    var cookAgain: (() -> Void)? = nil
    var rename: ((CookingAttempt) -> Void)? = nil
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            if textSize.isAccessibilitySize || cookAgain == nil {
                SGSectionHeader(title: title)
                if let cookAgain { cookAgainButton(cookAgain) }
            } else if let cookAgain {
                SGSectionHeader(title: title) { cookAgainButton(cookAgain) }
            }
            ForEach(entries, id: \.attempt.id) { entry in
                if entry.attempt.id == current?.id {
                    row(entry.attempt, rank: entry.rank, current: true)
                } else if linksByDestination {
                    NavigationLink { AttemptDetailView(attempt: entry.attempt) } label: { row(entry.attempt, rank: entry.rank, current: false) }
                        .buttonStyle(.plain)
                } else {
                    NavigationLink(value: entry.attempt.id) { row(entry.attempt, rank: entry.rank, current: false) }
                        .buttonStyle(.plain)
                }
            }
        }.padding(.vertical, SGTheme.Space.medium)
    }

    private func cookAgainButton(_ action: @escaping () -> Void) -> some View {
        Button("Cook Again", systemImage: "plus", action: action)
            .labelStyle(SGCenteredActionLabelStyle())
            .buttonStyle(SGButtonStyle()).accessibilityIdentifier("detail-new-version")
            .disabled(current?.rankedItem?.list == nil && current != nil)
    }

    /// Cooks in true global rank order; cooks without a ranked item are omitted.
    var entries: [(rank: Int, attempt: CookingAttempt)] {
        guard let ordered = dish.attempts.lazy.compactMap({ $0.rankedItem?.list }).first?.orderedItems else { return [] }
        let ranks = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($0.element.id, $0.offset + 1) })
        return dish.attempts.compactMap { cook in ranks[cook.rankedItemID].map { ($0, cook) } }.sorted { $0.rank < $1.rank }
    }

    private func row(_ cook: CookingAttempt, rank: Int, current: Bool) -> some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            HStack(spacing: SGTheme.Space.small) {
                if cook.primaryImage != nil {
                    DishPhoto(media: cook.primaryImage, thumbnail: true, name: cook.meaningfulVersionLabel ?? cook.dish?.name ?? "Dish")
                        .sgPhotoFrame(.compactThumbnail)
                }
                if !textSize.isAccessibilitySize { CookVersionIdentity(cook: cook) }
                Spacer(minLength: 0)
                Text("#\(rank)").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                if let item = cook.rankedItem { ScoreBadge(score: item.score) }
                Image(systemName: current ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(current ? SGTheme.ColorToken.accent : .secondary)
            }
            if textSize.isAccessibilitySize { CookVersionIdentity(cook: cook) }
        }
        .padding(.vertical, SGTheme.Space.small).contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel([cook.meaningfulVersionLabel.map { "\($0), cook of \(dish.name)" } ?? dish.name, "rank \(rank)"].joined(separator: ", "))
        .accessibilityIdentifier("version-row-\(cook.id)")
        .accessibilityHint(current ? "Current cook" : "Opens this cook")
        .contextMenu { if let rename { Button("Rename", systemImage: "character.cursor.ibeam") { rename(cook) } } }
        .accessibilityActions { if let rename { Button("Rename") { rename(cook) } } }
    }
}

/// A Dish's related Recipes: the Main Recipe first, then the others, with Set as Main and
/// Remove from Dish. For the selected cook it states "Recipe used" (an exact snapshot)
/// separately from "Linked Recipe" (a current association). Main never implies use.
struct DishRecipesSection: View {
    let dish: Dish
    var attempt: CookingAttempt? = nil
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @Query private var syncBindings: [SyncStoreBinding]
    @State private var set: DishRecipeSet?
    @State private var usedRecipe: RecipeCookSnapshot?
    @State private var failure: String?
    @State private var busy = false
    @State private var creating = false
    @State private var linking = false
    @State private var removing: Recipe?
    @State private var generation = UUID()

    private var synced: Bool {
        guard let cook = attempt ?? dish.attempts.first else { return false }
        return CookPublicationReadiness.revision(for: cook, binding: syncBindings.first, requireCurrent: false) != nil
    }

    var body: some View {
        if request != nil {
            VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                if let usedRecipe { usedBlock(usedRecipe) }
                SGSectionHeader(title: (set?.recipes.count ?? 0) > 1 ? "Recipes" : "Recipe") {
                    if set != nil && !(set?.recipes.isEmpty ?? true) { addMenu }
                }
                if let set {
                    if let main = set.main { mainCard(main) }
                    ForEach(set.others, id: \.recipe.id) { otherRow($0) }
                    if set.recipes.isEmpty { emptyActions }
                } else if !synced {
                    Text("Recipes are available once this Dish syncs.").font(.footnote).foregroundStyle(.secondary)
                } else if failure == nil { ProgressView().frame(maxWidth: .infinity, alignment: .leading) }
                if let failure {
                    Text(failure).font(.footnote).accessibilityIdentifier("cook-recipe-error")
                    Button("Retry Recipes") { Task { await load() } }
                }
            }
            .task(id: "\(dish.id):\(attempt?.id.uuidString ?? ""):\(synced)") { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
            .onChange(of: phase) { _, next in generation = UUID(); if next == .active { Task { await load() } } }
            .onDisappear { generation = UUID() }
            .sheet(isPresented: $creating) {
                RecipeEditor(title: dish.name, course: attempt?.categoryCode ?? dish.defaultCategoryCode, cuisine: dish.cuisineLabel) { recipe in
                    Task { await mutate("link_dish_recipe", recipe: recipe.id) }
                }
            }
            .sheet(isPresented: $linking, onDismiss: { Task { await load() } }) {
                NavigationStack { RecipeLibraryView(dishID: dish.id, linksDishRecipe: true) }
            }
            .confirmationDialog("Remove this Recipe from \(dish.name)?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
                Button("Remove from Dish", role: .destructive) { if let removing { Task { await mutate("unlink_dish_recipe", recipe: removing.id) } } }
            } message: { Text("The Recipe, its history, your cooks and any Recipe-used records stay intact.") }
        }
    }

    private var addMenu: some View {
        Menu {
            Button("Add Recipe", systemImage: "plus") { creating = true }.accessibilityIdentifier("dish-add-recipe")
            Button("Link Existing Recipe", systemImage: "link") { linking = true }.accessibilityIdentifier("dish-link-recipe")
        } label: { SGToolbarIcon(symbol: "plus") }
            .disabled(busy).accessibilityLabel("Add a Recipe to this Dish").accessibilityIdentifier("dish-recipes-add")
    }
    @ViewBuilder private var emptyActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: SGTheme.Space.medium) { addButtons }
            VStack(alignment: .leading, spacing: SGTheme.Space.small) { addButtons }
        }
    }
    @ViewBuilder private var addButtons: some View {
        Button("Add Recipe", systemImage: "plus") { creating = true }
            .buttonStyle(RecipeInlineAction()).disabled(busy).accessibilityIdentifier("dish-add-recipe")
        Button("Link Existing Recipe", systemImage: "link") { linking = true }
            .buttonStyle(RecipeInlineAction()).disabled(busy).accessibilityIdentifier("dish-link-recipe")
    }

    private func usedBlock(_ used: RecipeCookSnapshot) -> some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            SGSectionHeader(title: "Recipe used")
            if let creator = used.creatorName { Text("Created by \(creator)").font(.subheadline).accessibilityIdentifier("cook-recipe-creator") }
            NavigationLink { RecipeSnapshotView(cook: used) } label: { Label(used.snapshot.title, systemImage: "clock") }
                .accessibilityIdentifier("cook-recipe-snapshot")
            Text("Recipe revision \(used.revision) when this cook began").font(.caption).foregroundStyle(.secondary)
        }.padding(.bottom, SGTheme.Space.small)
    }

    private func relation(_ entry: DishRecipeSet.Entry) -> String? {
        guard let attempt else { return nil }
        if entry.usedByAttemptIDs.contains(attempt.id) { return "Used for this cook" }
        if entry.linkedAttemptIDs.contains(attempt.id) { return "Linked to this cook" }
        return nil
    }

    private func mainCard(_ entry: DishRecipeSet.Entry) -> some View {
        NavigationLink { RecipeDetailView(id: entry.recipe.id, dishID: dish.id) } label: {
            HStack(spacing: SGTheme.Space.small) {
                RecipePhoto(id: entry.recipe.content.photoID, dish: dish, name: entry.recipe.content.title).sgPhotoFrame(.compactThumbnail)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                    if (set?.recipes.count ?? 0) > 1 { SGEyebrow(text: "Main Recipe") }
                    Text(entry.recipe.content.title).font(SGTheme.TypeRole.headline).foregroundStyle(SGTheme.ColorToken.primaryText)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    if let relation = relation(entry) { Text(relation).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }.contentShape(Rectangle())
        }
        .buttonStyle(.plain).frame(minHeight: 44)
        .contextMenu { removeButton(entry.recipe) }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the Recipe")
        .accessibilityIdentifier("dish-view-recipe")
    }

    private func otherRow(_ entry: DishRecipeSet.Entry) -> some View {
        NavigationLink { RecipeDetailView(id: entry.recipe.id, dishID: dish.id) } label: {
            HStack(spacing: SGTheme.Space.small) {
                VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                    Label(entry.recipe.content.title, systemImage: "book").foregroundStyle(SGTheme.ColorToken.primaryText)
                    if let relation = relation(entry) { Text(relation).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }.contentShape(Rectangle())
        }
        .buttonStyle(.plain).frame(minHeight: 44)
        .contextMenu {
            Button("Set as Main Recipe", systemImage: "star") { Task { await setMain(entry.recipe.id) } }
            removeButton(entry.recipe)
        }
        .accessibilityElement(children: .combine)
        .accessibilityActions {
            Button("Set as Main Recipe") { Task { await setMain(entry.recipe.id) } }
            Button("Remove from Dish") { removing = entry.recipe }
        }
        .accessibilityIdentifier("dish-recipe-\(entry.recipe.id)")
    }
    private func removeButton(_ recipe: Recipe) -> some View {
        Button("Remove from Dish", systemImage: "link.badge.plus", role: .destructive) { removing = recipe }
    }

    private func load() async {
        guard synced, let request else { return }
        let token = UUID(); generation = token
        do {
            let value = try await DishRecipeService.load(dish.id, request: request)
            var used: RecipeCookSnapshot?
            if let attempt { used = try await DishRecipeService.usedRecipe(for: attempt.id, dishID: dish.id, request: request) }
            guard !Task.isCancelled, generation == token else { return }
            set = value; usedRecipe = used; failure = nil
        } catch is CancellationError {} catch {
            guard generation == token else { return }
            failure = DishRecipeService.message(for: error)
        }
    }
    private func mutate(_ action: String, recipe: UUID) async {
        guard let request else { return }; busy = true; defer { busy = false }
        do {
            set = try await DishRecipeService.mutate(action, dishID: dish.id, recipeID: recipe, request: request)
            NotificationCenter.default.post(name: .socialContentChanged, object: nil); failure = nil
        } catch { failure = DishRecipeService.message(for: error) }
    }
    private func setMain(_ recipe: UUID) async {
        guard let request else { return }; busy = true; defer { busy = false }
        do {
            set = try await DishRecipeService.setMain(recipe, dishID: dish.id, expected: set?.chosenMainRecipeID, request: request)
            NotificationCenter.default.post(name: .socialContentChanged, object: nil); failure = nil
        } catch { failure = DishRecipeService.message(for: error); await load() }
    }
}

/// The Dish Detail overflow actions, in one place for every Dish surface.
struct DishActions: View {
    var editCook: () -> Void
    var rename: () -> Void
    var rerank: () -> Void
    var shareWithSousChefs: (() -> Void)?
    var editDishText: () -> Void
    var delete: () -> Void
    var body: some View {
        Menu {
            Button("Edit Cook", systemImage: "pencil", action: editCook).accessibilityIdentifier("detail-edit-cook")
            Button("Rename", systemImage: "character.cursor.ibeam", action: rename).accessibilityIdentifier("detail-rename-cook")
            Button("Re-rank", systemImage: "arrow.triangle.2.circlepath", action: rerank).accessibilityIdentifier("detail-rerank")
            if let shareWithSousChefs { Button("Share with Sous Chefs", systemImage: "person.2", action: shareWithSousChefs).accessibilityIdentifier("share-with-friends") }
            Button("Edit Dish Description & Notes", systemImage: "text.alignleft", action: editDishText).accessibilityIdentifier("dish-text-edit")
            Button("86 Cook (Delete)", systemImage: "trash", role: .destructive, action: delete)
        } label: { SGToolbarIcon(symbol: "ellipsis") }
            .sgUtilityTint()
            .accessibilityLabel("More cook actions").accessibilityIdentifier("cook-more-actions")
    }
}
