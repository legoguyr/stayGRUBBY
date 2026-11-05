import SwiftUI

/// One native browsing interaction; each domain supplies its own read-only ordering.
struct SGBrowseSortMenu<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    var title: (Option) -> String
    var disabled: (Option) -> Bool = { _ in false }
    var active = false
    var identifier: String
    var body: some View {
        Menu {
            ForEach(options) { option in
                Button { selection = option } label: {
                    if option == selection { Label(title(option), systemImage: "checkmark") }
                    else { Text(title(option)) }
                }.disabled(disabled(option)).accessibilityIdentifier("\(identifier)-\(String(describing: option.id))")
            }
        } label: { SGBrowseControlLabel(title: "Sort", symbol: "arrow.up.arrow.down", active: active) }
            .accessibilityLabel("Sort, \(title(selection))").accessibilityIdentifier(identifier)
    }
}

/// Shared native filter sheet chrome; domain content owns selection and semantics.
struct SGSelectionSheet<Content: View>: View {
    let title: String
    var doneIdentifier = "filters-done"
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView { VStack(spacing: SGTheme.Space.xSmall) { content }.padding(SGTheme.Space.medium) }
                .background(SGTheme.ColorToken.background)
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier(doneIdentifier) } }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}
