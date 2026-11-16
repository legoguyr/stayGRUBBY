import SwiftUI
import SwiftData
import Supabase

// D2 Unified Dish Detail parts (FOOD_ARCHITECTURE §8). Each part owns one record and is
// shared by Dish Detail (from Grub Rank) and the Recipe reader (from Food Bible).

/// Dish name, the selected cook's name, its score and global rank.
struct DishIdentityHeader: View {
    let attempt: CookingAttempt
    /// Shows the Dish's verified cook count beside score and rank (the Dish page header).
    var showsCookCount = false
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            SGEyebrow(text: globalRank == 1 ? "Signature Dish" : "From your Grub Rank")
            Text(attempt.dish?.name ?? "Dish").font(SGTheme.TypeRole.hero)
                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("dish-title")
            if let name = attempt.meaningfulVersionLabel {
                Text(name).font(SGTheme.TypeRole.body).foregroundStyle(.secondary).accessibilityIdentifier("detail-cook-name")
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: SGTheme.Space.small) { scoreAndRank; cookCount }
                VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                    HStack(spacing: SGTheme.Space.small) { scoreAndRank }
                    cookCount
                }
            }
        }
    }
    @ViewBuilder private var scoreAndRank: some View {
        if let item = attempt.rankedItem { ScoreBadge(score: item.score) }
        if let globalRank { Text("#\(globalRank) overall").font(SGTheme.TypeRole.body).foregroundStyle(.secondary).fixedSize() }
    }
    @ViewBuilder private var cookCount: some View {
        if showsCookCount, let dish = attempt.dish { DishCookCount(count: dish.attempts.count) }
    }
    private var globalRank: Int? {
        guard let item = attempt.rankedItem, let ordered = item.list?.orderedItems,
              let index = ordered.firstIndex(where: { $0.id == item.id }) else { return nil }
        return index + 1
    }
}

/// The Dish's verified number of cooks (its local Cooking Attempts; nothing inferred or aggregated
/// from the cloud). Informational only: the cooks themselves are listed on Dish & Ranking.
struct DishCookCount: View {
    let count: Int
    var body: some View {
        Label(count == 1 ? "Cooked once" : "Cooked \(count) times", systemImage: "fork.knife")
            .font(SGTheme.TypeRole.body).foregroundStyle(.secondary).fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(count == 1 ? "Cooked once" : "Cooked \(count) times")
            .accessibilityIdentifier("dish-cook-count")
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
            if let shareWithSousChefs { Button("Post to The Pass", systemImage: "person.2", action: shareWithSousChefs).accessibilityIdentifier("share-with-friends") }
            Button("Edit Dish Description & Notes", systemImage: "text.alignleft", action: editDishText).accessibilityIdentifier("dish-text-edit")
            Button("86 Cook (Delete)", systemImage: "trash", role: .destructive, action: delete)
        } label: { SGToolbarIcon(symbol: "ellipsis") }
            .sgUtilityTint()
            .accessibilityLabel("More cook actions").accessibilityIdentifier("cook-more-actions")
    }
}
