import SwiftUI

/// Neutral food-media fallback using the same official, cropped wordmark as sharing.
/// No synthetic photography or remote media request is introduced.
struct SGFoodPlaceholder: View {
    var body: some View {
        ZStack {
            SGTheme.ColorToken.surface
            if let logo = OfficialBrandWordmark.image {
                Image(uiImage: logo).resizable().scaledToFit()
                    .frame(maxWidth: 112, maxHeight: 60).padding(SGTheme.Space.medium)
            }
        }.accessibilityHidden(true)
    }
}
