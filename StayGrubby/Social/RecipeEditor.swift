import SwiftUI
import SwiftData

/// One editable value, shared by manual entry and future user-reviewed RecipeDrafts.
struct RecipeEditor: View {
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var textSize
    @Query private var dishes: [Dish]
    let recipe: Recipe?
    var dishID: UUID?
    let onSave: (Recipe) -> Void
    @State private var content: RecipeDraft
    private let original: RecipeDraft
    private let originallyShared: Bool
    @State private var shared: Bool
    @State private var recipeID: UUID
    @State private var saving = false
    @State private var failed = false
    @State private var discard = false
    @State private var deleteSection: UUID?
    @FocusState private var focus: RecipeField?
    init(recipe: Recipe? = nil, dishID: UUID? = nil, title: String = "", course: String? = nil, cuisine: String? = nil, draft: RecipeDraft? = nil, onSave: @escaping (Recipe) -> Void) {
        self.recipe = recipe; self.dishID = dishID; self.onSave = onSave
        var value = draft ?? recipe?.content ?? RecipeContent(title: title, course: course, cuisine: cuisine)
        value.components = value.orderedComponents
        original = value; originallyShared = recipe?.visibility == "friends"
        _content = State(initialValue: value); _shared = State(initialValue: recipe?.visibility == "friends")
        _recipeID = State(initialValue: recipe?.id ?? UUID())
    }
    private var dirty: Bool { content != original || shared != originallyShared }
    private var parts: [RecipeComponent] { content.components ?? [] }
    private var dish: Dish? { dishes.first { $0.id == dishID } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    identity
                    details
                    VStack(alignment: .leading, spacing: 16) {
                        SGEyebrow(text: "Ingredients")
                        ForEach(parts) { part in ingredientSection(part) }
                        Button("Add Section", systemImage: "plus.rectangle.on.rectangle") {
                            let part = RecipeComponent(); content.components?.append(part); focus = .section(part.id)
                        }.buttonStyle(RecipeInlineAction()).disabled(parts.count >= 20).accessibilityIdentifier("recipe-add-component")
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 16) {
                        SGEyebrow(text: "Method")
                        ForEach(parts) { part in methodSection(part) }
                    }
                    Divider()
                    attribution
                    if failed { Label("Couldn’t save. Your draft is safe here. Check your connection and cooking sync, then try Save again. If it changed elsewhere, keep your draft while you review that change.", systemImage: "wifi.exclamationmark").font(.subheadline).accessibilityIdentifier("recipe-save-error") }
                }.padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }.background(SGTheme.ColorToken.background).scrollDismissesKeyboard(.interactively).accessibilityIdentifier("recipe-editor-scroll")
                .navigationTitle(recipe == nil ? "Add Recipe" : "Edit Recipe").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if dirty { discard = true } else { dismiss() } }.disabled(saving) }
                    ToolbarItem(placement: .confirmationAction) { Button(saving ? "Saving…" : "Save") { focus = nil; Task { await save() } }.disabled(saving || !content.isValidDraft).accessibilityIdentifier("recipe-save") }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focus = nil }.accessibilityIdentifier("recipe-keyboard-done") }
                }
        }.interactiveDismissDisabled(dirty || saving)
            .alert("Discard your recipe changes?", isPresented: $discard) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: { Text("Your saved recipe stays unchanged.") }
            .confirmationDialog("Delete this section and its ingredients and steps?", isPresented: Binding(get: { deleteSection != nil }, set: { if !$0 { deleteSection = nil } }), titleVisibility: .visible) {
                Button("Delete Section", role: .destructive) { if let id = deleteSection { content.components?.removeAll { $0.id == id } }; deleteSection = nil }
            }
    }
    private var identity: some View {
        VStack(alignment: .leading, spacing: 16) {
            if dish != nil { CookbookPhoto(dish: dish, name: dish?.name ?? content.title).frame(height: 155).clipShape(RoundedRectangle(cornerRadius: 14)) }
            TextField("Recipe title", text: $content.title, axis: .vertical).font(SGTheme.TypeRole.hero).focused($focus, equals: .title).accessibilityIdentifier("recipe-edit-title")
            TextField("A little about this recipe…", text: optional(\.description), axis: .vertical).font(.body).foregroundStyle(.secondary).accessibilityLabel("Recipe introduction, optional")
        }
    }
    private var details: some View {
        Group {
            if textSize.isAccessibilitySize { VStack(alignment: .leading, spacing: 16) { yieldField; prepField; cookField } }
            else { HStack(alignment: .top, spacing: 20) { yieldField; prepField; cookField } }
        }.padding(.vertical, 8)
    }
    private var yieldField: some View { VStack(alignment: .leading, spacing: 6) { Text("SERVES").font(.caption.bold()).foregroundStyle(.secondary); TextField("e.g. 4", text: optional(\.yield)).accessibilityIdentifier("recipe-yield").accessibilityLabel("Servings or yield, optional") }.frame(minWidth: 80) }
    private var prepField: some View { VStack(alignment: .leading, spacing: 6) { Text("PREP · MIN").font(.caption.bold()).foregroundStyle(.secondary); TextField("—", value: $content.prepMinutes, format: .number).keyboardType(.numberPad).accessibilityLabel("Preparation time in minutes") }.frame(minWidth: 75) }
    private var cookField: some View { VStack(alignment: .leading, spacing: 6) { Text("COOK · MIN").font(.caption.bold()).foregroundStyle(.secondary); TextField("—", value: $content.cookMinutes, format: .number).keyboardType(.numberPad).accessibilityLabel("Cooking time in minutes") }.frame(minWidth: 75) }
    private func sectionHeading(_ part: RecipeComponent) -> some View {
        HStack(alignment: .top) {
            if parts.count > 1 {
                TextField("Section name", text: Binding(get: { parts.first { $0.id == part.id }?.title ?? "" }, set: { value in update(part.id) { $0.title = value.isEmpty ? nil : value } }))
                    .font(.title3.bold()).focused($focus, equals: .section(part.id)).accessibilityIdentifier("recipe-section-name")
            }
            Spacer(minLength: 0)
            if parts.count > 1 {
                Menu {
                    let i = parts.firstIndex { $0.id == part.id } ?? 0
                    Button("Move Section Up") { content.components?.swapAt(i, i-1) }.disabled(i == 0)
                    Button("Move Section Down") { content.components?.swapAt(i, i+1) }.disabled(i+1 == parts.count)
                    Button("Delete Section", role: .destructive) { deleteSection = part.id }
                } label: { Image(systemName: "line.3.horizontal").frame(width: 44, height: 44) }.accessibilityLabel("Section actions, \(part.title ?? "unnamed")").accessibilityIdentifier("recipe-section-actions-\(part.id)")
            }
        }
    }
    private func ingredientSection(_ part: RecipeComponent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeading(part)
            ForEach(part.ingredients) { row in
                RecipeIngredientEditor(row: ingredient(part.id, row.id), focus: $focus, next: { addIngredient(part.id) }, actions: { rowActions(part, rowID: row.id, ingredient: true) })
                Divider()
            }
            Button("Ingredient", systemImage: "plus") { addIngredient(part.id) }.buttonStyle(RecipeInlineAction()).accessibilityIdentifier("recipe-add-ingredient")
        }
    }
    private func methodSection(_ part: RecipeComponent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if parts.count > 1 { Text(part.title?.isEmpty == false ? part.title! : "Untitled section").font(.title3.bold()).accessibilityAddTraits(.isHeader) }
            ForEach(Array(part.steps.enumerated()), id: \.element.id) { i,row in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(stepOffset(part.id)+i+1)").font(.title3.bold()).foregroundStyle(.secondary).frame(minWidth: 24).padding(.top, 10).accessibilityLabel("Step \(stepOffset(part.id)+i+1)")
                    TextField("What happens next?", text: step(part.id,row.id), axis: .vertical).lineLimit(3...20).font(.body).lineSpacing(6).focused($focus, equals: .step(row.id)).padding(.vertical, 10).accessibilityIdentifier("recipe-step-text")
                    rowActions(part, rowID: row.id, ingredient: false)
                }
            }
            Button("Step", systemImage: "plus") { let row = RecipeStep(); update(part.id) { $0.steps.append(row) }; focus = .step(row.id) }.buttonStyle(RecipeInlineAction()).accessibilityIdentifier("recipe-add-step")
        }
    }
    private var attribution: some View {
        VStack(alignment: .leading, spacing: 20) {
            DisclosureGroup("Details & source") {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Course", selection: optional(\.course)) { Text("None").tag(""); ForEach(DishCategory.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) } }
                    TextField("Cuisine · optional", text: optional(\.cuisine))
                    TextField("Original creator · optional", text: optional(\.originalCreator))
                    TextField("Source · optional", text: optional(\.source))
                    TextField("HTTPS source URL · optional", text: optional(\.externalURL)).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    Text("The original creator, who saved the recipe, and who inspired your cook stay separate.").font(.footnote).foregroundStyle(.secondary)
                }.padding(.top, 12)
            }
            DisclosureGroup("Recipe tips") {
                TextField("Anything helpful for next time…", text: optional(\.tips), axis: .vertical).padding(.vertical, 12)
                Text("Recipe tips are shared only if you turn sharing on. Personal Notes on a cook always stay private.").font(.footnote).foregroundStyle(.secondary)
            }
            Toggle("Share recipe with Sous Chefs", isOn: $shared).accessibilityIdentifier("recipe-sharing")
            Text("Off keeps this recipe private. Only recipe fields are shared when on; never your private cooking notes or photos.").font(.footnote).foregroundStyle(.secondary)
        }
    }
    private func rowActions(_ part: RecipeComponent, rowID: UUID, ingredient: Bool) -> some View {
        let ids = ingredient ? part.ingredients.map(\.id) : part.steps.map(\.id)
        let i = ids.firstIndex(of: rowID) ?? 0
        let subject = ingredient ? part.ingredients.first { $0.id == rowID }?.name : part.steps.first { $0.id == rowID }?.instruction
        return RecipeRowActions(label: (ingredient ? "Ingredient actions" : "Step actions") + ", " + (subject?.isEmpty == false ? subject! : "new row"), canUp: i>0, canDown: i+1<ids.count,
            up: { update(part.id) { if ingredient { $0.ingredients.swapAt(i,i-1) } else { $0.steps.swapAt(i,i-1) } } },
            down: { update(part.id) { if ingredient { $0.ingredients.swapAt(i,i+1) } else { $0.steps.swapAt(i,i+1) } } },
            destinations: parts.filter { $0.id != part.id }.map { ($0.id,$0.title ?? "Untitled section") },
            move: { destination in content.moveRecipeRow(rowID, from: part.id, to: destination, ingredient: ingredient) },
            remove: { update(part.id) { if ingredient { $0.ingredients.removeAll { $0.id == rowID } } else { $0.steps.removeAll { $0.id == rowID } } } })
    }
    private func stepOffset(_ id: UUID) -> Int { parts.prefix { $0.id != id }.reduce(0) { $0 + $1.steps.count } }
    private func update(_ id: UUID, _ change: (inout RecipeComponent) -> Void) { if let i = content.components?.firstIndex(where: { $0.id == id }) { change(&content.components![i]) } }
    private func addIngredient(_ id: UUID) { let row = RecipeIngredient(); update(id) { $0.ingredients.append(row) }; focus = .quantity(row.id) }
    private func ingredient(_ part: UUID, _ id: UUID) -> Binding<RecipeIngredient> { Binding(get: { parts.first { $0.id == part }?.ingredients.first { $0.id == id } ?? .init(id:id) }, set: { value in update(part) { if let i = $0.ingredients.firstIndex(where: { $0.id == id }) { $0.ingredients[i] = value } } }) }
    private func step(_ part: UUID, _ id: UUID) -> Binding<String> { Binding(get: { parts.first { $0.id == part }?.steps.first { $0.id == id }?.instruction ?? "" }, set: { value in update(part) { if let i = $0.steps.firstIndex(where: { $0.id == id }) { $0.steps[i].instruction = value } } }) }
    private func optional(_ path: WritableKeyPath<RecipeContent,String?>) -> Binding<String> { Binding(get: { content[keyPath:path] ?? "" }, set: { content[keyPath:path] = $0.isEmpty ? nil : $0 }) }
    private func save() async {
        guard let request else { failed = true; return }; saving = true; failed = false; defer { saving = false }
        do {
            var payload = SocialPayload(); payload.recipeID = recipeID; payload.dishID = dishID; payload.expectedRevision = recipe?.revision
            payload.recipe = content.preparedForSave(); payload.visibility = shared ? "friends" : "private"
            let next = try JSONDecoder().decode(Recipe.self, from: await request("recipes", "save", payload))
            try Task.checkCancellation(); NotificationCenter.default.post(name: .socialContentChanged, object: nil); onSave(next); dismiss()
        } catch is CancellationError {} catch { failed = true }
    }
}
private enum RecipeField: Hashable { case title, section(UUID), quantity(UUID), unit(UUID), ingredient(UUID), step(UUID) }
private struct RecipeIngredientEditor<Actions: View>: View {
    @Binding var row: RecipeIngredient
    var focus: FocusState<RecipeField?>.Binding
    var next: () -> Void
    @ViewBuilder var actions: () -> Actions
    @Environment(\.dynamicTypeSize) private var size
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                if size.isAccessibilitySize { VStack(alignment: .leading, spacing: 12) { measures; name } }
                else { HStack(alignment: .top, spacing: 8) { measures; name } }
                actions()
            }
            DisclosureGroup(row.preparation.isEmpty && row.note.isEmpty ? "Preparation & note" : [row.preparation,row.note].filter { !$0.isEmpty }.joined(separator: ", ")) {
                TextField("e.g. finely chopped", text: $row.preparation, axis: .vertical).accessibilityLabel("Ingredient preparation")
                TextField("Optional ingredient note", text: $row.note, axis: .vertical)
            }.font(.subheadline).foregroundStyle(.secondary)
        }.padding(.vertical, 10)
    }
    private var measures: some View {
        HStack(spacing: 4) {
            TextField("Qty", text: $row.quantity).frame(minWidth: 40, idealWidth: 45, maxWidth: size.isAccessibilitySize ? .infinity : 65).focused(focus, equals: .quantity(row.id)).submitLabel(.next).onSubmit { focus.wrappedValue = .unit(row.id) }.accessibilityLabel("Ingredient quantity")
            TextField("Unit", text: $row.unit).frame(minWidth: 42, idealWidth: 48, maxWidth: size.isAccessibilitySize ? .infinity : 65).focused(focus, equals: .unit(row.id)).submitLabel(.next).onSubmit { focus.wrappedValue = .ingredient(row.id) }.accessibilityLabel("Ingredient unit, for example cup or g")
        }.font(.body.weight(.semibold)).padding(.vertical, 10)
    }
    private var name: some View {
        TextField("Ingredient", text: $row.name).focused(focus, equals: .ingredient(row.id)).submitLabel(.next).onSubmit(next).padding(.vertical, 10).accessibilityIdentifier("recipe-ingredient-name")
    }
}
private struct RecipeRowActions: View {
    let label: String
    let canUp: Bool
    let canDown: Bool
    let up: () -> Void
    let down: () -> Void
    let destinations: [(UUID,String)]
    let move: (UUID) -> Void
    let remove: () -> Void
    @State private var deleting = false
    var body: some View {
        Menu {
            Button("Move Up", systemImage: "arrow.up", action: up).disabled(!canUp)
            Button("Move Down", systemImage: "arrow.down", action: down).disabled(!canDown)
            if !destinations.isEmpty { Menu("Move to…") { ForEach(destinations, id: \.0) { id,name in Button(name) { move(id) } } } }
            Button("Delete", systemImage: "trash", role: .destructive) { deleting = true }
        } label: { Image(systemName: "line.3.horizontal").frame(width: 44, height: 44).contentShape(Rectangle()) }
            .accessibilityLabel(label).confirmationDialog("Delete this row?", isPresented: $deleting, titleVisibility: .visible) { Button("Delete Row", role: .destructive, action: remove) }
    }
}
private struct RecipeInlineAction: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(.body.weight(.medium)).frame(minHeight: 44).foregroundStyle(SGTheme.ColorToken.accent).opacity(configuration.isPressed ? 0.6 : 1) }
}
