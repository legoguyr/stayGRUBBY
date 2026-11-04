import SwiftUI

/// Same identity composition for the owner and authorized other-user profiles.
struct KitchenIdentityPresentation: View {
    let name: String
    let username: String?
    let avatarPath: String?
    var body: some View {
        VStack(spacing: SGTheme.Space.small) {
            SocialAvatar(name: name, path: avatarPath, size: 72)
            Text(name).font(SGTheme.TypeRole.title).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            if let username { Text("@" + username).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity).padding(.vertical, SGTheme.Space.small)
    }
}

struct KitchenIdentityHeader: View {
    @Environment(\.socialRequest) private var request
    @State private var identity: SocialIdentity?
    var body: some View {
        KitchenIdentityPresentation(name: (identity?.displayName).flatMap { $0.isEmpty ? nil : $0 } ?? "Your Kitchen", username: identity?.username, avatarPath: identity?.avatarPath)
            .accessibilityIdentifier("profile-identity")
            .task { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
    }
    private func load() async {
        guard let request else { return }
        do { let next = try JSONDecoder().decode(SocialIdentity.self, from: await request("social_identity", "get", .init())); try Task.checkCancellation(); identity = next }
        catch { identity = nil }
    }
}
