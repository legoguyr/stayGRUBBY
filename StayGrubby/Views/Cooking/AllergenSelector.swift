import SwiftUI

/// The same presence vocabulary serves metadata entry and discovery exclusion.
struct SGAllergenChoices: View {
    @Binding var selection: Set<Allergen>
    let identifierPrefix: String
    var body: some View {
        ForEach(CookingProductOptions.allergens) { allergen in
            SGSelectionRow(title: allergen.label, selected: selection.contains(allergen)) {
                if selection.contains(allergen) { selection.remove(allergen) }
                else { selection.insert(allergen) }
            }.accessibilityIdentifier("\(identifierPrefix)-\(allergen.rawValue)")
        }
    }
}

struct ContainsSelector: View {
    @Binding var selection: Set<Allergen>
    var body: some View {
        SGAllergenSelector(selection: $selection, title: "Contains", identifierPrefix: "contains", help: "Mark ingredients this cook contains. These are your own labels, not verified allergy information.")
    }
}

/// Shared, approved checkmark interaction. The caller owns the labels and data;
/// Recipe selections do not mutate cooking-attempt tags.
struct SGAllergenSelector: View {
    @Binding var selection: Set<Allergen>
    let title: String
    let identifierPrefix: String
    let help: String
    var body: some View {
        SGOptionSheet(title: title, doneIdentifier: "\(identifierPrefix)-done") {
            SGAllergenChoices(selection: $selection, identifierPrefix: identifierPrefix)
            SGOptionNote(help)
        }
    }
}
