import Foundation
import SwiftData

@Model
final class CookingAttempt {
    @Attribute(.unique) var id: UUID
    /// A unique bridge key enforces one cooking attempt per generic ranking item.
    @Attribute(.unique) var rankedItemID: UUID
    var dish: Dish?
    @Relationship(deleteRule: .nullify) var rankedItem: RankedItem?
    /// Nil means unknown, used for legacy items; creation time is not a cooking date.
    var cookedAt: Date?
    var versionTitle: String?
    var notes: String?
    var categoryCode: String
    var sequenceNumber: Int
    var createdAt: Date
    var updatedAt: Date
    var isLegacyImport: Bool
    @Relationship(deleteRule: .nullify) var tags: [CookingTag] = []
    @Relationship(deleteRule: .cascade, inverse: \CookingMedia.attempt) var media: [CookingMedia] = []

    var category: DishCategory {
        get { DishCategory(rawValue: categoryCode) ?? .other }
        set { categoryCode = newValue.rawValue }
    }
    /// The cook's name with its "Version N" fallback always shown (`CookName`).
    var versionLabel: String { CookName.name(custom: versionTitle, sequence: sequenceNumber) }
    /// Presentation only; stored sequence/title and historical snapshots stay unchanged.
    /// A lone unnamed cook has no label (`CookName.label`).
    var meaningfulVersionLabel: String? {
        CookName.label(custom: versionTitle, sequence: sequenceNumber, siblingCount: dish?.attempts.count ?? 1)
    }
    var displayName: String { [dish?.name ?? rankedItem?.name ?? "Dish", meaningfulVersionLabel].compactMap { $0 }.joined(separator: " — ") }
    var dietaryTags: Set<DietaryTag> { Set(tags.filter { $0.kindCode == CookingTagKind.dietary.rawValue }.compactMap { DietaryTag(rawValue: $0.value) }) }
    var allergyTags: Set<AllergyTag> { Set(tags.filter { $0.kindCode == CookingTagKind.allergy.rawValue }.compactMap { AllergyTag(rawValue: $0.value) }) }
    var containedAllergens: Set<Allergen> { Set(tags.filter { $0.kindCode == CookingTagKind.contains.rawValue }.compactMap { Allergen(rawValue: $0.value) }) }
    var customTags: [String] { tags.filter { $0.kindCode == CookingTagKind.custom.rawValue }.map(\.label).sorted() }
    var orderedImages: [CookingMedia] { CookingPhotoPolicy.ordered(media) }
    var primaryImage: CookingMedia? { orderedImages.first }

    init(item: RankedItem, sequence: Int, category: DishCategory, cookedAt: Date?, legacy: Bool = false, id: UUID = UUID()) {
        self.id = id; rankedItemID = item.id; rankedItem = item
        sequenceNumber = sequence; categoryCode = category.rawValue; self.cookedAt = cookedAt
        createdAt = item.createdAt; updatedAt = .now; isLegacyImport = legacy
    }
}
