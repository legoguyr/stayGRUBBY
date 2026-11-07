import SwiftUI

/// Semantic photo roles. Every food/Recipe/social image frame chooses one role so
/// shape, corner and placeholder behave the same across Grub Rank, Food Bible,
/// Grub List and Kitchens. Loading stays with the existing photo views
/// (`DishPhoto`, `RecipePhoto`, `SocialPhoto`); this only frames and clips them.
enum SGPhotoRole {
    /// 86 pt square row thumbnail (Grub Rank rows).
    case thumbnail
    /// 44 pt square thumbnail in selection/version rows.
    case compactThumbnail
    /// Square tile with flexible width (Signature Dishes, Kitchen post grids).
    case tile
    /// 4:3 content card with flexible width (Grub List posts, Recipe activity).
    case card
    /// Slightly portrait cookbook card (Food Bible grid).
    case cookbook
    /// Full-width detail hero with a fixed height (Dish/Recipe readers).
    case hero

    var cornerRadius: CGFloat {
        switch self {
        case .compactThumbnail: SGTheme.Radius.chip
        case .thumbnail, .tile, .cookbook: SGTheme.Radius.field
        case .card, .hero: SGTheme.Radius.hero
        }
    }
    fileprivate var fixedSide: CGFloat? {
        switch self {
        case .thumbnail: SGTheme.Size.rowThumbnail
        case .compactThumbnail: SGTheme.Size.versionThumbnail
        default: nil
        }
    }
    fileprivate var aspectRatio: CGFloat? {
        switch self {
        case .tile: 1
        case .card: 4 / 3
        case .cookbook: 0.9
        default: nil
        }
    }
}

private struct SGPhotoFrameModifier: ViewModifier {
    let role: SGPhotoRole
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: role.cornerRadius, style: .continuous)
        if let side = role.fixedSide {
            content.frame(width: side, height: side).clipShape(shape)
        } else if let ratio = role.aspectRatio {
            // A clear sizing box keeps the layout stable while the image loads.
            Color.clear.aspectRatio(ratio, contentMode: .fit)
                .overlay { content }
                .clipShape(shape)
        } else {
            content.frame(maxWidth: .infinity).frame(height: SGTheme.Size.heroHeight).clipShape(shape)
        }
    }
}

extension View {
    /// Frame and clip food media by semantic role. See `SGPhotoRole`.
    func sgPhotoFrame(_ role: SGPhotoRole) -> some View { modifier(SGPhotoFrameModifier(role: role)) }
}

/// The one missing-photo treatment: warm neutral surface plus a quiet, monochrome
/// `#stayGRUBBY` mark sized to the frame. A screen of missing photos stays calm;
/// the full-color wordmark is reserved for identity (headers, share cards).
/// Very small frames show the surface alone. Decorative: callers own the label.
struct SGPhotoPlaceholder: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                SGTheme.ColorToken.elevatedSurface
                if side >= 64, let mark = OfficialBrandWordmark.image {
                    Image(uiImage: mark).renderingMode(.template).resizable().scaledToFit()
                        .foregroundStyle(SGTheme.ColorToken.placeholderMark)
                        // Size from the short side so wide, short frames (editor strips) stay quiet too.
                        .frame(width: min(side * 0.55, 104))
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.accessibilityHidden(true)
    }
}
