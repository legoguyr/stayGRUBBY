import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppLinkRouter.self) private var links
    @Environment(AccountSessionCoordinator.self) private var accountSession
    @State private var activity = SocialActivityCoordinator()
    @State private var selection: StayGrubbyTab = .rankings
    @State private var grubRankRequest: GrubRankRequest?

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { SocialFeedView(isSelected: selection == .feed).modifier(SGPrimaryTabChrome()) }
                .tabItem { SGTabLabel(tab: .feed, selected: selection == .feed) }.tag(StayGrubbyTab.feed)

            HomeView().modifier(SGPrimaryTabChrome())
                .tabItem { SGTabLabel(tab: .rankings, selected: selection == .rankings) }
                .tag(StayGrubbyTab.rankings)

            NavigationStack { FoodBibleView().modifier(SGPrimaryTabChrome()) }
                .tabItem { SGTabLabel(tab: .bible, selected: selection == .bible) }.tag(StayGrubbyTab.bible)

            NavigationStack {
                AccountView().modifier(SGPrimaryTabChrome())
            }
            .tabItem { SGTabLabel(tab: .profile, selected: selection == .profile) }.badge(activity.unread).tag(StayGrubbyTab.profile)
        }
        .tint(SGTheme.ColorToken.accent)
        .environment(\.selectTab, { selection = $0 })
        .environment(\.openGrubRank, { mode in grubRankRequest = GrubRankRequest(mode: mode); selection = .rankings })
        .environment(\.grubRankRequest, grubRankRequest)
        .onChange(of: links.ownKitchenRequests) { _, _ in selection = .profile }
        .modifier(AppLinkPresentation())
        .modifier(SocialActivityHost(coordinator: activity))
        .modifier(SocialPublicationHost())
        .modifier(SocialOnboardingHost())
        #if DEBUG
        .modifier(SocialReviewModifier())
        #endif

    }


}

enum StayGrubbyTab: Hashable { case feed, rankings, bible, profile }

/// Switches the root tab (Connected UI: My Kitchen statistics open Grub Rank and Food Bible).
private struct SelectTabKey: EnvironmentKey { static let defaultValue: (StayGrubbyTab) -> Void = { _ in } }
private struct OpenGrubRankKey: EnvironmentKey { static let defaultValue: (RankingsDisplayMode) -> Void = { _ in } }
private struct GrubRankRequestKey: EnvironmentKey { static let defaultValue: GrubRankRequest? = nil }
extension EnvironmentValues {
    var selectTab: (StayGrubbyTab) -> Void {
        get { self[SelectTabKey.self] } set { self[SelectTabKey.self] = newValue }
    }
    /// Opens Grub Rank in a view: `.topVersion` (one row per Dish) or `.allVersions` (All Cooks).
    var openGrubRank: (RankingsDisplayMode) -> Void {
        get { self[OpenGrubRankKey.self] } set { self[OpenGrubRankKey.self] = newValue }
    }
    var grubRankRequest: GrubRankRequest? {
        get { self[GrubRankRequestKey.self] } set { self[GrubRankRequestKey.self] = newValue }
    }
}

#Preview {
    ContentView().environment(AppLinkRouter()).environment(AccountSessionCoordinator()).modelContainer(try! ModelContainer(for: AppPersistence.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]))
}
