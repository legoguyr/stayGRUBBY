import SwiftUI

/// HTTPS pointers confer no access. The recipient still passes the existing account/server gate.
struct SocialLinkShareAction: View {
    let url: URL
    let title: String
    var compact = false
    var body: some View {
        ShareLink(item: url) {
            if compact { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44) }
            else { Label(title, systemImage: "square.and.arrow.up").frame(minHeight: 44) }
        }.accessibilityLabel(title)
    }
}
