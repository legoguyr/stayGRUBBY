import SwiftUI

/// Action roles (Stage A):
/// - primary: `SGButtonStyle(prominent: true)` — one per region, filled red.
/// - secondary: `SGButtonStyle()` — neutral filled.
/// - compact utility: `SGButtonStyle(compact: true)` or a native text button.
/// - toolbar: `SGToolbarIcon` + `sgUtilityTint()` — neutral, consistent size/weight;
///   reserve accent for a screen's single primary toolbar action (e.g. Add).
/// - destructive: native `role: .destructive` (86 wording) — system red semantics.
/// - list row action: `SGRowButtonStyle` keeps row text neutral under the app tint.

/// One size/weight and a 44 pt target for every toolbar utility symbol.
struct SGToolbarIcon: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: SGTheme.Size.toolbarSymbol, weight: .medium))
            .frame(width: SGTheme.Size.minimumTap, height: SGTheme.Size.minimumTap)
            .contentShape(Rectangle())
    }
}

extension View {
    /// Neutral tint for utility controls (share, overflow, settings, Tickets bell, people)
    /// so the app-wide accent tint does not turn every toolbar item red.
    func sgUtilityTint() -> some View {
        tint(SGTheme.ColorToken.primaryText).foregroundStyle(SGTheme.ColorToken.primaryText)
    }
}

/// Row-shaped buttons inside lists keep their own text hierarchy instead of inheriting
/// the accent tint (which colored handles, messages and times red in Tickets).
struct SGRowButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(SGTheme.ColorToken.primaryText)
            .tint(SGTheme.ColorToken.primaryText)
            .contentShape(Rectangle())
            .opacity(enabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
    }
}
