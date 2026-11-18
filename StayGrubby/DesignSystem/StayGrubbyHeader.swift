import SwiftUI

struct SGIconButton: View {
    let title: String
    let symbol: String
    var emphasized = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(SGTheme.TypeRole.headline)
                .frame(width: SGTheme.Size.minimumTap, height: SGTheme.Size.minimumTap)
                .foregroundStyle(emphasized ? SGTheme.ColorToken.onAccent : SGTheme.ColorToken.primaryText)
                .background(emphasized ? SGTheme.ColorToken.buttonAccent : SGTheme.ColorToken.elevatedSurface, in: Circle())
        }.buttonStyle(.plain).accessibilityLabel(title)
    }
}

struct SGSelectionRow: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: SGTheme.Space.small) {
                Text(title).font(SGTheme.TypeRole.body)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? SGTheme.ColorToken.accent : .secondary)
            }
            .padding(.horizontal, SGTheme.Space.medium)
            .frame(minHeight: SGTheme.Size.minimumTap)
            .padding(.vertical, SGTheme.Space.xSmall)
            .background(selected ? SGTheme.ColorToken.selected : SGTheme.ColorToken.surface,
                        in: RoundedRectangle(cornerRadius: SGTheme.Radius.field))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
