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

    /// One canonical Dish (FOOD_ARCHITECTURE §3.4): combines `source` into `target` when the user
    /// says they are the same real-world Dish (Use a Food Bible Recipe on a ranked Dish). Lossless:
    /// - cooks move with their IDs, ranked items, comparisons, photos, tags, notes and Recipe
    ///   provenance intact (all evidence keys on cook / ranked-item / Recipe IDs, never the Dish);
    ///   they get the next free sequence numbers on `target`, so only fallback labels change;
    /// - Dish-level text fills empty target fields; conflicting Private Notes are appended, and a
    ///   conflicting Source is kept as a note, so nothing the user wrote is dropped;
    /// - `source` is then deleted (synced tombstone). Ranking order and scores never change.
    static func combine(_ source: Dish, into target: Dish, context: ModelContext) throws {
        guard source.id != target.id else { return }
        let baseline = try SyncJournal.begin(context)
        do {
            let moving = source.attempts.sorted { ($0.cookedAt ?? $0.createdAt, $0.sequenceNumber, $0.id.uuidString) < ($1.cookedAt ?? $1.createdAt, $1.sequenceNumber, $1.id.uuidString) }
            var next = (target.attempts.map(\.sequenceNumber).max() ?? 0) + 1
            for cook in moving {
                source.attempts.removeAll { $0.id == cook.id }
                cook.dish = target; target.attempts.append(cook)
                cook.sequenceNumber = next; next += 1; cook.updatedAt = .now
            }
            if target.publicDescription == nil { target.publicDescription = source.publicDescription }
            target.privateNotes = mergedNotes(target.privateNotes, source.privateNotes, sourceLabel: source.source?.summary, keepsSource: target.source != nil)
            if target.cuisine == nil { target.cuisine = source.cuisine }
            if target.source == nil, let moved = source.source {
                source.source = nil; moved.dish = target; target.source = moved; moved.updatedAt = .now
            }
            for cook in target.attempts { cook.rankedItem?.name = cook.displayName }
            context.delete(source)
            try SyncJournal.stage(baseline, kind: "combineDishes", context: context)
            try context.save()
            SyncJournal.didCommit(context)
        } catch { context.rollback(); throw error }
    }

    /// Target notes first; the combined Dish's notes and (when both had one) its Source follow.
    nonisolated static func mergedNotes(_ target: String?, _ source: String?, sourceLabel: String?, keepsSource: Bool) -> String? {
        var parts = [target, source].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if keepsSource, let sourceLabel, !sourceLabel.isEmpty { parts.append("Also from: \(sourceLabel)") }
        guard !parts.isEmpty else { return nil }
        var seen = Set<String>(); parts = parts.filter { seen.insert($0).inserted }
        let joined = parts.joined(separator: "\n\n")
        return String(String.UnicodeScalarView(joined.unicodeScalars.prefix(DishTextPolicy.privateMaximum)))
    }
}
