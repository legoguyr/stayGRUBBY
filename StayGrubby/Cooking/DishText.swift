import Foundation
import SwiftData

nonisolated enum DishTextPolicy {
    static let publicMaximum = 2_000
    static let privateMaximum = 8_000
    static func valid(description: String?, notes: String?) -> Bool {
        (description?.unicodeScalars.count ?? 0) <= publicMaximum && (notes?.unicodeScalars.count ?? 0) <= privateMaximum
            && description?.contains("\0") != true && notes?.contains("\0") != true
    }
}
extension CookingStore {
    /// Explicit Dish-level owner edit; no copying from private cook notes or existing posts.
    static func editDishText(_ dish: Dish, publicDescription: String, privateNotes: String, context: ModelContext) throws {
        let description = CookingDraft.optional(publicDescription), notes = CookingDraft.optional(privateNotes)
        guard DishTextPolicy.valid(description: description, notes: notes) else { throw StoreError.invalidDraft }
        let baseline = try SyncJournal.begin(context)
        do {
            dish.publicDescription = description; dish.privateNotes = notes
            try SyncJournal.stage(baseline, kind: "editDish", context: context)
            try context.save(); SyncJournal.didCommit(context)
        } catch { context.rollback(); throw error }
    }
}
