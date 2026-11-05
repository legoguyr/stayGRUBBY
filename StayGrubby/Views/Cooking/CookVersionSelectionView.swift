import SwiftUI

/// Shared version identity across Dish Detail and intentional Recipe association.
struct CookVersionIdentity: View {
    let cook: CookingAttempt
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
            Text(cook.versionLabel).font(SGTheme.TypeRole.headline).fixedSize(horizontal: false, vertical: true)
            Text(cook.cookedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Date unknown")
                .font(SGTheme.TypeRole.secondary).foregroundStyle(SGTheme.ColorToken.subdued)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct CookVersionSelectionView: View {
    let dish: Dish
    var selectedID: UUID?
    var disabled = false
    let onSelect: (CookingAttempt) -> Void
    var body: some View {
        ScrollView {
            VStack(spacing: SGTheme.Space.small) {
                ForEach(dish.attempts.sorted { $0.sequenceNumber > $1.sequenceNumber }) { cook in
                    Button { onSelect(cook) } label: {
                        HStack(spacing: SGTheme.Space.small) {
                            DishPhoto(media: cook.primaryImage, thumbnail: true, name: dish.name)
                                .frame(width: SGTheme.Size.versionThumbnail, height: SGTheme.Size.versionThumbnail)
                                .clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.field))
                            CookVersionIdentity(cook: cook)
                            Image(systemName: cook.id == selectedID ? "checkmark.circle.fill" : "chevron.right").foregroundStyle(.secondary)
                        }.frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(disabled).accessibilityValue(cook.id == selectedID ? "Selected" : "Not selected")
                        .accessibilityIdentifier("choose-cook-\(cook.id)")
                }
            }.padding(SGTheme.Space.medium)
        }.background(SGTheme.ColorToken.background).navigationTitle(dish.name).navigationBarTitleDisplayMode(.inline)
    }
}
