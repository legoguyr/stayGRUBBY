import SwiftUI

// Shared library chrome (owner steering, November 18, 2026): Grub Rank and Food Bible use the same
// header, search field, circular + and filter row. Screens keep their own identity and options.

/// The one circular + used by every library screen. Where it leads is the screen's choice.
struct SGCreateButton: View {
    let title: String
    var identifier: String
    let action: () -> Void
    var body: some View {
        SGIconButton(title: title, symbol: "plus", emphasized: true, action: action).accessibilityIdentifier(identifier)
    }
}

/// Horizontally scrolling filter chips with one clear X at their end, and a compact circular Sort pinned
/// beside them so it stays reachable while the chips scroll.
struct SGFilterRail<Chips: View, Sort: View>: View {
    var clearActive = false
    var clearTitle = "Clear Filters"
    var clearIdentifier = "clear-filters"
    var clear: () -> Void = {}
    @ViewBuilder var chips: Chips
    @ViewBuilder var sort: Sort
    var body: some View {
        HStack(spacing: SGTheme.Space.xSmall) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SGTheme.Space.xSmall) {
                    chips
                    if clearActive {
                        SGIconButton(title: clearTitle, symbol: "xmark", action: clear).accessibilityIdentifier(clearIdentifier)
                    }
                }.padding(.vertical, 1)
            }
            // Chips clip at the rail's edge (a soft fade) so they never run under Sort.
            .mask(HStack(spacing: 0) { Color.black; LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: SGTheme.Space.medium) })
            sort
        }
    }
}

/// The one tab header (UI overhaul, Nov 18, 2026): wordmark and page name on the left, the page's actions on
/// the right as circular controls (utilities neutral via `sgHeaderAction()`, the one create action red).
/// Used by The Pass, Grub Rank, Food Bible and My Kitchen, so every tab opens the same way.
struct SGLibraryHeader<Trailing: View>: View {
    let page: String
    var create: (() -> Void)? = nil
    var createTitle = "Create"
    var createIdentifier = "creation-toggle"
    /// Stable accessibility identifier for the title group.
    var identifier = "primary-brand-title"
    @ViewBuilder var trailing: Trailing
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        HStack(alignment: .center, spacing: SGTheme.Space.xSmall) {
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) { identity }
                } else { HStack(spacing: SGTheme.Space.small) { identity } }
            }.accessibilityElement(children: .ignore)
                .accessibilityLabel("#stayGRUBBY, \(page)").accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(identifier)
            Spacer(minLength: 0)
            trailing
            if let create { SGCreateButton(title: createTitle, identifier: createIdentifier, action: create) }
        }
        .frame(minHeight: SGTheme.Size.minimumTap)
    }
    @ViewBuilder private var identity: some View {
        SGPrimaryBrandTitle(page: page)
        Text(page).font(SGTheme.TypeRole.headline).fixedSize(horizontal: false, vertical: true)
    }
}
extension SGLibraryHeader where Trailing == EmptyView {
    init(page: String, create: (() -> Void)? = nil, createTitle: String = "Create", createIdentifier: String = "creation-toggle", identifier: String = "primary-brand-title") {
        self.init(page: page, create: create, createTitle: createTitle, createIdentifier: createIdentifier, identifier: identifier) { EmptyView() }
    }
}

extension View {
    /// Circular neutral utility control in a tab header (notifications, people, settings, share).
    func sgHeaderAction() -> some View {
        sgUtilityTint()
            .frame(width: SGTheme.Size.minimumTap, height: SGTheme.Size.minimumTap)
            .background(SGTheme.ColorToken.elevatedSurface, in: Circle())
            .contentShape(Circle())
    }
    /// Places the shared tab header above a tab's content and hides the system bar for that tab.
    func sgTabHeader<Header: View>(@ViewBuilder _ header: () -> Header) -> some View {
        let header = header()
        return toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                header.padding(.horizontal, SGTheme.Space.medium).padding(.vertical, SGTheme.Space.xSmall)
                    .background(SGTheme.ColorToken.background)
            }
    }
}
