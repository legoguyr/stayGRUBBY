import SwiftUI

/// Readable content shared with immutable cook snapshots. No timers, scaling or cooking-session state.
struct RecipeReadingBody: View {
    let content: RecipeContent
    @Environment(\.dynamicTypeSize) private var size
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            RecipeSummaryMetrics(content: content)
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
        let amount = [row.quantity,row.unit].filter { !$0.isEmpty }.joined(separator: " ")
        return Group {
            if size.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) { if !amount.isEmpty { Text(amount).font(.body.bold()) }; ingredientName(row) }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 16) { if !amount.isEmpty { Text(amount).font(.body.bold()).frame(width: 88, alignment: .leading).fixedSize(horizontal: false, vertical: true) }; ingredientName(row).frame(maxWidth: .infinity, alignment: .leading) }
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel(row.displayText)
    }
    private func ingredientName(_ row: RecipeIngredient) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.name).font(.body).fixedSize(horizontal: false, vertical: true)
            if !row.preparation.isEmpty { Text(row.preparation).font(.subheadline).foregroundStyle(.secondary) }
            if !row.note.isEmpty { Text(row.note).font(.subheadline).foregroundStyle(.secondary) }
        }
    }
    private func offset(_ id: UUID) -> Int { content.orderedComponents.prefix { $0.id != id }.reduce(0) { $0+$1.steps.count } }
}
struct RecipeSummaryMetrics: View {
    let content: RecipeContent
    @Environment(\.dynamicTypeSize) private var size
    var body: some View {
        LazyVGrid(columns: size.isAccessibilitySize ? [GridItem(.flexible(), alignment: .leading)] : [GridItem(.adaptive(minimum: 100), alignment: .leading)], alignment: .leading, spacing: 18) {
            if let yield = content.yield, !yield.isEmpty { metric("Serves", yield) }
            if let prep = content.prepMinutes { metric("Prep", "\(prep) min") }
            if let cook = content.cookMinutes { metric("Cook", "\(cook) min") }
            if let total = content.totalMinutes { metric("Total", "\(total) min") }
        }.padding(.vertical, 6)
    }
    private func metric(_ title: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 5) { Text(title.uppercased()).font(.caption.bold()).foregroundStyle(.secondary); Text(value).font(.body.weight(.semibold)) }.accessibilityElement(children: .combine) }
}
