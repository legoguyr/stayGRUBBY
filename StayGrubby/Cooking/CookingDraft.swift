import Foundation

@MainActor struct CookingDraft {
    var dishName = ""
    var cuisine: Cuisine?
    var category: DishCategory = .main
    var cookedAt: Date? = .now
    /// True when Diet/Contains were preselected from a Recipe as written; shown for confirmation.
    var prefilledFromRecipe = false
    var versionTitle = ""
    var notes = ""
    var publicDescription = ""
    private var descriptionAttemptID: UUID?
    private var preservesLegacyDescription = false
    private var initialPublicDescription = ""
    var shouldSavePublicDescription: Bool {
        // An untouched new Cook has no canonical text. Empty is reserved for an explicit
        // clear of existing text, and requires a server that can preserve that intent.
        if descriptionAttemptID == nil { return Self.optional(publicDescription) != nil }
        return !preservesLegacyDescription || publicDescription != initialPublicDescription
    }
    /// The draft may be reused after its first Save resolved legacy nil. A later clear
    /// must compare with that now-canonical Cook, not the draft's old nil baseline.
    func shouldSavePublicDescription(for attempt: CookingAttempt) -> Bool {
        if descriptionAttemptID == attempt.id, let current = attempt.publicDescription {
            return CookDescriptionPolicy.normalized(publicDescription) != current
        }
        return shouldSavePublicDescription
    }
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
    /// The Dish's Smart Collections; nil leaves them unchanged (new Dish without a choice, or gate off).
    var collections: [String]? = nil

    init() {}
    init(dish: Dish) {
        dishName = dish.name; category = dish.defaultCategory; cuisine = dish.cuisine
        // A new cook starts independently; Dish text is legacy food-level context.
        publicDescription = ""; privateNotes = dish.privateNotes ?? ""
        source = dish.source.map(DishSourceDraft.init(source:))
        collections = dish.collections
    }
    init(attempt: CookingAttempt) {
        dishName = attempt.dish?.name ?? attempt.rankedItem?.name ?? ""
        cuisine = attempt.dish?.cuisine
        category = attempt.category; cookedAt = attempt.cookedAt
        versionTitle = attempt.versionTitle ?? ""; notes = attempt.notes ?? ""
        dietary = attempt.dietaryTags; allergy = attempt.allergyTags; contains = attempt.containedAllergens; customTags = attempt.customTags
        source = attempt.dish?.source.map(DishSourceDraft.init(source:))
        publicDescription = attempt.publicDescription ?? attempt.dish?.publicDescription ?? ""
        descriptionAttemptID = attempt.id
        initialPublicDescription = publicDescription; preservesLegacyDescription = attempt.publicDescription == nil
        privateNotes = attempt.dish?.privateNotes ?? ""
        existingPhoto = attempt.primaryImage; existingPhotoCount = attempt.orderedImages.count
        collections = attempt.dish?.collections
    }
    /// Displaying legacy evidence must not count as an owner edit on an unrelated Save.
    mutating func useLegacyDescriptionContext(_ value: CookDescriptionContext) {
        guard preservesLegacyDescription, value.attemptID == descriptionAttemptID, value.publicDescription == nil else { return }
        publicDescription = value.effectiveDescription ?? ""
        initialPublicDescription = publicDescription
    }
    var validForRanking: Bool { !cleanDishName.isEmpty && cookedAt != nil && validDishText }
    var hasPhoto: Bool { pendingPhoto != nil || (existingPhoto != nil && !removeExistingPhoto) }
    var validDishText: Bool { DishTextPolicy.valid(description: publicDescription, notes: privateNotes) && CookDescriptionPolicy.valid(publicDescription) }
    var cleanDishName: String { dishName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var cleanTitle: String? { CookName.normalized(versionTitle) }
    static func optional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
