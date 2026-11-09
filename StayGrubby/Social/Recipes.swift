import Foundation

/// Independent Recipe content; optional cooking associations never define its identity.
nonisolated struct RecipeContent: Codable, Equatable, Sendable {
    var title = ""
    var description: String? = nil
    var ingredients: [String] = []
    var steps: [String] = []
    var course: String? = nil
    var cuisine: String? = nil
    var source: String? = nil
    var externalURL: String? = nil
    var components: [RecipeComponent]? = nil
    var yield: String? = nil
    var prepMinutes: Int? = nil
    var cookMinutes: Int? = nil
    var elapsedMinutes: Int? = nil
    var metadataOrigins: [String:String]? = nil
    var allergens: RecipeAllergenAssessment? = nil
    var photoID: UUID? = nil
    var tips: String? = nil
    var originalCreator: String? = nil
    /// Diet as written (`DietaryTag` raw values: dairyFree, glutenFree, vegan, vegetarian).
    /// Author-selected only; never Certification. Kept so editing never drops it.
    var dietary: [String]? = nil
}
extension RecipeContent {
    /// Diet as written (never Certification); unknown codes are ignored.
    var dietTags: Set<DietaryTag> {
        get { Set((dietary ?? []).compactMap(DietaryTag.init(rawValue:))).intersection(CookingProductOptions.diets) }
        set {
            let codes = newValue.intersection(CookingProductOptions.diets).map(\.rawValue).sorted()
            dietary = codes.isEmpty ? nil : codes
        }
    }
}
nonisolated struct Recipe: Codable, Identifiable, Sendable {
    var id: UUID
    var isOwner: Bool
    var creator: SocialPerson?
    var content: RecipeContent
    var visibility: String
    var revision: Int
    var createdAt: Double
    var updatedAt: Double
    var saved: Bool
    var linkedDishID: UUID? = nil
    var linkedAttemptID: UUID? = nil
    /// The viewer's own Dish identity for this Recipe (Dish and Recipe are one Dish).
    var dishID: UUID? = nil
}
nonisolated struct RecipesPage: Codable { var recipes: [Recipe] }
nonisolated struct RecipeTicket: Codable, Identifiable { var id: UUID; var createdAt: Double; var recipe: Recipe? }
nonisolated struct TicketsPage: Codable { var tickets: [RecipeTicket] }
nonisolated struct RecipeCookSnapshot: Codable, Identifiable {
    var id: UUID
    var recipeID: UUID?
    var creatorName: String? = nil
    var snapshot: RecipeContent
    var revision: Int
}
nonisolated struct RecipeCooksPage: Codable { var cooks: [RecipeCookSnapshot] }

@MainActor enum RecipeService {
    static func recipe(_ action: String, id: UUID, request: SocialRequest) async throws -> Recipe {
        try JSONDecoder().decode(Recipe.self, from: await request("recipes", action, .init(recipeID: id)))
    }
    static func begin(id: UUID, reservation: UUID, request: SocialRequest) async throws -> SocialCookingClaim {
        try JSONDecoder().decode(SocialCookingClaim.self, from: await request("recipes", "begin", .init(originID: reservation, recipeID: id)))
    }
}
