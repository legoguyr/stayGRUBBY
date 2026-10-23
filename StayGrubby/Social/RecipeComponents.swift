import Foundation

/// Serializable manual/parsed draft contract. No provider, private cooking notes or ranking fields.
typealias RecipeDraft = RecipeContent

nonisolated struct RecipeIngredient: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var order = 0
    var quantity = ""
    var unit = ""
    var name = ""
    var preparation = ""
    var note = ""
    var displayText: String {
        let main = [quantity, unit, name].filter { !$0.isEmpty }.joined(separator: " ")
        return [main, preparation, note].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
nonisolated struct RecipeStep: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var order = 0
    var instruction = ""
}
nonisolated struct RecipeComponent: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var title: String? = nil
    var order = 0
    var ingredients: [RecipeIngredient] = []
    var steps: [RecipeStep] = []
}

extension RecipeContent {
    /// Old flat recipes remain untouched on disk/server until intentionally edited.
    /// Stable namespace IDs preserve identity on every legacy read; new rows use random UUIDs.
    nonisolated var orderedComponents: [RecipeComponent] {
        if let components { return components }
        func legacyID(_ kind: Int, _ index: Int) -> UUID {
            UUID(uuidString: String(format: "00000000-0000-4000-a%03d-%012d", kind, index))!
        }
        return [.init(id: legacyID(0, 0), ingredients: ingredients.enumerated().map {
            .init(id: legacyID(1, $0.offset), order: $0.offset, name: $0.element)
        }, steps: steps.enumerated().map {
            .init(id: legacyID(2, $0.offset), order: $0.offset, instruction: $0.element)
        })]
    }
    nonisolated var totalMinutes: Int? {
        guard prepMinutes != nil || cookMinutes != nil else { return nil }
        return (prepMinutes ?? 0) + (cookMinutes ?? 0)
    }
    /// Order is the array order, canonicalized at save; quantities remain exact user text (1 1/2, etc.).
    nonisolated func preparedForSave() -> RecipeContent {
        var copy = self
        copy.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.components = orderedComponents.enumerated().map { index, part in
            var part = part; part.order = index
            part.ingredients = part.ingredients.enumerated().map { index, row in var row = row; row.order = index; return row }
            part.steps = part.steps.enumerated().map { index, row in var row = row; row.order = index; return row }
            return part
        }
        copy.ingredients = copy.orderedComponents.flatMap(\.ingredients).map(\.displayText)
        copy.steps = copy.orderedComponents.flatMap(\.steps).map(\.instruction)
        return copy
    }
    nonisolated var isValidDraft: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 120 &&
        (1...20).contains(orderedComponents.count) && orderedComponents.allSatisfy { part in
            part.ingredients.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } &&
            part.steps.allSatisfy { !$0.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }
}

nonisolated struct CookbookEntry: Codable, Identifiable, Sendable {
    var dishID: UUID
    var recipeID: UUID
    var dishTitle: String
    var recipeTitle: String
    var course: String?
    var cuisine: String?
    var revision: Int
    var id: UUID { dishID }
}
nonisolated struct CookbookPage: Codable { var entries: [CookbookEntry] }
nonisolated struct DishRecipeResponse: Codable { var recipe: Recipe? }

extension RecipeIngredient {
    private enum CodingKeys: String, CodingKey { case id, order, quantity, unit, name, preparation, note }
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id); order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        quantity = try c.decodeIfPresent(String.self, forKey: .quantity) ?? ""
        unit = try c.decodeIfPresent(String.self, forKey: .unit) ?? ""
        name = try c.decode(String.self, forKey: .name)
        preparation = try c.decodeIfPresent(String.self, forKey: .preparation) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}
