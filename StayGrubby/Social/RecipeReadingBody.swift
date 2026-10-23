import SwiftUI

/// Shared by the current reader and immutable cook snapshots; no live private notes are read.
struct RecipeReadingBody: View {
    let content: RecipeContent
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.large) {
            VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                if let yield = content.yield, !yield.isEmpty { Label(yield, systemImage: "person.2") }
                if let prep = content.prepMinutes { Text("Prep · \(prep) min") }
                if let cook = content.cookMinutes { Text("Cook · \(cook) min") }
                if let total = content.totalMinutes { Text("Total · \(total) min").font(.headline) }
                if let creator = content.originalCreator, !creator.isEmpty { Text("Original creator · \(creator)") }
            }.foregroundStyle(.secondary)
            ForEach(content.orderedComponents) { component in
                VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
                    if content.orderedComponents.count > 1, let title = component.title, !title.isEmpty {
                        Text(title).font(SGTheme.TypeRole.title).accessibilityAddTraits(.isHeader)
                    }
                    Text("Ingredients").font(SGTheme.TypeRole.headline).accessibilityAddTraits(.isHeader)
                    ForEach(component.ingredients) { ingredient in
                        Text(ingredient.displayText).font(SGTheme.TypeRole.reading).lineSpacing(6).fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Instructions").font(SGTheme.TypeRole.headline).padding(.top, SGTheme.Space.small).accessibilityAddTraits(.isHeader)
                    ForEach(Array(component.steps.enumerated()), id: \.element.id) { index, step in
                        Text("\(index + 1). \(step.instruction)").font(SGTheme.TypeRole.reading).lineSpacing(8).padding(.vertical, 4).fixedSize(horizontal: false, vertical: true)
                    }
                }.padding(.vertical, SGTheme.Space.small)
                if content.orderedComponents.count > 1 { Divider() }
            }
            if let tips = content.tips, !tips.isEmpty {
                Text("Recipe tips").font(SGTheme.TypeRole.headline).accessibilityAddTraits(.isHeader)
                Text(tips).font(SGTheme.TypeRole.reading).lineSpacing(6)
            }
        }.accessibilityIdentifier("recipe-reading-body")
    }
}
