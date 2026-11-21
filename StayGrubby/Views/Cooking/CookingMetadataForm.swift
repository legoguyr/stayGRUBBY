import SwiftUI
import SwiftData

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
    /// Rank a Dish only: lets the owner explicitly pick an existing Dish instead (nil opens the picker).
    var chooseExisting: ((Dish?) -> Void)? = nil
    /// Edit Cook: how many cooks share this Dish (its name renames all of them).
    var sharedCookCount = 0
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.featureFlags) private var flags
    @State private var details = false
    @FocusState private var focusedField: EntryField?
    private enum EntryField: Hashable { case name, description, dishNotes, version }

    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
            CookingPhotoEditor(draft: $draft)
            // Grouped by owner (FOOD_ARCHITECTURE §7.3): Dish fields apply to every cook; cook fields to this one.
            SGFormSection(title: "This Dish") {
                VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
                        if existingDish && !editing {
                            Text(draft.dishName).font(SGTheme.TypeRole.title)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("inherited-dish-name")
                        } else {
                            TextField("Dish name (required)", text: $draft.dishName).font(SGTheme.TypeRole.title)
                                .focused($focusedField, equals: .name).submitLabel(.done).onSubmit { focusedField = nil }
                                .accessibilityIdentifier("dish-name").sgField()
                            if let chooseExisting { ExistingDishPrompt(name: draft.dishName, choose: chooseExisting) }
                            if editing && sharedCookCount > 1 {
                                // The owner's risotto trap: renaming here renamed every cook's shared Dish.
                                Text("This renames the Dish for all \(sharedCookCount) cooks. If this cook is a different dish, use Separate Cooks on the Dish page instead.")
                                    .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary).accessibilityIdentifier("edit-dish-name-shared")
                            }
                        }
                        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                            Label("Private Notes", systemImage: "lock").font(SGTheme.TypeRole.secondary.weight(.semibold))
                            TextField("For your kitchen only", text: $draft.privateNotes, axis: .vertical)
                                .focused($focusedField, equals: .dishNotes).lineLimit(1...4).accessibilityIdentifier("cook-dish-private-notes").sgField()
                        }
                        if flags.isOn(.dishCollections) {
                            DishCollectionsField(labels: Binding(get: { draft.collections ?? [] }, set: { draft.collections = $0 }))
                        }
                        if existingDish || editing {
                            Text(editing ? "These apply to every cook of this Dish, including Cuisine and Source in Details." : "Private Notes apply to every cook of this Dish.").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                        }
                        if !draft.validDishText {
                            Text("Keep the description within 2,000 characters and private notes within 8,000.")
                                .font(SGTheme.TypeRole.footnote).foregroundStyle(SGTheme.ColorToken.destructive)
                        }
                }
            }
            SGFormSection(title: "This cook") {
                VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
                        TextField("Cook Name (optional)", text: $draft.versionTitle).accessibilityIdentifier("version-title")
                            .focused($focusedField, equals: .version).submitLabel(.done).onSubmit { focusedField = nil }.sgField()
                        // One description per cook (November 21, 2026): this cook's own text, the caption The Pass
                        // shows when this cook is posted. Never shared with the Dish's other cooks.
                        VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                            Text("Description").font(SGTheme.TypeRole.secondary.weight(.semibold))
                            TextField("A few words about this cook for your Sous Chefs", text: $draft.publicDescription, axis: .vertical)
                                .focused($focusedField, equals: .description).lineLimit(1...4).accessibilityIdentifier("cook-dish-description").sgField()
                            Text("Shown with this cook on The Pass when you post it.").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                        }
                        if let fallbackCookName, draft.cleanTitle == nil {
                            Text("Leave blank to show \(fallbackCookName).").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                                .accessibilityIdentifier("cook-name-fallback")
                        }
                        if editing {
                            Toggle("Cooked date known", isOn: Binding(get: { draft.cookedAt != nil }, set: { draft.cookedAt = $0 ? .now : nil }))
                        }
                        if draft.cookedAt != nil { cookedDate.accessibilityIdentifier("cook-date") }
                        else if !editing {
                            Button("Set required cooked date") { draft.cookedAt = .now }.frame(minHeight: SGTheme.Size.minimumTap)
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
                    if draft.prefilledFromRecipe {
                        Text("Diet and Contains were filled in from the Recipe as written. Check them in Details for what you actually made.")
                            .font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary).accessibilityIdentifier("cook-recipe-prefill")
                    }
                }
            }
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
    var chooseExisting: ((Dish?) -> Void)? = nil
    var sharedCookCount = 0
    var body: some View {
        ScrollView {
            CookingMetadataForm(draft: $draft, existingDish: existingDish, editing: editing, sharingSelection: sharingSelection, cookedWith: cookedWith, editingParticipants: editingParticipants, selectedPeople: selectedPeople, fallbackCookName: fallbackCookName, chooseExisting: chooseExisting, sharedCookCount: sharedCookCount)
                .frame(maxWidth: SGTheme.Size.contentMaximum)
                .padding(SGTheme.Space.medium).frame(maxWidth: .infinity)
        }.accessibilityIdentifier("cooking-form").scrollDismissesKeyboard(.interactively).background(SGTheme.ColorToken.background)
    }
}

/// Rank a Dish: a new name creates a new Dish. When the typed name matches a Dish already ranked, the owner
/// chooses explicitly whether this is another cook of it; similar names never merge on their own.
struct ExistingDishPrompt: View {
    let name: String
    let choose: (Dish?) -> Void
    @Query(sort: \Dish.name) private var dishes: [Dish]
    private var ranked: [Dish] { dishes.filter { !$0.attempts.isEmpty } }
    private var match: Dish? {
        let key = DishCollectionPolicy.key(name)
        return key.isEmpty ? nil : ranked.first { DishCollectionPolicy.key($0.name) == key }
    }
    var body: some View {
        if let match {
            VStack(alignment: .leading, spacing: SGTheme.Space.xSmall) {
                Text("You’ve ranked “\(match.name)” before.").font(SGTheme.TypeRole.secondary.weight(.semibold))
                Button { choose(match) } label: { Label("Add Another Cook of \(match.name)", systemImage: "plus").frame(maxWidth: .infinity, minHeight: SGTheme.Size.minimumTap, alignment: .leading) }
                    .buttonStyle(SGButtonStyle(compact: true)).accessibilityIdentifier("cook-existing-match")
                Text("Or continue to save it as a separate Dish.").font(SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
            }.accessibilityElement(children: .contain).accessibilityIdentifier("existing-dish-prompt")
        } else if !ranked.isEmpty {
            Button { choose(nil) } label: { Label("Made one of your Dishes again? Choose it", systemImage: "arrow.triangle.branch").font(SGTheme.TypeRole.secondary.weight(.medium)).frame(maxWidth: .infinity, minHeight: SGTheme.Size.minimumTap, alignment: .leading).contentShape(Rectangle()) }
                .buttonStyle(.plain).foregroundStyle(SGTheme.ColorToken.accent).accessibilityIdentifier("cook-existing-dish")
        }
    }
}
