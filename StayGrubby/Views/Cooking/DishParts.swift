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

/// Every cook of one Dish with name, global rank, gated score and date. Cook Again is offered
/// by the host; a cook's name is edited in Edit Cook. `current` marks the cook Dish Detail is showing.
struct DishCooksSection: View {
    let dish: Dish
    var current: CookingAttempt? = nil
    /// Destination-based rows for hosts outside the Grub Rank stack (the Recipe reader).
    var linksByDestination = false
    var title = "Cooks"
    var cookAgain: (() -> Void)? = nil
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
    }
}

/// The Dish's Recipe side on Dish Detail: one "View Recipe" row, or Add Recipe when the Dish
/// has none. Dish and Recipe are one Dish, so the Recipe is not repeated here (photo, body).
/// The selected cook's exact "Recipe used" revision stays separate provenance.
struct DishRecipeRow: View {
    let dish: Dish
    var attempt: CookingAttempt? = nil
    /// Tells the host whether this Dish has a Recipe (keeps the Dish when its last cook is 86'd).
    var recipeKnown: ((Bool) -> Void)? = nil
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @State private var recipe: Recipe?
    @State private var usedRecipe: RecipeCookSnapshot?
    @State private var loaded = false
    @State private var failure: String?
    @State private var adding = false
    @State private var generation = UUID()

    var body: some View {
        if request != nil {
            VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                if let recipe {
                    NavigationLink { RecipeDetailView(id: recipe.id, dishID: dish.id) } label: {
                        HStack(spacing: SGTheme.Space.small) {
                            Label("View Recipe", systemImage: "book").font(SGTheme.TypeRole.headline)
                                .foregroundStyle(SGTheme.ColorToken.primaryText)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(recipe.content.title == dish.name ? "View Recipe" : "View Recipe, \(recipe.content.title)")
                    .accessibilityIdentifier("dish-view-recipe")
                } else if loaded {
                    Button { adding = true } label: { Label("Add Recipe", systemImage: "plus").frame(minHeight: 44) }
                        .buttonStyle(RecipeInlineAction()).accessibilityIdentifier("dish-add-recipe")
                }
                if let usedRecipe, usedRecipe.recipeID != recipe?.id || usedRecipe.revision != recipe?.revision {
                    NavigationLink { RecipeSnapshotView(cook: usedRecipe) } label: {
                        Label("Recipe used for this cook · revision \(usedRecipe.revision)", systemImage: "clock")
                    }.frame(minHeight: 44).accessibilityIdentifier("cook-recipe-snapshot")
                }
                if let failure {
                    Text(failure).font(.footnote).accessibilityIdentifier("cook-recipe-error")
                    Button("Retry Recipe") { Task { await load() } }
                }
            }
            .task(id: "\(dish.id):\(attempt?.id.uuidString ?? "")") { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
            .onChange(of: phase) { _, next in generation = UUID(); if next == .active { Task { await load() } } }
            .onDisappear { generation = UUID() }
            .sheet(isPresented: $adding, onDismiss: { Task { await load() } }) { AddRecipeFlow(context: .dish(dish)) }
        }
    }

    private func load() async {
        guard let request else { return }
        let token = UUID(); generation = token
        do {
            struct DishResponse: Decodable { var recipe: Recipe? }
            var payload = SocialPayload(); payload.dishID = dish.id
            let next = try JSONDecoder().decode(DishResponse.self, from: await request("recipes", "dish", payload)).recipe
            var used: RecipeCookSnapshot?
            if let attempt { used = try? await DishRecipeService.usedRecipe(for: attempt.id, dishID: dish.id, request: request) }
            guard !Task.isCancelled, generation == token else { return }
            recipe = next; usedRecipe = used; loaded = true; failure = nil; recipeKnown?(next != nil)
        } catch is CancellationError {} catch {
            guard generation == token else { return }
            failure = DishRecipeService.message(for: error)
        }
    }
}

/// The Dish Detail overflow actions, in one place for every Dish surface.
struct DishActions: View {
    var editCook: () -> Void
    var rerank: () -> Void
    var shareWithSousChefs: (() -> Void)?
    var editDishText: () -> Void
    var delete: () -> Void
    var body: some View {
        Menu {
            Button("Edit Cook", systemImage: "pencil", action: editCook).accessibilityIdentifier("detail-edit-cook")
            Button("Re-rank", systemImage: "arrow.triangle.2.circlepath", action: rerank).accessibilityIdentifier("detail-rerank")
            if let shareWithSousChefs { Button("Share with Sous Chefs", systemImage: "person.2", action: shareWithSousChefs).accessibilityIdentifier("share-with-friends") }
            Button("Edit Dish Description & Notes", systemImage: "text.alignleft", action: editDishText).accessibilityIdentifier("dish-text-edit")
            Button("86 Cook (Delete)", systemImage: "trash", role: .destructive, action: delete)
        } label: { SGToolbarIcon(symbol: "ellipsis") }
            .sgUtilityTint()
            .accessibilityLabel("More cook actions").accessibilityIdentifier("cook-more-actions")
    }
}
