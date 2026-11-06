import SwiftUI

/// Shared version identity across Dish Detail and intentional Recipe association.
struct CookVersionIdentity: View {
    let cook: CookingAttempt
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
            if let version = cook.meaningfulVersionLabel { Text(version).font(SGTheme.TypeRole.headline).fixedSize(horizontal: false, vertical: true) }
            Text(cook.cookedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Date unknown")
                .font(SGTheme.TypeRole.secondary).foregroundStyle(SGTheme.ColorToken.subdued)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct CookVersionSelectionView: View {
    let dishes: [Dish]
    var query = ""
    var selectedID: UUID?
    var disabled = false
    let onSelect: (CookingAttempt) -> Void
    private var cooks: [CookingAttempt] {
        dishes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .flatMap { $0.attempts.sorted { $0.sequenceNumber > $1.sequenceNumber } }
            .filter { CookbookSearch.matches([ $0.dish?.name, $0.versionTitle, $0.versionLabel ].compactMap { $0 }.joined(separator: " "), query: query) }
    }
    var body: some View {
        ScrollView {
            LazyVStack(spacing: SGTheme.Space.small) {
                if cooks.isEmpty { ContentUnavailableView.search(text: query) }
                ForEach(cooks) { cook in
                    Button { onSelect(cook) } label: {
                        HStack(spacing: SGTheme.Space.small) {
                            DishPhoto(media: cook.primaryImage, thumbnail: true, name: cook.dish?.name ?? cook.displayName)
                                .frame(width: SGTheme.Size.versionThumbnail, height: SGTheme.Size.versionThumbnail)
                                .clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.field))
                            VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                                Text(cook.dish?.name ?? cook.displayName).font(SGTheme.TypeRole.headline)
                                CookVersionIdentity(cook: cook)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: cook.id == selectedID ? "checkmark.circle.fill" : "chevron.right").foregroundStyle(.secondary)
                        }.frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(disabled).accessibilityValue(cook.id == selectedID ? "Selected" : "Not selected")
                        .accessibilityIdentifier("choose-cook-\(cook.id)")
                }
            }.padding(SGTheme.Space.medium)
        }.background(SGTheme.ColorToken.background)
    }
}
