import SwiftUI

/// Native principal-toolbar identity. Adds no safe-area inset or second navigation bar.
/// Primary-screen context remains in navigationTitle, selected tab and accessibility.
struct SGPrimaryBrandTitle: View {
    let page: String
    var body: some View {
        Group {
            if let logo = OfficialBrandWordmark.image {
                Image(uiImage: logo).resizable().scaledToFit().frame(width: 72, height: 40)
            } else { Text(page).font(SGTheme.TypeRole.headline) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("#stayGRUBBY, \(page)").accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("primary-brand-title")
    }
}
