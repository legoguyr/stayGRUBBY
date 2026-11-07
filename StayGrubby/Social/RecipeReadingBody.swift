import SwiftUI

/// Readable content shared with immutable cook snapshots; optional scaling is a value-only projection.
struct RecipeReadingBody: View {
    let content: RecipeContent
    var allowScaling = false
    @State private var servings: Int?
    @State private var units = RecipeUnitMode.original
    private var displayed: RecipeContent { RecipeUnits.content(content, mode: RecipeUnits.showsControl ? units : .original, servings: allowScaling ? servings : nil) }
    @Environment(\.dynamicTypeSize) private var size
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.xLarge) {
            if RecipeUnits.showsControl || (allowScaling && RecipeScaling.canonicalServings(content.yield) != nil) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: SGTheme.Space.medium) { servingControl; if RecipeUnits.showsControl { unitControl } }
                    VStack(alignment: .leading, spacing: SGTheme.Space.small) { servingControl; if RecipeUnits.showsControl { unitControl } }
                }
            }
            RecipeSummaryMetrics(content: displayed)
            VStack(alignment: .leading, spacing: SGTheme.Space.group) {
                SGEyebrow(text: "Ingredients")
                ForEach(displayed.orderedComponents) { part in
                    VStack(alignment: .leading, spacing: 0) {
                        sectionTitle(part)
                        ForEach(part.ingredients) { ingredient in
                            ingredientRow(ingredient).padding(.vertical, SGTheme.Space.stack)
                            Divider().accessibilityHidden(true)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: SGTheme.Space.large) {
                SGEyebrow(text: "Method").accessibilityIdentifier("recipe-method-heading")
                ForEach(displayed.orderedComponents) { part in
                    VStack(alignment: .leading, spacing: SGTheme.Space.group) {
                        sectionTitle(part)
                        ForEach(Array(part.steps.enumerated()), id: \.element.id) { index, step in
                            HStack(alignment: .firstTextBaseline, spacing: SGTheme.Space.medium) {
                                Text("\(offset(part.id)+index+1)").font(.title2.bold()).foregroundStyle(SGTheme.ColorToken.accent).frame(minWidth: 25, alignment: .leading)
                                Text(step.instruction).font(.body).lineSpacing(7).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                            }.accessibilityElement(children: .combine).accessibilityLabel("Step \(offset(part.id)+index+1). \(step.instruction)")
                        }
                    }
                }
            }
            if let tips = content.tips, !tips.isEmpty {
                VStack(alignment: .leading, spacing: SGTheme.Space.stack) {
                    SGEyebrow(text: "Recipe tips")
                    Text(tips).font(.body).lineSpacing(6).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let allergens = content.allergens, !allergens.contains.isEmpty || !allergens.possible.isEmpty {
                VStack(alignment: .leading, spacing: SGTheme.Space.compact) {
                    if !allergens.contains.isEmpty { Text("Contains: " + allergens.contains.compactMap { Allergen(rawValue: $0)?.label }.joined(separator: ", ")) }
                    if !allergens.possible.isEmpty { Text("Possible: " + allergens.possible.compactMap { Allergen(rawValue: $0)?.label }.joined(separator: ", ")) }
                    DisclosureGroup("Allergen safety") { Text(RecipeAllergenAssessment.safetyText).font(.footnote).foregroundStyle(.secondary) }
                }.font(.subheadline).accessibilityIdentifier("recipe-allergen-information")
            }
        }.textSelection(.enabled)
    }
    @ViewBuilder private var servingControl: some View {
        if allowScaling, let base = RecipeScaling.canonicalServings(content.yield) {
            Stepper(value: Binding(get: { servings ?? base }, set: { servings = $0 }), in: 1...100) { Text("Servings: \(servings ?? base)") }.accessibilityIdentifier("recipe-servings")
            if let servings, servings != base { Button("Reset Servings") { self.servings = nil } }
        }
    }
    private var unitControl: some View {
        Menu { Picker("Units", selection: $units) { ForEach(RecipeUnitMode.allCases) { Text($0.rawValue).tag($0) } } }
            label: { SGBrowseControlLabel(title: units == .original ? "Units" : units.rawValue, symbol: "arrow.left.arrow.right", active: units != .original) }
            .accessibilityLabel("Units, \(units.rawValue)").accessibilityIdentifier("recipe-units")
    }
    @ViewBuilder private func sectionTitle(_ part: RecipeComponent) -> some View {
        if content.orderedComponents.count > 1 { Text(part.title?.isEmpty == false ? part.title! : "Untitled section").font(.title3.bold()).accessibilityAddTraits(.isHeader).padding(.top, 4) }
    }
    private func ingredientRow(_ row: RecipeIngredient) -> some View {
        RecipeIngredientLabel(row: row).accessibilityElement(children: .ignore).accessibilityLabel(IngredientLineFormatter.accessibilityLine(row))
    }
    private func offset(_ id: UUID) -> Int { content.orderedComponents.prefix { $0.id != id }.reduce(0) { $0+$1.steps.count } }
}
struct RecipeSummaryMetrics: View {
    let content: RecipeContent
    @Environment(\.dynamicTypeSize) private var size
    var body: some View {
        LazyVGrid(columns: size.isAccessibilitySize ? [GridItem(.flexible(), alignment: .leading)] : [GridItem(.adaptive(minimum: 100), alignment: .leading)], alignment: .leading, spacing: 18) {
            if let yield = content.yield, !yield.isEmpty { metric("Yield", yield) }
            if let prep = content.prepMinutes { metric("Prep", "\(prep) min") }
            if let cook = content.cookMinutes { metric("Cook", "\(cook) min") }
            if let total = content.totalMinutes { metric("Total", "\(total) min") }
        }.padding(.vertical, SGTheme.Space.xSmall)
    }
    private func metric(_ title: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 5) { Text(title.uppercased()).font(.caption.bold()).foregroundStyle(.secondary); Text(value).font(.body.weight(.semibold)) }.accessibilityElement(children: .combine) }
}
