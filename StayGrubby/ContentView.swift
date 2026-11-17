import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppLinkRouter.self) private var links
    @Environment(AccountSessionCoordinator.self) private var accountSession
    @State private var activity = SocialActivityCoordinator()
    @State private var selection: StayGrubbyTab = .rankings

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { SocialFeedView(isSelected: selection == .feed).modifier(SGPrimaryTabChrome()) }
                .tabItem { Label("The Pass", systemImage: "house") }.tag(StayGrubbyTab.feed)

            HomeView().modifier(SGPrimaryTabChrome())
                .tabItem { Label("Grub Rank", systemImage: "chart.bar.fill") }
                .tag(StayGrubbyTab.rankings)

            NavigationStack { FoodBibleView().modifier(SGPrimaryTabChrome()) }
                .tabItem { Label("Food Bible", systemImage: "book.closed") }.tag(StayGrubbyTab.bible)

            NavigationStack {
                AccountView().modifier(SGPrimaryTabChrome())
            }
            .tabItem { Label("My Kitchen", systemImage: "person") }.badge(activity.unread).tag(StayGrubbyTab.profile)
        }
        .tint(SGTheme.ColorToken.accent)
        .environment(\.selectTab, { selection = $0 })
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
extension EnvironmentValues {
    var selectTab: (StayGrubbyTab) -> Void {
        get { self[SelectTabKey.self] } set { self[SelectTabKey.self] = newValue }
    }
}

#Preview {
    ContentView().environment(AppLinkRouter()).environment(AccountSessionCoordinator()).modelContainer(try! ModelContainer(for: AppPersistence.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]))
}
