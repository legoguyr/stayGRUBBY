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
        if let elapsedMinutes { return elapsedMinutes }
        if metadataOrigins != nil { return nil }
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
        [prepMinutes,cookMinutes,elapsedMinutes].compactMap { $0 }.allSatisfy { (0...10080).contains($0) } &&
        (elapsedMinutes == nil || elapsedMinutes! >= max(prepMinutes ?? 0,cookMinutes ?? 0)) &&
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
    var searchText: String? = nil
    var updatedAt: Double? = nil
    var yield: String? = nil
    var prepMinutes: Int? = nil
    var cookMinutes: Int? = nil
    var source: String? = nil
    var elapsedMinutes: Int? = nil
    var creatorMetadata: Bool? = nil
    var id: UUID { dishID }
    var searchableText: String { CookbookSearch.normalized([dishTitle, recipeTitle, cuisine, source, searchText].compactMap { $0 }.joined(separator: " ")) }
    var duration: Int? { if let elapsedMinutes { return elapsedMinutes }; if creatorMetadata == true { return nil }; return prepMinutes == nil && cookMinutes == nil ? nil : (prepMinutes ?? 0) + (cookMinutes ?? 0) }
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

/// Local, literal partial search. No keystroke requests, private notes, tags or AI inference.
nonisolated enum CookbookSearch {
    static func normalized(_ text: String) -> String { text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
    static func matches(_ text: String, query: String) -> Bool {
        normalized(query).split(whereSeparator: { $0.isWhitespace }).allSatisfy { normalized(text).contains($0) }
    }
    static func entries(_ values: [CookbookEntry], query: String, course: String, cuisine: String, alphabetical: Bool) -> [CookbookEntry] {
        values.filter { matches($0.searchableText, query: query) && (course.isEmpty || $0.course == course) && (cuisine.isEmpty || $0.cuisine == cuisine) }
            .sorted { a,b in
                if !alphabetical, a.updatedAt != b.updatedAt { return (a.updatedAt ?? 0) > (b.updatedAt ?? 0) }
                let result = a.dishTitle.localizedStandardCompare(b.dishTitle)
                return result == .orderedSame ? a.id.uuidString < b.id.uuidString : result == .orderedAscending
            }
    }
}
@MainActor enum CookbookIndex {
    static func load(request: SocialRequest) async throws -> [CookbookEntry] {
        var entries: [CookbookEntry] = [], seen = Set<UUID>(), cursor: UUID?
        repeat {
            try Task.checkCancellation()
            var payload = SocialPayload(); payload.beforeID = cursor
            let page = try JSONDecoder().decode(CookbookPage.self, from: await request("recipes", "cookbook_index", payload))
            let fresh = page.entries.filter { seen.insert($0.id).inserted }
            entries += fresh
            if page.entries.count < 50 || fresh.isEmpty { break }
            cursor = page.entries.last?.id
        } while cursor != nil
        return entries
    }
}

extension RecipeContent {
    /// Stable IDs survive section corrections; no string parsing or cooking mutations.
    nonisolated mutating func moveRecipeRow(_ id: UUID, from source: UUID, to destination: UUID, ingredient: Bool) {
        guard source != destination, let s = components?.firstIndex(where: { $0.id == source }), let d = components?.firstIndex(where: { $0.id == destination }) else { return }
        if ingredient {
            guard let i = components?[s].ingredients.firstIndex(where: { $0.id == id }), let row = components?[s].ingredients.remove(at: i) else { return }
            components?[d].ingredients.append(row)
        } else {
            guard let i = components?[s].steps.firstIndex(where: { $0.id == id }), let row = components?[s].steps.remove(at: i) else { return }
            components?[d].steps.append(row)
        }
    }
}
