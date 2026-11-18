import SwiftUI

/// #stayGRUBBY tab icons (master UI milestone, November 18, 2026). Filled template vectors in the asset
/// catalog, matching how the iOS 26 tab bar draws SF Symbols (always filled); selection shows through the
/// tab bar's tint and highlight, in light and dark mode.
/// - The Pass: a kitchen ticket rail with order tickets (where food is called and passed).
/// - Grub Rank: a three-tier podium, tallest in the centre, with a small star.
/// - Food Bible: the system closed book (unchanged).
/// - My Kitchen: a person with a small chef hat (`SousChefs` uses the same language for two cooks).
struct SGTabLabel: View {
    let tab: StayGrubbyTab
    let selected: Bool
    var body: some View {
        Label { Text(title) } icon: { icon }
    }
    private var title: String {
        switch tab {
        case .feed: "The Pass"
        case .rankings: "Grub Rank"
        case .bible: "Food Bible"
        case .profile: "My Kitchen"
        }
    }
    @ViewBuilder private var icon: some View {
        switch tab {
        case .feed: Image("TabPassFill").renderingMode(.template)
        case .rankings: Image("TabRankFill").renderingMode(.template)
        case .bible: Image(systemName: "book.closed.fill")
        case .profile: Image("TabKitchenFill").renderingMode(.template)
        }
    }
}
