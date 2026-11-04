import SwiftUI

nonisolated struct CookingSharingSelection: Equatable, Sendable {
    var accountDefault = false
    var override: Bool?
    var configured: Bool?
    var loading = true
    var loadFailed = false
    var selected: Bool { override ?? accountDefault }
    mutating func receive(_ identity: SocialIdentity) {
        accountDefault = identity.sharingDefault; configured = identity.isConfigured; loading = false; loadFailed = false
    }
    mutating func unavailable() { accountDefault = false; loading = false; loadFailed = true }
}

struct CookingSharingChoice: View {
    @Binding var selection: CookingSharingSelection
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
            Toggle("Share with Sous Chefs", isOn: Binding(get: { selection.selected }, set: { selection.override = $0 }))
                .foregroundStyle(SGTheme.ColorToken.primaryText)
                .disabled(selection.loading || selection.configured == false).accessibilityIdentifier("cook-share-with-friends")
            if selection.loading { ProgressView("Loading sharing default").font(.footnote) }
            else if selection.configured == false {
                Text("Set up Profile in Settings to share.").font(.footnote).foregroundStyle(.secondary)
            } else if selection.loadFailed {
                Text("Sharing default unavailable; this starts private.").font(.footnote).foregroundStyle(.secondary)
            }
        }.font(SGTheme.TypeRole.body)
            .frame(minHeight: SGTheme.Size.minimumTap)
    }
}
