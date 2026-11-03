import SwiftUI

/// One foreground-only, account-mounted activity refresh. No push, background work or credentials.
@MainActor @Observable final class SocialActivityCoordinator {
    private(set) var unread = 0
    private(set) var failed = false
    private(set) var refreshing = false
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var countRevision = 0
    @ObservationIgnored private var request: SocialRequest?
    func connect(_ request: @escaping SocialRequest) -> UUID {
        generation = UUID(); self.request = request; unread = 0; failed = false; refreshing = false
        return generation
    }
    func disconnect(_ token: UUID) {
        guard generation == token else { return }
        generation = UUID(); request = nil; unread = 0; failed = false; refreshing = false
    }
    func acceptUnread(_ count: Int) {
        guard request != nil else { return }
        countRevision += 1; unread = max(0, count); failed = false
    }
    func refresh(broadcast: Bool = false) async {
        guard !refreshing, let request else { return }
        let token = generation, revision = countRevision; refreshing = true
        defer { if token == generation { refreshing = false } }
        do {
            let page = try JSONDecoder().decode(SocialNotificationsPage.self, from: await request("social_notifications", "page", .init()))
            guard !Task.isCancelled, token == generation else { return }
            if revision == countRevision { unread = max(0,page.unread); failed = false }
            if broadcast { NotificationCenter.default.post(name: .socialRemoteRefresh, object: nil) }
        } catch is CancellationError {} catch {
            guard token == generation, revision == countRevision else { return }; unread = 0; failed = true
        }
    }
}
private struct SocialActivityKey: EnvironmentKey { static let defaultValue: SocialActivityCoordinator? = nil }
extension EnvironmentValues {
    var socialActivity: SocialActivityCoordinator? { get { self[SocialActivityKey.self] } set { self[SocialActivityKey.self] = newValue } }
}
struct SocialActivityHost: ViewModifier {
    let coordinator: SocialActivityCoordinator
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    func body(content: Content) -> some View {
        content.environment(\.socialActivity, coordinator)
            .task(id: phase) {
                guard phase == .active, let request else { return }
                let token = coordinator.connect(request)
                defer { coordinator.disconnect(token) }
                while !Task.isCancelled {
                    await coordinator.refresh(broadcast: true)
                    do { try await Task.sleep(for: .seconds(coordinator.failed ? 60 : 30)) } catch { return }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in if phase == .active { Task { await coordinator.refresh() } } }
            .onReceive(NotificationCenter.default.publisher(for: .socialEngagementChanged)) { _ in if phase == .active { Task { await coordinator.refresh() } } }
    }
}
extension Notification.Name {
    static let socialRemoteRefresh = Notification.Name("StayGrubby.socialRemoteRefresh")
    static let socialEngagementChanged = Notification.Name("StayGrubby.socialEngagementChanged")
}

/// Read screens refresh only while visible; editors/drafts are never replaced by polling.
private struct SocialRefresh: ViewModifier {
    var action: () async -> Void
    @Environment(\.scenePhase) private var phase
    @State private var visible = false
    @State private var revision = 0
    func body(content: Content) -> some View {
        content.onAppear { visible = true }.onDisappear { visible = false }
            .onReceive(NotificationCenter.default.publisher(for: .socialRemoteRefresh)) { _ in if visible && phase == .active { revision += 1 } }
            .task(id: revision) { if revision > 0 && visible && phase == .active { await action() } }
    }
}
extension View { func onSocialRefresh(_ action: @escaping () async -> Void) -> some View { modifier(SocialRefresh(action: action)) } }
