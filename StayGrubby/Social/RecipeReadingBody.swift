import SwiftUI

/// Readable content shared with immutable cook snapshots. No timers, scaling or cooking-session state.
struct RecipeReadingBody: View {
    let content: RecipeContent
    @Environment(\.dynamicTypeSize) private var size
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            RecipeSummaryMetrics(content: content)
            if content.metadataOrigins?.values.contains("estimated") == true { Text("Servings and times may include estimates. Adjust for your kitchen.").font(.footnote).foregroundStyle(.secondary) }
            if let allergens = content.allergens {
                VStack(alignment: .leading, spacing: 8) {
                    if !allergens.contains.isEmpty { Text("Contains: " + allergens.contains.compactMap { Allergen(rawValue: $0)?.label }.joined(separator: ", ")).font(.subheadline) }
                    if !allergens.possible.isEmpty { Text("Possible: " + allergens.possible.compactMap { Allergen(rawValue: $0)?.label }.joined(separator: ", ")).font(.subheadline) }
                    Text(RecipeAllergenAssessment.safetyText).font(.footnote).foregroundStyle(.secondary)
                }.accessibilityIdentifier("recipe-allergen-information")
            }
            VStack(alignment: .leading, spacing: 20) {
                SGEyebrow(text: "Ingredients")
                ForEach(content.orderedComponents) { part in
                    VStack(alignment: .leading, spacing: 0) {
                        sectionTitle(part)
                        ForEach(part.ingredients) { ingredient in
                            ingredientRow(ingredient).padding(.vertical, 12)
                            Divider().accessibilityHidden(true)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 24) {
                SGEyebrow(text: "Method")
                ForEach(content.orderedComponents) { part in
                    VStack(alignment: .leading, spacing: 20) {
                        sectionTitle(part)
                        ForEach(Array(part.steps.enumerated()), id: \.element.id) { index, step in
                            HStack(alignment: .firstTextBaseline, spacing: 16) {
                                Text("\(offset(part.id)+index+1)").font(.title2.bold()).foregroundStyle(SGTheme.ColorToken.accent).frame(minWidth: 25, alignment: .leading)
                                Text(step.instruction).font(.body).lineSpacing(7).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                            }.accessibilityElement(children: .combine).accessibilityLabel("Step \(offset(part.id)+index+1). \(step.instruction)")
                        }
                    }
                }
            }
            if let tips = content.tips, !tips.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SGEyebrow(text: "Recipe tips")
                    Text(tips).font(.body).lineSpacing(6).fixedSize(horizontal: false, vertical: true)
                }
            }
        }.accessibilityIdentifier("recipe-reading-body").textSelection(.enabled)
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
        }.padding(.vertical, 6)
    }
    private func metric(_ title: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 5) { Text(title.uppercased()).font(.caption.bold()).foregroundStyle(.secondary); Text(value).font(.body.weight(.semibold)) }.accessibilityElement(children: .combine) }
}
