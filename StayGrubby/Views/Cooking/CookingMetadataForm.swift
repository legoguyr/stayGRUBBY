import SwiftUI

/// Value-only state: dismissing the enclosing editor never writes to saved objects.
struct CookingMetadataForm: View {
    @Binding var draft: CookingDraft
    var existingDish = false
    var editing = false
    var sharingSelection: Binding<CookingSharingSelection>? = nil
    var cookedWith: Binding<Set<UUID>>? = nil
    var editingParticipants = false
    var selectedPeople: [SocialPerson] = []
    /// The cook's "Version N" fallback, or nil when an unnamed cook shows no name.
    var fallbackCookName: String? = nil
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var details = false
    @FocusState private var focusedField: EntryField?
    private enum EntryField: Hashable { case name, description, dishNotes, version }

    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            CookingPhotoEditor(draft: $draft)
            VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
                if existingDish && !editing {
                    Text(draft.dishName).font(SGTheme.TypeRole.title)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("inherited-dish-name")
                } else {
                    TextField("Dish name (required)", text: $draft.dishName).font(SGTheme.TypeRole.title)
                        .focused($focusedField, equals: .name).submitLabel(.done).onSubmit { focusedField = nil }
                        .accessibilityIdentifier("dish-name").sgField()
                }
                TextField("Cook Name (optional)", text: $draft.versionTitle).accessibilityIdentifier("version-title")
                    .focused($focusedField, equals: .version).submitLabel(.done).onSubmit { focusedField = nil }.sgField()
                if let fallbackCookName, draft.cleanTitle == nil {
                    Text("Leave blank to show \(fallbackCookName).").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                        .accessibilityIdentifier("cook-name-fallback")
                }
                VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                    Text("Public Description").font(SGTheme.TypeRole.secondary.weight(.semibold))
                    TextField("A few words for your Sous Chefs", text: $draft.publicDescription, axis: .vertical)
                        .focused($focusedField, equals: .description).lineLimit(1...4).accessibilityIdentifier("cook-dish-description").sgField()
                }
                if editing {
                    Toggle("Cooked date known", isOn: Binding(get: { draft.cookedAt != nil }, set: { draft.cookedAt = $0 ? .now : nil }))
                }
                if draft.cookedAt != nil { cookedDate.accessibilityIdentifier("cook-date") }
                else if !editing {
                    Button("Set required cooked date") { draft.cookedAt = .now }.frame(minHeight: SGTheme.Size.minimumTap)
                }
                VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                    Label("Private Notes", systemImage: "lock").font(SGTheme.TypeRole.secondary.weight(.semibold))
                    TextField("For your kitchen only", text: $draft.privateNotes, axis: .vertical)
                        .focused($focusedField, equals: .dishNotes).lineLimit(1...4).accessibilityIdentifier("cook-dish-private-notes").sgField()
                }
                if existingDish || editing {
                    Text(editing ? "Name, description, Dish notes, Cuisine and Source apply to every cook of this Dish." : "Description and Dish notes apply to every cook of this Dish.").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                }
                if !draft.validDishText {
                    Text("Keep the description within 2,000 characters and private notes within 8,000.")
                        .font(.footnote).foregroundStyle(SGTheme.ColorToken.destructive)
                }
            }
            Button { focusedField = nil; details = true } label: {
                HStack(spacing: SGTheme.Space.small) {
                    Label("Details", systemImage: "slider.horizontal.3")
                    Spacer(minLength: SGTheme.Space.small)
                    Text([draft.category.label, draft.cuisine?.label].compactMap { $0 }.joined(separator: " · "))
                        .foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }.font(SGTheme.TypeRole.body).frame(minHeight: SGTheme.Size.minimumTap).contentShape(Rectangle())
            }.buttonStyle(SGButtonStyle(compact: true)).accessibilityIdentifier("cook-details")
            if let cookedWith { CookedWithSelection(selected: cookedWith, editing: editingParticipants, existingPeople: selectedPeople) }
            if let sharingSelection { CookingSharingChoice(selection: sharingSelection) }


        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField != nil {
                    Spacer()
                    Button("Done") { focusedField = nil }.accessibilityIdentifier("cook-keyboard-done")
                }
            }
        }
        .sheet(isPresented: $details) { CookingDetailsSheet(draft: $draft, inherited: existingDish && !editing) }
    }
    private var cookedDate: some View {
        DatePicker(editing ? "Date cooked" : "Date cooked (required)", selection: Binding(get: { draft.cookedAt ?? .now }, set: { draft.cookedAt = $0 }), displayedComponents: .date)
            .font(SGTheme.TypeRole.body).frame(minHeight: SGTheme.Size.minimumTap)
    }
}

struct SGFormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            SGEyebrow(text: title)
            content
        }.font(SGTheme.TypeRole.body).padding(.vertical, SGTheme.Space.medium)
            .overlay(alignment: .top) { Divider().accessibilityHidden(true) }
    }
}

struct CookingFormScroll: View {
    @Binding var draft: CookingDraft
    var existingDish = false
    var editing = false
    var sharingSelection: Binding<CookingSharingSelection>? = nil
    var cookedWith: Binding<Set<UUID>>? = nil
    var editingParticipants = false
    var selectedPeople: [SocialPerson] = []
    var fallbackCookName: String? = nil
    var body: some View {
        ScrollView {
            CookingMetadataForm(draft: $draft, existingDish: existingDish, editing: editing, sharingSelection: sharingSelection, cookedWith: cookedWith, editingParticipants: editingParticipants, selectedPeople: selectedPeople, fallbackCookName: fallbackCookName)
                .frame(maxWidth: SGTheme.Size.contentMaximum)
                .padding(SGTheme.Space.medium).frame(maxWidth: .infinity)
        }.accessibilityIdentifier("cooking-form").scrollDismissesKeyboard(.interactively).background(SGTheme.ColorToken.background)
    }
}
