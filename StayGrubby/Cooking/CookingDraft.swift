import Foundation

@MainActor struct CookingDraft {
    var dishName = ""
    var cuisine: Cuisine?
    var category: DishCategory = .main
    var cookedAt: Date? = .now
    var versionTitle = ""
    var notes = ""
    var publicDescription = ""
    var privateNotes = ""
    var existingPhotoCount = 0
    var dietary: Set<DietaryTag> = []
    // Compatibility only: restore and preserve legacy Free claims when editing.
    var allergy: Set<AllergyTag> = []
    var contains: Set<Allergen> = []
    var customTags: [String] = []
    var source: DishSourceDraft?
    var existingPhoto: CookingMedia?
    var pendingPhoto: PreparedCookingPhoto?
    var removeExistingPhoto = false

    init() {}
    init(dish: Dish) {
        dishName = dish.name; category = dish.defaultCategory; cuisine = dish.cuisine
        publicDescription = dish.publicDescription ?? ""; privateNotes = dish.privateNotes ?? ""
        source = dish.source.map(DishSourceDraft.init(source:))
    }
    init(attempt: CookingAttempt) {
        dishName = attempt.dish?.name ?? attempt.rankedItem?.name ?? ""
        cuisine = attempt.dish?.cuisine
        category = attempt.category; cookedAt = attempt.cookedAt
        versionTitle = attempt.versionTitle ?? ""; notes = attempt.notes ?? ""
        dietary = attempt.dietaryTags; allergy = attempt.allergyTags; contains = attempt.containedAllergens; customTags = attempt.customTags
        source = attempt.dish?.source.map(DishSourceDraft.init(source:))
        publicDescription = attempt.dish?.publicDescription ?? ""; privateNotes = attempt.dish?.privateNotes ?? ""
        existingPhoto = attempt.primaryImage; existingPhotoCount = attempt.orderedImages.count
    }
    var hasPhoto: Bool { pendingPhoto != nil || (existingPhoto != nil && !removeExistingPhoto) }
    var validDishText: Bool { DishTextPolicy.valid(description: publicDescription, notes: privateNotes) }
    var cleanDishName: String { dishName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var cleanTitle: String? { Self.optional(versionTitle) }
    static func optional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
