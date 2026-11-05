import Foundation

nonisolated enum RecipeBrowseSort: String, CaseIterable, Identifiable {
    case updated = "Recently Updated", newest = "Newest Added", oldest = "Oldest Added", alphabetical = "A–Z", reverseAlphabetical = "Z–A"
    var id: String { rawValue }
}
nonisolated enum RecipeFilterGroup: String, CaseIterable, Identifiable {
    case course = "Course", cuisine = "Cuisine", contains = "Contains", avoid = "Avoid", source = "Source", photo = "Photo"
    var id: String { rawValue }
}
nonisolated struct RecipeFilters: Equatable {
    static let unspecified = "__unspecified__"
    var courses: Set<String> = [], cuisines: Set<String> = [], contains: Set<String> = [], avoid: Set<String> = [], sources: Set<String> = []
    var photo: Bool? = nil
    var count: Int { courses.count + cuisines.count + contains.count + avoid.count + sources.count + (photo == nil ? 0 : 1) }
    var isActive: Bool { count > 0 }
    func count(_ group: RecipeFilterGroup) -> Int {
        switch group { case .course: courses.count; case .cuisine: cuisines.count; case .contains: contains.count; case .avoid: avoid.count; case .source: sources.count; case .photo: photo == nil ? 0 : 1 }
    }
    func matches(_ entry: CookbookEntry) -> Bool {
        func match(_ values: Set<String>, _ field: String?) -> Bool { values.isEmpty || values.contains(field?.isEmpty == false ? field! : Self.unspecified) }
        guard match(courses,entry.course), match(cuisines,entry.cuisine), match(sources,entry.source) else { return false }
        let known = Set(entry.allergens?.contains ?? []), possible = Set(entry.allergens?.possible ?? [])
        return (contains.isEmpty || !known.isDisjoint(with: contains)) && known.union(possible).isDisjoint(with: avoid)
            && (photo == nil || (entry.photoID != nil) == photo)
    }
    func entries(_ entries: [CookbookEntry], query: String, sort: RecipeBrowseSort) -> [CookbookEntry] {
        entries.filter { matches($0) && CookbookSearch.matches($0.searchableText, query: query) }.sorted { a,b in
            if sort == .alphabetical || sort == .reverseAlphabetical {
                let result = a.recipeTitle.localizedStandardCompare(b.recipeTitle)
                if result != .orderedSame { return result == (sort == .alphabetical ? .orderedAscending : .orderedDescending) }
            } else {
                let x = sort == .updated ? a.updatedAt : a.createdAt, y = sort == .updated ? b.updatedAt : b.createdAt
                if x != y { guard let x else { return false }; guard let y else { return true }; return sort == .oldest ? x < y : x > y }
            }
            return a.id.uuidString < b.id.uuidString
        }
    }
}
