import SwiftUI

/// One value draft; cancellation never mutates the saved Recipe or the private cooking graph.
struct RecipeEditor: View {
    @Environment(\.socialRequest) private var request
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe?
    var dishID: UUID?
    let onSave: (Recipe) -> Void
    @State private var content: RecipeDraft
    @State private var shared: Bool
    @State private var recipeID: UUID
    @State private var saving = false
    @State private var failed = false
    init(recipe: Recipe? = nil, dishID: UUID? = nil, title: String = "", course: String? = nil, cuisine: String? = nil, onSave: @escaping (Recipe) -> Void) {
        self.recipe = recipe; self.dishID = dishID; self.onSave = onSave
        var value = recipe?.content ?? RecipeContent(title: title, course: course, cuisine: cuisine)
        value.components = value.orderedComponents
        _content = State(initialValue: value); _shared = State(initialValue: recipe?.visibility == "friends")
        _recipeID = State(initialValue: recipe?.id ?? UUID())
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SGTheme.Space.large) {
                    SGPageIntro(title: recipe == nil ? "A recipe worth keeping." : "Keep the good details.", subtitle: "One recipe. As many components as your dish needs.")
                    SGFormSection(title: "Recipe") {
                        TextField("Recipe title", text: $content.title).accessibilityIdentifier("recipe-edit-title")
                        TextField("Introduction · optional", text: optional(\.description), axis: .vertical)
                        TextField("Servings / yield · optional", text: optional(\.yield)).accessibilityIdentifier("recipe-yield")
                        HStack {
                            TextField("Prep minutes", value: $content.prepMinutes, format: .number).keyboardType(.numberPad).accessibilityLabel("Preparation time in minutes")
                            TextField("Cook minutes", value: $content.cookMinutes, format: .number).keyboardType(.numberPad).accessibilityLabel("Cooking time in minutes")
                        }
                    }
                    ForEach(Array((content.components ?? []).enumerated()), id: \.element.id) { index, component in
                        RecipeComponentEditor(component: componentBinding(index), multiple: (content.components?.count ?? 0) > 1,
                            moveUp: { moveComponent(index, -1) }, moveDown: { moveComponent(index, 1) },
                            canUp: index > 0, canDown: index + 1 < (content.components?.count ?? 0),
                            remove: { content.components?.remove(at: index) },
                            moveIngredient: { id, destination in moveIngredient(id, from: index, to: destination) },
                            moveStep: { id, destination in moveStep(id, from: index, to: destination) },
                            destinations: (content.components ?? []).enumerated().filter { $0.offset != index }.map { ($0.offset, $0.element.title ?? "Component \($0.offset + 1)") })
                    }
                    Button("Add Component", systemImage: "plus.rectangle.on.rectangle") { content.components?.append(.init()) }
                        .buttonStyle(SGButtonStyle()).disabled((content.components?.count ?? 0) >= 20).accessibilityIdentifier("recipe-add-component")
                    SGFormSection(title: "Classification & attribution") {
                        Picker("Course", selection: optional(\.course)) { Text("None").tag(""); ForEach(DishCategory.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) } }
                        TextField("Cuisine · optional", text: optional(\.cuisine))
                        TextField("Original creator · optional", text: optional(\.originalCreator))
                        TextField("Source · optional", text: optional(\.source))
                        TextField("HTTPS source URL · optional", text: optional(\.externalURL)).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        Text("The original creator, who saved the recipe, and who inspired your cook stay separate.").font(.footnote).foregroundStyle(.secondary)
                    }
                    SGFormSection(title: "Recipe tips") {
                        TextField("Recipe tips · optional", text: optional(\.tips), axis: .vertical)
                        Text("Part of this recipe if you share it. Your Personal Notes on a cook always stay private.").font(.footnote).foregroundStyle(.secondary)
                    }
                    SGFormSection(title: "Privacy") {
                        Toggle("Share recipe with Sous Chefs", isOn: $shared).accessibilityIdentifier("recipe-sharing")
                        Text("Off keeps this recipe private. On shares only these recipe fields with current Sous Chefs, never your private cooking notes or photos.").font(.footnote)
                    }
                    if failed { Text("Couldn’t save. Your draft is still here. Check your connection and cooking sync. If edited elsewhere, cancel and reload before editing again.").accessibilityIdentifier("recipe-save-error") }
                }.padding(SGTheme.Space.medium).frame(maxWidth: SGTheme.Size.contentMaximum).frame(maxWidth: .infinity)
            }.accessibilityIdentifier("recipe-editor-scroll").background(SGTheme.ColorToken.background).scrollDismissesKeyboard(.interactively)
                .navigationTitle(recipe == nil ? "Add Recipe" : "Edit Recipe").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(saving || !content.isValidDraft).accessibilityIdentifier("recipe-save") }
                }
        }.interactiveDismissDisabled(saving)
    }
    private func componentBinding(_ index: Int) -> Binding<RecipeComponent> {
        Binding(get: { content.components?[safe: index] ?? .init() }, set: { if content.components?.indices.contains(index) == true { content.components?[index] = $0 } })
    }
    private func optional(_ path: WritableKeyPath<RecipeContent, String?>) -> Binding<String> {
        Binding(get: { content[keyPath: path] ?? "" }, set: { content[keyPath: path] = $0.isEmpty ? nil : $0 })
    }
    private func moveComponent(_ index: Int, _ delta: Int) { content.components?.swapAt(index, index + delta) }
    private func moveIngredient(_ id: UUID, from source: Int, to destination: Int) {
        guard let index = content.components?[source].ingredients.firstIndex(where: { $0.id == id }), let row = content.components?[source].ingredients.remove(at: index) else { return }
        content.components?[destination].ingredients.append(row)
    }
    private func moveStep(_ id: UUID, from source: Int, to destination: Int) {
        guard let index = content.components?[source].steps.firstIndex(where: { $0.id == id }), let row = content.components?[source].steps.remove(at: index) else { return }
        content.components?[destination].steps.append(row)
    }
    private func save() async {
        guard let request else { failed = true; return }; saving = true; failed = false; defer { saving = false }
        do {
            var payload = SocialPayload(); payload.recipeID = recipeID; payload.dishID = dishID
            payload.expectedRevision = recipe?.revision; payload.recipe = content.preparedForSave(); payload.visibility = shared ? "friends" : "private"
            let next = try JSONDecoder().decode(Recipe.self, from: await request("recipes", "save", payload))
            try Task.checkCancellation(); NotificationCenter.default.post(name: .socialContentChanged, object: nil); onSave(next); dismiss()
        } catch is CancellationError {} catch { failed = true }
    }
}

private struct RecipeComponentEditor: View {
    @Binding var component: RecipeComponent
    let multiple: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void
    let canUp: Bool
    let canDown: Bool
    let remove: () -> Void
    let moveIngredient: (UUID, Int) -> Void
    let moveStep: (UUID, Int) -> Void
    let destinations: [(Int, String)]
    @State private var deleting = false
    var body: some View {
        SGFormSection(title: multiple ? (component.title?.isEmpty == false ? component.title! : "Component") : "Ingredients & instructions") {
            if multiple {
                TextField("Component name · optional", text: Binding(get: { component.title ?? "" }, set: { component.title = $0.isEmpty ? nil : $0 }))
                HStack {
                    Button("Move component up", systemImage: "arrow.up", action: moveUp).disabled(!canUp)
                    Button("Move component down", systemImage: "arrow.down", action: moveDown).disabled(!canDown)
                    Button("Delete component", systemImage: "trash", role: .destructive) { deleting = true }
                }.labelStyle(.iconOnly).buttonStyle(RecipeReorderButtonStyle()).frame(minHeight: 44)
            }
            Text("Ingredients").font(SGTheme.TypeRole.headline).accessibilityAddTraits(.isHeader)
            ForEach($component.ingredients) { $row in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Quantity", text: $row.quantity).accessibilityLabel("Ingredient quantity")
                        TextField("Unit", text: $row.unit).accessibilityLabel("Ingredient unit, for example cup or g")
                    }
                    TextField("Ingredient", text: $row.name).accessibilityIdentifier("recipe-ingredient-name")
                    TextField("Preparation · optional", text: $row.preparation)
                    TextField("Note · optional", text: $row.note)
                    rowControls(id: row.id, ingredient: true)
                }.padding(.vertical, 8)
            }
            Button("Add Ingredient", systemImage: "plus") { component.ingredients.append(.init()) }.frame(minHeight: 44).accessibilityIdentifier("recipe-add-ingredient")
            Divider().padding(.vertical, 8)
            Text("Instructions").font(SGTheme.TypeRole.headline).accessibilityAddTraits(.isHeader)
            ForEach($component.steps) { $row in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Instruction", text: $row.instruction, axis: .vertical).accessibilityIdentifier("recipe-step-text")
                    rowControls(id: row.id, ingredient: false)
                }
            }
            Button("Add Step", systemImage: "plus") { component.steps.append(.init()) }.frame(minHeight: 44).accessibilityIdentifier("recipe-add-step")
        }.confirmationDialog("Delete this component and its ingredients and steps?", isPresented: $deleting, titleVisibility: .visible) { Button("Delete Component", role: .destructive, action: remove) }
    }
    private func rowControls(id: UUID, ingredient: Bool) -> some View {
        let ids = ingredient ? component.ingredients.map(\.id) : component.steps.map(\.id)
        let index = ids.firstIndex(of: id) ?? 0
        return HStack {
            Button("Move \(ingredient ? "ingredient" : "step") up", systemImage: "arrow.up") { if ingredient { component.ingredients.swapAt(index, index - 1) } else { component.steps.swapAt(index, index - 1) } }.disabled(index == 0)
            Button("Move \(ingredient ? "ingredient" : "step") down", systemImage: "arrow.down") { if ingredient { component.ingredients.swapAt(index, index + 1) } else { component.steps.swapAt(index, index + 1) } }.disabled(index + 1 == ids.count)
            if !destinations.isEmpty {
                Menu("Move to component", systemImage: "arrow.turn.down.right") {
                    ForEach(destinations, id: \.0) { destination, title in Button(title) { if ingredient { moveIngredient(id, destination) } else { moveStep(id, destination) } } }
                }
            }
            Spacer()
            Button("Delete \(ingredient ? "ingredient" : "step")", systemImage: "trash", role: .destructive) { if ingredient { component.ingredients.removeAll { $0.id == id } } else { component.steps.removeAll { $0.id == id } } }
        }.labelStyle(.iconOnly).buttonStyle(RecipeReorderButtonStyle()).frame(minHeight: 44)
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}

private struct RecipeReorderButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            .foregroundStyle(enabled ? SGTheme.ColorToken.accent : .secondary.opacity(0.4))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
