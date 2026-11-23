#if DEBUG || INTERNAL_TESTING
import SwiftUI

/// Internal first-run preview (Build 7; V1_RELEASE_GATE "Internal builds"). Replays the real new-account
/// journey — Welcome → Your kitchen (name, privacy, photo) → kitchen tour → empty Grub Rank — on the
/// owner's signed-in iPhone without touching the account:
/// - every request goes to `PreviewSocialBackend`, an in-memory stand-in that answers only profile setup
///   and refuses everything else, so nothing can reach Supabase, Storage or Apple;
/// - setup progress lives under a throwaway scope that is discarded on exit;
/// - the real tour completion, username, profile and library are never read or written.
/// Compiled only into Debug and the `Internal` configuration; public Release builds exclude it
/// (`DevelopmentTools/check_release_excludes_internal.sh`). Settings shows it only with `INTERNAL_TESTING`.
@MainActor @Observable final class PreviewSocialBackend {
    struct Refused: Error, Equatable { let endpoint: String; let action: String }
    private(set) var identity = SocialIdentity(displayName: "", username: nil, discoverable: false)
    /// Every call the preview made, in order (tests assert nothing else is reachable).
    private(set) var calls: [String] = []

    func request(_ endpoint: String, _ action: String, _ payload: SocialPayload) async throws -> Data {
        calls.append("\(endpoint).\(action)")
        switch (endpoint, action) {
        case ("social_identity", "get"):
            return try JSONEncoder().encode(identity)
        case ("social_identity", "save"):
            identity.displayName = payload.displayName ?? identity.displayName
            identity.username = payload.username ?? identity.username
            identity.discoverable = payload.discoverable ?? identity.discoverable
            return try JSONEncoder().encode(identity)
        case ("social_avatar", "prepare"):
            return Data(#"{"path":"preview/avatar.jpg","published":false}"#.utf8)
        case ("social_avatar", "publish"):
            identity.avatarPath = payload.avatarPath
            return Data("{}".utf8)
        case ("social_avatar", "cleanup"):
            return Data(#"{"paths":[]}"#.utf8)
        default:
            throw Refused(endpoint: endpoint, action: action)
        }
    }
    func media(_ action: SocialMediaAction) async throws -> Data {
        calls.append("media")
        if case .avatarUpload = action { return Data() } // Discarded: no Storage exists here.
        throw Refused(endpoint: "media", action: "other")
    }
}

struct FirstRunPreview: View {
    enum Stage: Int, CaseIterable { case welcome, setup, tour, grubRank }
    let close: () -> Void
    @State private var stage: Stage = .welcome
    @State private var backend = PreviewSocialBackend()
    /// Throwaway setup scope, never an account scope.
    @State private var scope = "preview.\(UUID().uuidString)"
    @Environment(\.sgReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch stage {
            case .welcome: welcome
            case .setup:
                SocialOnboardingView(scope: scope, identity: backend.identity, required: true, announcesChanges: false) { advance(to: .tour) }
            case .tour:
                TutorialView { advance(to: .grubRank) }
            case .grubRank:
                ScrollView { GrubRankEmptyState { exit() }.padding(.top, SGTheme.Space.xLarge) }
                    .background(SGTheme.ColorToken.background)
            }
        }
        .environment(\.socialRequest, { endpoint, action, payload in try await backend.request(endpoint, action, payload) })
        .environment(\.socialMedia, { action in try await backend.media(action) })
        .safeAreaInset(edge: .top, spacing: 0) { banner }
        .onDisappear { SocialOnboardingDraft.discard(scope) }
    }

    private var banner: some View {
        HStack(spacing: SGTheme.Space.small) {
            Label("Preview · nothing is saved", systemImage: "eye").font(SGTheme.TypeRole.secondary.weight(.semibold))
                .foregroundStyle(SGTheme.ColorToken.onAccent)
            Spacer()
            Button("Exit Preview") { exit() }.font(SGTheme.TypeRole.secondary.weight(.bold))
                .foregroundStyle(SGTheme.ColorToken.onAccent)
                .frame(minHeight: SGTheme.Size.minimumTap).accessibilityIdentifier("internal-preview-exit")
        }
        .padding(.horizontal, SGTheme.Space.medium)
        .background(SGTheme.ColorToken.buttonAccent)
        .accessibilityElement(children: .contain).accessibilityIdentifier("internal-preview-banner")
    }

    private var welcome: some View {
        ScrollView {
            WelcomeIntroduction()
                .frame(maxWidth: SGTheme.Size.sharingContentMaximum, alignment: .leading).frame(maxWidth: .infinity)
                .padding(.horizontal, SGTheme.Space.large).padding(.vertical, SGTheme.Space.medium)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: SGTheme.Space.xSmall) {
                Button { advance(to: .setup) } label: {
                    Label("Continue with Simulated Sign In", systemImage: "apple.logo").frame(maxWidth: .infinity)
                }
                .buttonStyle(SGButtonStyle(prominent: true)).accessibilityIdentifier("internal-preview-sign-in")
                Text("Preview: Sign in with Apple is simulated. No account is created.")
                    .font(SGTheme.TypeRole.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(SGTheme.Space.medium).background(SGTheme.ColorToken.background)
        }
        .background(SGTheme.ColorToken.background)
    }

    private func advance(to next: Stage) {
        if reduceMotion { stage = next } else { withAnimation(SGTheme.Motion.standard) { stage = next } }
    }
    private func exit() { SocialOnboardingDraft.discard(scope); close() }
}
#endif
