import SwiftUI

// Stage B browsing grammar (owner-revised November 7, 2026):
//   Grub Rank  header · [Course][Cuisine][Dietary][Avoid] · [Sort] … [All Versions ⏽] [clear]
//              (chips: multi-select sheets that stay open until Done; active = red, no count)
//   Food Bible search · [Filters n] [Sort] [clear]   (more groups than fit one even row)
// Few common groups get direct, equal-width `SGFilterChip`s that each open one
// `SGFilterGroupSheet`; larger sets use one `SGFilterSheet`. Sort is its own compact
// native menu. Features own state and semantics.

/// One native menu for read-only ordering. The label names the current choice.
struct SGBrowseSortMenu<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    var title: (Option) -> String
    var disabled: (Option) -> Bool = { _ in false }
    var active = false
    var identifier: String
    /// Text shown in the control; defaults to "Sort".
    var label: String? = nil

    var body: some View {
        Menu {
            Section("Sort by") {
                ForEach(options) { option in
                    Button { selection = option } label: {
                        if option == selection { Label(title(option), systemImage: "checkmark") }
                        else { Text(title(option)) }
                    }.disabled(disabled(option)).accessibilityIdentifier("\(identifier)-\(String(describing: option.id))")
                }
            }
        } label: { SGBrowseControlLabel(title: label ?? "Sort", symbol: "arrow.up.arrow.down", active: active) }
            .accessibilityLabel("Sort, \(title(selection))").accessibilityValue(label ?? title(selection))
            .accessibilityIdentifier(identifier)
    }
}

/// A direct filter-group control: equal width within its row, opening that group's
/// sheet. Active is shown by color only (red title, selected fill) — no count — so the
/// chip's geometry never changes when filters toggle.
struct SGFilterChip: View {
    let title: String
    let count: Int
    var summary: String? = nil
    var identifier: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: SGTheme.Space.hairline) {
                Text(title).lineLimit(1).fixedSize()
                Image(systemName: "chevron.down").font(.caption2.weight(.semibold)).accessibilityHidden(true)
            }
            .font(SGTheme.TypeRole.secondary.weight(.medium))
            .foregroundStyle(count > 0 ? SGTheme.ColorToken.accent : SGTheme.ColorToken.primaryText)
            .padding(.horizontal, SGTheme.Space.small)
            .frame(maxWidth: .infinity, minHeight: SGTheme.Size.minimumTap)
            .background(count > 0 ? SGTheme.ColorToken.selected : SGTheme.ColorToken.surface, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain).accessibilityIdentifier(identifier)
        .accessibilityLabel(count > 0 ? "\(title), \(count) active" : title)
        .accessibilityValue(summary ?? (count > 0 ? "\(count) selected" : "Any"))
    }
}

/// A browse-mode switch styled like the other controls (e.g. Show All Versions).
struct SGBrowseToggle: View {
    let title: String
    @Binding var isOn: Bool
    var identifier: String
    /// Fuller spoken name when the visible title is shortened for width.
    var spokenTitle: String? = nil
    var body: some View {
        Toggle(isOn: $isOn) { Text(title).font(SGTheme.TypeRole.secondary.weight(.medium)).lineLimit(1).fixedSize() }
            .toggleStyle(.switch).tint(SGTheme.ColorToken.accent).fixedSize()
            .padding(.leading, SGTheme.Space.medium).padding(.trailing, SGTheme.Space.xSmall)
            .frame(minHeight: SGTheme.Size.minimumTap)
            .background(SGTheme.ColorToken.surface, in: Capsule())
            .accessibilityLabel(spokenTitle ?? title).accessibilityIdentifier(identifier)
    }
}

/// One filter group presented on its own (from an `SGFilterChip`). Pushed-page
/// chrome is shared with `SGFilterSheet`, so Clear/Done behave identically.
struct SGFilterGroupSheet<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack { content }
            .environment(\.sgCloseFilterSheet, { dismiss() })
            .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}

/// The single Filter entry point: shows how many filters are active.
struct SGFilterButton: View {
    let count: Int
    var identifier: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            SGBrowseControlLabel(title: count > 0 ? "Filters \(count)" : "Filters",
                                 symbol: "line.3.horizontal.decrease", active: count > 0)
        }
        .buttonStyle(.plain).accessibilityIdentifier(identifier)
        .accessibilityLabel(count > 0 ? "Filters, \(count) active" : "Filters")
    }
}

/// Scrolling option content shared by filter groups and editing selectors. Not lazy,
/// so every row exists for VoiceOver and UI automation.
struct SGOptionList<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView { VStack(spacing: SGTheme.Space.xSmall) { content }.padding(SGTheme.Space.margin) }
            .background(SGTheme.ColorToken.background)
    }
}

/// Short secondary note under an option list.
struct SGOptionNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, SGTheme.Space.small)
    }
}

/// A quiet heading that separates groups inside one option list (Diet / Certification).
struct SGOptionGroupLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(SGTheme.TypeRole.secondary.weight(.semibold)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, SGTheme.Space.small).accessibilityAddTraits(.isHeader)
    }
}

/// A standalone option sheet (editing a cook's Dietary/Contains, a single filter group):
/// native title, Done, medium/large detents.
struct SGOptionSheet<Content: View>: View {
    let title: String
    var doneIdentifier = "filters-done"
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            SGOptionList { content }
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier(doneIdentifier) } }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}

/// One Filters sheet: a root list of groups with their current summary; each group
/// pushes its own options. Done and Clear All are available on every page.
struct SGFilterSheet<Content: View>: View {
    let isActive: Bool
    let clear: () -> Void
    var doneIdentifier = "filters-done"
    var clearIdentifier = "filters-clear-all"
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            SGOptionList { content }
                .navigationTitle("Filters").navigationBarTitleDisplayMode(.inline)
                .toolbar { SGFilterSheetToolbar(isActive: isActive, clear: clear, done: { dismiss() },
                                                 doneIdentifier: doneIdentifier, clearIdentifier: clearIdentifier) }
        }
        .environment(\.sgCloseFilterSheet, { dismiss() })
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}

private struct SGCloseFilterSheetKey: EnvironmentKey { static let defaultValue: (() -> Void)? = nil }
extension EnvironmentValues {
    /// Set by `SGFilterSheet`; pushed group pages use it so Done closes the whole sheet.
    var sgCloseFilterSheet: (() -> Void)? {
        get { self[SGCloseFilterSheetKey.self] }
        set { self[SGCloseFilterSheetKey.self] = newValue }
    }
}

/// A pushed filter group page: group title plus the sheet's Clear and Done.
struct SGFilterGroupPage<Content: View>: View {
    let title: String
    let isActive: Bool
    let clear: () -> Void
    var clearTitle = "Clear"
    var clearIdentifier = "filter-group-clear"
    @ViewBuilder var content: Content
    @Environment(\.sgCloseFilterSheet) private var close
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        SGOptionList { content }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(clearTitle, action: clear).disabled(!isActive).accessibilityIdentifier(clearIdentifier)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { if let close { close() } else { dismiss() } }.accessibilityIdentifier("filters-done")
                }
            }
    }
}

/// Group pages keep the sheet's Done so one tap closes the whole Filters sheet.
struct SGFilterSheetToolbar: ToolbarContent {
    let isActive: Bool
    let clear: () -> Void
    let done: () -> Void
    var doneIdentifier = "filters-done"
    var clearIdentifier = "filters-clear-all"
    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Clear All", action: clear).disabled(!isActive).accessibilityIdentifier(clearIdentifier)
        }
        ToolbarItem(placement: .confirmationAction) { Button("Done", action: done).accessibilityIdentifier(doneIdentifier) }
    }
}

/// Root row for one filter group: title, current summary, native disclosure.
struct SGFilterGroupLink<Destination: View>: View {
    let title: String
    var summary: String? = nil
    var count = 0
    var identifier: String
    @ViewBuilder var destination: Destination
    var body: some View {
        NavigationLink { destination } label: {
            HStack(spacing: SGTheme.Space.small) {
                Text(title).font(SGTheme.TypeRole.body)
                Spacer(minLength: SGTheme.Space.small)
                Text(summary ?? (count > 0 ? "\(count) selected" : "Any"))
                    .font(SGTheme.TypeRole.body)
                    .foregroundStyle(count > 0 || summary != nil ? SGTheme.ColorToken.accent : SGTheme.ColorToken.subdued)
                    .multilineTextAlignment(.trailing).lineLimit(2)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary).accessibilityHidden(true)
            }
            .padding(.horizontal, SGTheme.Space.medium).frame(minHeight: SGTheme.Size.minimumTap)
            .padding(.vertical, SGTheme.Space.xSmall)
            .background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: SGTheme.Radius.field))
            .contentShape(Rectangle())
        }
        .buttonStyle(SGRowButtonStyle())
        .accessibilityIdentifier(identifier)
        .accessibilityLabel("\(title), \(count) active selections")
        .accessibilityValue(summary ?? (count > 0 ? "\(count) selected" : "Any"))
    }
}
