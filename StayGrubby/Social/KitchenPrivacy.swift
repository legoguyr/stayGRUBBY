import SwiftUI

/// What a visitor who isn't a Sous Chef sees instead of someone's Kitchen content (master UI milestone,
/// November 18, 2026). Only accepted Sous Chefs receive shared posts and Recipes, so this replaces an empty
/// content block and skips the request that could only return nothing. The server still enforces access;
/// this is presentation only.
///
/// Reused later by the public/private account model (`FeatureFlag.accountPrivacyFollows`, backend
/// dependency): a private account shows this to non-followers; a public account shows its public posts.
struct SGLockedKitchenNotice: View {
    let person: SocialPerson
    var body: some View {
        VStack(spacing: SGTheme.Space.small) {
            Image(systemName: "lock.fill").font(.title2).foregroundStyle(.secondary).accessibilityHidden(true)
            Text(title).font(SGTheme.TypeRole.headline).multilineTextAlignment(.center)
            Text(message).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity).padding(SGTheme.Space.large)
        .background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: SGTheme.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine).accessibilityIdentifier("kitchen-locked")
    }
    private var title: String { "\(person.displayName)’s Kitchen is for Sous Chefs" }
    private var message: String {
        switch person.relationship {
        case .outgoing: "Your request is pending. Once accepted, you’ll see the cooks and Recipes they share."
        case .incoming: "Accept their request to see the cooks and Recipes they share."
        default: "Add them as a Sous Chef to see the cooks and Recipes they share. Their rankings and notes stay private."
        }
    }
}
