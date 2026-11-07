import SwiftUI

/// Shared presentation; no feature state, authorization or ranking decisions.
struct SGEyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(SGTheme.TypeRole.eyebrow).tracking(1.6)
            .foregroundStyle(SGTheme.ColorToken.accent).fixedSize(horizontal: false, vertical: true)
    }
}
struct SGPageIntro: View {
    let title: String
    let subtitle: String
    var eyebrow: String? = nil
    var showsTitle = true
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            if let eyebrow { SGEyebrow(text: eyebrow) }
            if showsTitle { Text(title).font(SGTheme.TypeRole.page).tracking(-0.8).accessibilityAddTraits(.isHeader) }
            Text(subtitle).font(SGTheme.TypeRole.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, SGTheme.Space.medium)
    }
}
/// Shared empty / unavailable / error state on the native ContentUnavailableView:
/// short title, one-line message, optional recovery action. No paragraphs.
struct SGContentState<Actions: View>: View {
    let title: String
    let symbol: String
    var message: String? = nil
    @ViewBuilder var actions: Actions
    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            if let message { Text(message) }
        } actions: { actions }
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(SGTheme.ColorToken.primaryText)
    }
}
extension SGContentState where Actions == EmptyView {
    init(title: String, symbol: String, message: String? = nil) {
        self.init(title: title, symbol: symbol, message: message) { EmptyView() }
    }
}
/// Shared loading state: native spinner with a concrete label.
struct SGLoadingState: View {
    let label: String
    var body: some View { ProgressView(label).frame(maxWidth: .infinity).padding(.vertical, SGTheme.Space.xLarge) }
}
struct SGDestinationLabel: View {
    let title: String
    let subtitle: String
    let symbol: String
    var showsChevron = true
    var body: some View {
        HStack(spacing: SGTheme.Space.medium) {
            Image(systemName: symbol).font(.title3).foregroundStyle(SGTheme.ColorToken.accent).frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(SGTheme.TypeRole.headline).foregroundStyle(SGTheme.ColorToken.primaryText)
                if !subtitle.isEmpty { Text(subtitle).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
            if showsChevron { Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary).accessibilityHidden(true) }
        }.padding(.vertical, SGTheme.Space.small).frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
    }
}
struct SGListPresentation: ViewModifier {
    func body(content: Content) -> some View {
        content.listStyle(.plain).scrollContentBackground(.hidden)
            .background(SGTheme.ColorToken.background)
            .environment(\.defaultMinListRowHeight, SGTheme.Size.minimumTap)
    }
}
extension View {
    func sgEditorialList() -> some View { modifier(SGListPresentation()) }
}

struct SGEditorialList<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        List {
            Group { content }.listRowBackground(SGTheme.ColorToken.background)
                .listRowInsets(EdgeInsets(top: SGTheme.Space.small, leading: SGTheme.Space.medium, bottom: SGTheme.Space.small, trailing: SGTheme.Space.medium))
        }.sgEditorialList()
    }
}
