import Foundation
import SwiftData

/// Dish and Recipe are two views of one Dish (FOOD_ARCHITECTURE §2). A Recipe made in Food
/// Bible takes its Dish identity immediately: the local Dish exists (and syncs) even before
/// its first cook. A Dish with no cooks never appears in Grub Rank.
@MainActor enum DishIdentityStore {
    /// Creates the local Dish for a Recipe's identity if it does not exist yet.
    @discardableResult
    static func ensureDish(id: UUID, for content: RecipeContent, context: ModelContext) throws -> Dish {
        if let existing = try context.fetch(FetchDescriptor<Dish>(predicate: #Predicate { $0.id == id })).first { return existing }
        let name = content.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseline = try SyncJournal.begin(context)
        do {
            let dish = Dish(name: name.isEmpty ? "Untitled Dish" : String(name.prefix(200)),
                            category: content.course.flatMap(DishCategory.init(rawValue:)) ?? .other, id: id)
            dish.cuisine = content.cuisine.flatMap { CuisineCatalog.resolve($0) }
            context.insert(dish)
            try SyncJournal.stage(baseline, kind: "createDish", context: context)
            try context.save()
            SyncJournal.didCommit(context)
            return dish
        } catch { context.rollback(); throw error }
    }

    /// Removes a Dish that only existed for its Recipe once that Recipe is 86'd.
    static func removeIfUncooked(id: UUID?, context: ModelContext) throws {
        guard let id, let dish = try context.fetch(FetchDescriptor<Dish>(predicate: #Predicate { $0.id == id })).first,
              dish.attempts.isEmpty else { return }
        let baseline = try SyncJournal.begin(context)
        do {
            context.delete(dish)
            try SyncJournal.stage(baseline, kind: "deleteDish", context: context)
            try context.save()
            SyncJournal.didCommit(context)
        } catch { context.rollback(); throw error }
    }
}
