import SwiftUI

/// Feature-local composition; shared theme, photo loading and sharing stay authoritative.
struct ProfileCookingContent: View {
    let snapshot: ProfileSnapshot
    let ranking: RankingList?
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.openGrubRank) private var openGrubRank
    @State private var titleHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.large) {
            topFoods
            cookingSnapshot
            if let collections = snapshot.collections { KitchenCollectionsSection(summaries: collections, scores: snapshot.scores) }
            recentCooks
        }
    }

    /// Compact Kitchen statistics (Connected UI, November 16, 2026). Both open Grub Rank, which always lists
    /// every ranked cook (Nov 18, 2026). Counts are verified local data, never cloud estimates.
    private var cookingSnapshot: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            HStack(alignment: .top, spacing: SGTheme.Space.small) {
                statistic(snapshot.dishCount, title: "Dishes Ranked", identifier: "profile-dish-count", hint: "Opens Grub Rank") { openGrubRank(.allVersions) }
                    .frame(maxWidth: .infinity)
                statistic(snapshot.rankedEntryCount, title: "Total Makes", identifier: "profile-entry-count", hint: "Opens Grub Rank") { openGrubRank(.allVersions) }
                    .frame(maxWidth: .infinity)
            }
            if let last = snapshot.lastCookedAt {
                Text("Last cooked \(last.formatted(date: .abbreviated, time: .omitted))")
                    .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary).accessibilityIdentifier("profile-last-cooked")
            }
        }.padding(.vertical, SGTheme.Space.xSmall)
    }

    private func statistic(_ count: Int, title: String, identifier: String, hint: String, open: @escaping () -> Void) -> some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                Text(count, format: .number).font(SGTheme.TypeRole.title).monospacedDigit()
                Text(title).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, minHeight: SGTheme.Size.minimumTap, alignment: .leading)
                .padding(SGTheme.Space.small)
                .background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: SGTheme.Radius.field, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(SGTheme.ColorToken.primaryText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) \(title.lowercased())")
        .accessibilityHint(hint).accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
    }

    /// Cooking history: the newest ranked cooks, each opening its Dish page.
    @ViewBuilder private var recentCooks: some View {
        if !snapshot.recentCooks.isEmpty {
            VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                SGSectionHeader(title: "Recent Cooks")
                ForEach(snapshot.recentCooks) { food in
                    NavigationLink(value: food.attempt.id) {
                        HStack(spacing: SGTheme.Space.small) {
                            DishPhoto(media: food.attempt.primaryImage, thumbnail: true, name: food.title).sgPhotoFrame(.compactThumbnail)
                            VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                                Text(food.title).font(SGTheme.TypeRole.headline).foregroundStyle(SGTheme.ColorToken.primaryText)
                                    .lineLimit(textSize.isAccessibilitySize ? nil : 1)
                                Text(food.attempt.cookedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Date unknown")
                                    .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Text("#\(food.rank)").font(SGTheme.TypeRole.secondary).monospacedDigit().foregroundStyle(.secondary)
                            SGScore(text: food.scoreText, identifier: "profile-recent-score-\(food.id)")
                            Image(systemName: "chevron.right").foregroundStyle(.secondary).accessibilityHidden(true)
                        }.frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore).accessibilityLabel(food.accessibilityLabel)
                    .accessibilityHint("Opens the Dish").accessibilityIdentifier("profile-recent-cook-\(food.id)")
                }
            }
        }
    }

    private var topFoods: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            SGSectionHeader(title: "Signature Dishes") {
                TopThreeShareAction(list: ranking, title: "Share Signature Dishes", compact: true)
            }
            if !snapshot.topFoods.isEmpty {
                if textSize.isAccessibilitySize {
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: SGTheme.Space.small) {
                            ForEach(snapshot.topFoods) { food in signature(food).frame(width: 220) }
                        }
                    }.accessibilityIdentifier("signature-dishes-row")
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SGTheme.Space.small, alignment: .topLeading), count: 3), alignment: .leading, spacing: SGTheme.Space.small) {
                        ForEach(snapshot.topFoods) { food in signature(food) }
                    }.accessibilityIdentifier("signature-dishes-row")
                }
                if snapshot.topFoods.count < 3 {
                    Text("Keep cooking to find your Signature Dishes.")
                        .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                        .accessibilityIdentifier("profile-building-top-three")
                }
            } else {
                Text("Add your first dish in Grub Rank.")
                    .font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).sgCard().accessibilityIdentifier("profile-empty")
            }
            if !snapshot.scores.isUnlocked { ScoreUnlockProgressBanner(state: snapshot.scores) }
        }.onPreferenceChange(SignatureTitleHeightKey.self) { titleHeight = $0 }
    }
    private func signature(_ food: ProfileSnapshot.Food) -> some View {
        NavigationLink(value: food.attempt.id) { ProfileTopFood(food: food, titleHeight: titleHeight) }.buttonStyle(.plain)
            .accessibilityElement(children: .ignore).accessibilityLabel(food.accessibilityLabel)
            .accessibilityHint("Opens Dish Details").accessibilityIdentifier("profile-top-food-\(food.rank)")
    }
}

private struct ProfileTopFood: View {
    let food: ProfileSnapshot.Food
    let titleHeight: CGFloat
    @Environment(\.dynamicTypeSize) private var textSize
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            DishPhoto(media: food.attempt.primaryImage, thumbnail: SGPhotoRole.tile.usesThumbnailRendition, name: food.title)
                .sgPhotoFrame(.tile)
                .overlay(alignment: .topLeading) {
                    Text("#\(food.rank)").font(.subheadline.bold()).monospacedDigit()
                        .padding(SGTheme.Space.xSmall)
                        .foregroundStyle(SGTheme.ColorToken.primaryText)
                        .background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: SGTheme.Radius.chip))
                        .padding(SGTheme.Space.xSmall)
                }.accessibilityHidden(true)
            Text(food.title).font(SGTheme.TypeRole.secondary.weight(.semibold))
                .lineLimit(textSize.isAccessibilitySize ? nil : 2).fixedSize(horizontal: false, vertical: true)
                .background { GeometryReader { geometry in Color.clear.preference(key: SignatureTitleHeightKey.self, value: geometry.size.height) } }
                .frame(height: titleHeight > 0 ? titleHeight : nil, alignment: .top)
            SGScore(text: food.scoreText, identifier: "profile-score-\(food.rank)")
        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
}

private struct SignatureTitleHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
