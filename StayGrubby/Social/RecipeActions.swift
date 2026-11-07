import SwiftUI

nonisolated enum RecipeSharingPolicy {
    static func initiallyShared(_ recipe: Recipe?) -> Bool { recipe.map { $0.visibility == "friends" } ?? true }
    static func creatorCredit(_ recipe: Recipe) -> String? {
        if let original = recipe.content.originalCreator?.trimmingCharacters(in: .whitespacesAndNewlines), !original.isEmpty {
            if recipe.isOwner, let ownName = recipe.creator?.displayName, ownName.caseInsensitiveCompare(original) == .orderedSame { return nil }
            return original
        }
        return recipe.isOwner ? nil : recipe.creator?.displayName
    }
}

/// Same native sharing/Send/menu for current and authorized post-pinned Recipe readers.
struct RecipeToolbarActions<Management: View>: ToolbarContent {
    let url: URL?
    let sendContent: SocialSendContent?
    var sendTitle = "Send to Sous Chefs"
    var disabled = false
    @ViewBuilder let management: () -> Management
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            RecipeLinkShare(url: url).disabled(disabled)
            RecipeActions(sendContent: sendContent, sendTitle: sendTitle, management: management).disabled(disabled)
        }.sgIndependentToolbarBackground()
    }
}

struct RecipeLinkShare: View {
    let url: URL?
    var body: some View {
        if let url {
            SocialLinkShareAction(url: url, title: "Share Recipe Link", compact: true).accessibilityIdentifier("recipe-share-link")
        } else {
            SGToolbarIcon(symbol: "square.and.arrow.up").foregroundStyle(SGTheme.ColorToken.unavailable)
                .accessibilityLabel("Recipe sharing off").accessibilityIdentifier("recipe-sharing-off")
        }
    }
}

struct RecipeActions<Management: View>: View {
    let sendContent: SocialSendContent?
    var sendTitle = "Send to Sous Chefs"
    @ViewBuilder let management: () -> Management
    @State private var sending: SocialSendContent?
    var body: some View {
            Menu {
                if let sendContent { Button(sendTitle, systemImage: "person.crop.circle.badge.checkmark") { sending = sendContent }.accessibilityIdentifier("recipe-send-friend") }
                management()
            } label: { SGToolbarIcon(symbol: "ellipsis") }
                .sgUtilityTint()
                .accessibilityLabel("Recipe actions").accessibilityIdentifier("recipe-actions")
        .sheet(item: $sending) { SocialSendSheet(content: $0) }
    }
}
