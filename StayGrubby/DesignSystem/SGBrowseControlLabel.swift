import SwiftUI

/// Compact browsing actions shared by Grub Rank and Food Bible; feature owns semantics/state.
struct SGBrowseControlLabel: View {
    let title: String
    let symbol: String
    var active = false
    var body: some View {
        Label(title, systemImage: symbol).font(SGTheme.TypeRole.secondary.weight(.medium))
            .padding(.horizontal, SGTheme.Space.small).frame(minHeight: SGTheme.Size.minimumTap)
            .foregroundStyle(active ? SGTheme.ColorToken.accent : SGTheme.ColorToken.primaryText)
            .background(active ? SGTheme.ColorToken.selected : SGTheme.ColorToken.surface, in: Capsule())
    }
}

struct SGPrimaryTabChrome: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbarBackground(SGTheme.ColorToken.surface, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}
