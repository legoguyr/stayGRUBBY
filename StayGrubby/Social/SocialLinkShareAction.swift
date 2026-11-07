import SwiftUI

/// HTTPS pointers confer no access. The recipient still passes the existing account/server gate.
struct SocialLinkShareAction: View {
    let url: URL
    let title: String
    var compact = false
    var body: some View {
        if compact {
            ShareLink(item: url) { SGToolbarIcon(symbol: "square.and.arrow.up") }
                .sgUtilityTint().accessibilityLabel(title)
        } else {
            ShareLink(item: url) { Label(title, systemImage: "square.and.arrow.up").frame(minHeight: 44) }
                .accessibilityLabel(title)
        }
    }
}
