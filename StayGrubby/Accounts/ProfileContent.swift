import SwiftUI

/// Feature-local composition; shared theme, photo loading and sharing stay authoritative.
struct ProfileCookingContent: View {
    let snapshot: ProfileSnapshot
    let ranking: RankingList?
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.large) {
            topFoods
            cookingSnapshot
        }
    }

    private var cookingSnapshot: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            Text("In your kitchen").font(SGTheme.TypeRole.headline).accessibilityAddTraits(.isHeader)
            let columns = textSize.isAccessibilitySize ? 1 : 2
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: columns),
                      alignment: .leading, spacing: SGTheme.Space.medium) {
                statistic(snapshot.rankedEntryCount, title: "Ranked entries", identifier: "profile-entry-count")
                statistic(snapshot.dishCount, title: "Dishes ranked", identifier: "profile-dish-count")
            }
            if let date = snapshot.lastCookedAt {
                Divider()
                if textSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                        Text("Last cooked")
                        Text(date, format: .dateTime.month(.abbreviated).day().year()).foregroundStyle(.secondary)
                    }.font(SGTheme.TypeRole.body)
                } else {
                    LabeledContent("Last cooked") {
                        Text(date, format: .dateTime.month(.abbreviated).day().year())
                    }.font(SGTheme.TypeRole.body)
                }
            }
        }.padding(.vertical, SGTheme.Space.medium)
    }

    private func statistic(_ count: Int, title: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
            Text(count, format: .number).font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
            Text(title).font(SGTheme.TypeRole.body).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) \(title.lowercased())")
        .accessibilityIdentifier(identifier)
    }

    private var topFoods: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            Text("Signature Dishes").font(SGTheme.TypeRole.headline).accessibilityAddTraits(.isHeader)
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
            TopThreeShareAction(list: ranking, title: "Share Signature Dishes")
        }
    }
    private func signature(_ food: ProfileSnapshot.Food) -> some View {
        NavigationLink(value: food.attempt.id) { ProfileTopFood(food: food) }.buttonStyle(.plain)
            .accessibilityElement(children: .ignore).accessibilityLabel(food.accessibilityLabel)
            .accessibilityHint("Opens Dish Details").accessibilityIdentifier("profile-top-food-\(food.rank)")
    }
}

private struct ProfileTopFood: View {
    let food: ProfileSnapshot.Food
    @Environment(\.dynamicTypeSize) private var textSize
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            Color.clear.aspectRatio(1, contentMode: .fit)
                .overlay { DishPhoto(media: food.attempt.primaryImage, thumbnail: true, name: food.title) }
                .clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.field))
                .overlay(alignment: .topLeading) {
                    Text("#\(food.rank)").font(.subheadline.bold()).monospacedDigit()
                        .padding(SGTheme.Space.xSmall)
                        .foregroundStyle(SGTheme.ColorToken.primaryText)
                        .background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: SGTheme.Radius.chip))
                        .padding(SGTheme.Space.xSmall)
                }.accessibilityHidden(true)
            Text(food.title).font(SGTheme.TypeRole.secondary.weight(.semibold))
                .lineLimit(textSize.isAccessibilitySize ? nil : 2).fixedSize(horizontal: false, vertical: true)
            if let score = food.scoreText {
                Text(score).font(.title3.weight(.bold)).monospacedDigit()
                    .foregroundStyle(SGTheme.ScoreColor.color(forDisplayedScore: score))
                    .accessibilityIdentifier("profile-score-\(food.rank)")
            } else { LockedScoreIndicator() }
        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
}
