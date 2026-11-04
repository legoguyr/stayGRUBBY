import SwiftUI

/// The same account identity across discovery, recipients, tagging and activity.
struct SocialPersonLabel: View {
    let person: SocialPerson
    var detail: String? = nil
    var size: CGFloat = 44
    var body: some View {
        HStack(alignment: .top, spacing: SGTheme.Space.small) {
            SocialAvatar(name: person.displayName, path: person.avatarPath, size: size)
            VStack(alignment: .leading, spacing: SGTheme.Space.hairline) {
                Text(person.displayName).font(.headline).foregroundStyle(SGTheme.ColorToken.primaryText)
                Text(person.handle).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                if let detail { Text(detail).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary) }
            }.fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }.frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
    }
}

struct SocialPersonSelectionRow: View {
    let person: SocialPerson
    let selected: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: SGTheme.Space.small) {
                SocialPersonLabel(person: person)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? SGTheme.ColorToken.accent : .secondary).accessibilityHidden(true)
            }.frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("\(person.displayName), \(person.handle)")
            .accessibilityValue(selected ? "Selected" : "Not selected")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
