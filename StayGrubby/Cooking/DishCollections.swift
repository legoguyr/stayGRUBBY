import Foundation
import SwiftData

/// Smart Collections (November 18, 2026; FOOD_ARCHITECTURE §11). A collection is an organizational label
/// on a Dish — "Risotto", "Holiday Cooking" — never a folder record and never an owner of Dishes:
/// - membership is `Dish.collections`; counts, photos and rankings are derived from existing Dish data;
/// - one Dish may be in several collections; a collection never creates, merges or copies a Dish, cook,
///   Recipe, photo or ranking row;
/// - labels sync with their Dish through the existing cooking outbox, written only when they change;
/// - collections never infer Recipe links or merge Dishes (course and cuisine stay separate metadata).
nonisolated enum DishCollectionPolicy {
    static let maximumPerDish = 20
    static let maximumLength = 40

    /// Trimmed, single-spaced, bounded and de-duplicated case/diacritic-insensitively (first spelling wins).
    static func normalized(_ labels: [String]) -> [String] {
        var seen = Set<String>(), result: [String] = []
        for label in labels {
            let display = String(TagNormalization.display(label).prefix(maximumLength)).trimmingCharacters(in: .whitespaces)
            guard !display.isEmpty, seen.insert(key(display)).inserted else { continue }
            result.append(display)
            if result.count == maximumPerDish { break }
        }
        return result
    }
    static func key(_ label: String) -> String {
        TagNormalization.display(label).folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
    static func valid(_ labels: [String]) -> Bool { labels == normalized(labels) }
}

@MainActor enum DishCollectionStore {
    /// Sets one Dish's collections. Writes (and syncs) only when membership actually changes.
    static func set(_ labels: [String], on dish: Dish, context: ModelContext) throws {
        let next = DishCollectionPolicy.normalized(labels)
        guard next != dish.collections else { return }
        try write(context) { dish.collections = next }
    }

    /// Renames a collection on every Dish in it, as one synced edit. Dish identity, Recipes and cooks are untouched.
    static func rename(_ label: String, to newLabel: String, dishes: [Dish], context: ModelContext) throws {
        let old = DishCollectionPolicy.key(label)
        guard let replacement = DishCollectionPolicy.normalized([newLabel]).first else { return }
        let members = dishes.filter { $0.collections.contains { DishCollectionPolicy.key($0) == old } }
        guard !members.isEmpty else { return }
        try write(context) {
            for dish in members {
                dish.collections = DishCollectionPolicy.normalized(dish.collections.map { DishCollectionPolicy.key($0) == old ? replacement : $0 })
            }
        }
    }

    /// Removes a collection: only the label goes; every Dish, cook and Recipe stays.
    static func remove(_ label: String, dishes: [Dish], context: ModelContext) throws {
        let old = DishCollectionPolicy.key(label)
        let members = dishes.filter { $0.collections.contains { DishCollectionPolicy.key($0) == old } }
        guard !members.isEmpty else { return }
        try write(context) { for dish in members { dish.collections.removeAll { DishCollectionPolicy.key($0) == old } } }
    }

    private static func write(_ context: ModelContext, _ change: () -> Void) throws {
        let baseline = try SyncJournal.begin(context)
        do {
            change()
            try SyncJournal.stage(baseline, kind: "editDish", context: context)
            try context.save(); SyncJournal.didCommit(context)
        } catch { context.rollback(); throw error }
    }
}

/// Read-only presentation derived from Dishes and the existing Grub Rank order. Makes no writes.
@MainActor struct DishCollectionSummary: Identifiable {
    /// One Dish in a collection, represented by its best-ranked eligible cook.
    struct Member: Identifiable {
        let dish: Dish
        /// The Dish's highest Grub Rank cook, if any cook is ranked.
        let best: CookingDiscovery.Entry?
        /// Displayable score of that cook, nil while scores are locked.
        let scoreText: String?
        var id: UUID { dish.id }
        var cookCount: Int { dish.attempts.count }
    }
    let label: String
    let members: [Member]
    var id: String { DishCollectionPolicy.key(label) }
    var cookCount: Int { members.reduce(0) { $0 + $1.cookCount } }
    var dishCountText: String { members.count == 1 ? "1 Dish" : "\(members.count) Dishes" }
    var cookCountText: String { cookCount == 1 ? "1 cook" : "\(cookCount) cooks" }

    /// Every collection, alphabetical. Members are in Grub Rank order of their best cook; unranked
    /// Dishes (Recipe only) follow by name. Ranks keep their global numbers.
    static func all(dishes: [Dish], entries: [CookingDiscovery.Entry], scores: ScoreUnlockState) -> [DishCollectionSummary] {
        var best: [UUID: CookingDiscovery.Entry] = [:]
        for entry in entries { if let id = entry.attempt.dish?.id, best[id] == nil { best[id] = entry } }
        var groups: [String: (label: String, dishes: [Dish])] = [:]
        for dish in dishes { for label in dish.collections { groups[DishCollectionPolicy.key(label), default: (label, [])].dishes.append(dish) } }
        return groups.values.map { group in
            let members = group.dishes.map { dish in
                Member(dish: dish, best: best[dish.id], scoreText: best[dish.id]?.attempt.rankedItem.flatMap { scores.scoreText($0.score) })
            }.sorted { a, b in
                switch (a.best?.globalRank, b.best?.globalRank) {
                case let (x?, y?): x < y
                case (.some, nil): true
                case (nil, .some): false
                default: a.dish.name.localizedStandardCompare(b.dish.name) == .orderedAscending
                }
            }
            return DishCollectionSummary(label: group.label, members: members)
        }.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    /// Existing labels for pickers, most used first.
    static func labels(in dishes: [Dish]) -> [String] {
        var counts: [String: (label: String, count: Int)] = [:]
        for dish in dishes { for label in dish.collections { counts[DishCollectionPolicy.key(label), default: (label, 0)].count += 1 } }
        return counts.values.sorted { ($1.count, $0.label) < ($0.count, $1.label) }.map(\.label)
    }
}
