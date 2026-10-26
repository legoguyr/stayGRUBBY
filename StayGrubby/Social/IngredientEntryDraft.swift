import Foundation

/// Editor-only original text. Never encoded into a Recipe or sent to a service.
nonisolated struct IngredientEntryDraft: Equatable {
    struct Line: Equatable {
        var raw: String
        var baselineText: String
        var baseline: RecipeIngredient
    }
    private(set) var lines: [UUID:Line] = [:]
    private(set) var bulkOriginals: [UUID:String] = [:]
    var editingID: UUID?
    var hasChanges: Bool { lines.values.contains { $0.raw != $0.baselineText } }
    mutating func begin(_ row: RecipeIngredient) {
        let text = lines[row.id]?.raw ?? IngredientLineFormatter.editableLine(row)
        lines[row.id] = Line(raw:text,baselineText:text,baseline:row)
        editingID = row.id
    }
    mutating func set(_ text: String, for row: RecipeIngredient) {
        if lines[row.id] == nil { begin(row) }
        guard editingID == row.id else { return }
        lines[row.id]?.raw = text
    }
    func text(for row: RecipeIngredient) -> String { lines[row.id]?.raw ?? IngredientLineFormatter.editableLine(row) }
    func resolved(_ row: RecipeIngredient) -> RecipeIngredient {
        guard let line = lines[row.id], line.raw != line.baselineText else { return row }
        return IngredientParser.parse(line.raw).ingredient(id:row.id,order:row.order)
    }
    mutating func forget(_ id: UUID) { lines[id] = nil; if editingID == id { editingID = nil } }
    /// Parse one Return or a multiline paste in-place; keep the existing first row ID.
    /// Empty Return reuses its placeholder. Additional lines stay in the same section.
    mutating func submit(_ id: UUID, in content: inout RecipeContent, advance: Bool) -> UUID? {
        guard editingID == id, let section = content.components?.firstIndex(where: { $0.ingredients.contains { $0.id == id } }),
              let index = content.components?[section].ingredients.firstIndex(where: { $0.id == id }),
              let row = content.components?[section].ingredients[index] else { return nil }
        let raw = text(for:row)
        let pieces = raw.components(separatedBy:.newlines).filter { !IngredientParser.trim($0).isEmpty }
        guard !pieces.isEmpty else {
            lines[id]?.raw = ""
            if !advance && lines[id]?.baseline.isBlank == true {
                content.components?[section].ingredients.remove(at:index); forget(id); return nil
            }
            editingID = id
            return advance ? id : nil
        }
        var parsed: [RecipeIngredient] = []
        for (offset,piece) in pieces.enumerated() {
            let next: RecipeIngredient
            if offset == 0 && pieces.count == 1 && lines[id]?.baselineText == raw { next = row }
            else { next = IngredientParser.parse(piece).ingredient(id:offset == 0 ? id : UUID(),order:index+offset) }
            parsed.append(next)
            lines[next.id] = Line(raw:piece,baselineText:piece,baseline:next)
        }
        content.components?[section].ingredients.replaceSubrange(index...index,with:parsed)
        editingID = nil
        guard advance else { return nil }
        // Reuse an immediately adjacent blank line instead of accumulating empties.
        let nextIndex = index+parsed.count
        if let rows = content.components?[section].ingredients, nextIndex < rows.count, rows[nextIndex].isBlank {
            begin(rows[nextIndex]); return rows[nextIndex].id
        }
        let blank = RecipeIngredient()
        content.components?[section].ingredients.insert(blank,at:nextIndex); begin(blank); return blank.id
    }
    mutating func appendBulk(_ raw: String, to sectionID: UUID, in content: inout RecipeContent) {
        guard let section = content.components?.firstIndex(where: { $0.id == sectionID }) else { return }
        for line in BulkIngredients.lines(raw) {
            let row = IngredientParser.parse(line.text).ingredient(id: UUID(), order: content.components![section].ingredients.count)
            content.components![section].ingredients.append(row)
            lines[row.id] = Line(raw: line.text, baselineText: line.text, baseline: row)
            bulkOriginals[row.id] = line.original
        }
    }
    func prepared(_ content: RecipeContent) -> RecipeContent {
        var copy = content
        copy.components = content.orderedComponents.map { section in
            var section = section
            section.ingredients = section.ingredients.compactMap { row in
                let next = resolved(row)
                // Only editor-created empty placeholders disappear. Clearing an existing
                // meaningful row remains a validation error until intentionally deleted.
                if next.isBlank && lines[row.id]?.baseline.isBlank == true { return nil }
                return next
            }
            return section
        }
        return copy.preparedForSave()
    }
    /// Validation does not repeatedly parse on every keystroke. Save resolves exact fields.
    func isValid(_ content: RecipeContent) -> Bool {
        var copy = content
        copy.components = content.orderedComponents.map { section in
            var section = section
            section.ingredients = section.ingredients.compactMap { row in
                guard let line = lines[row.id], line.raw != line.baselineText else { return row.isBlank && lines[row.id]?.baseline.isBlank == true ? nil : row }
                if IngredientParser.trim(line.raw).isEmpty && line.baseline.isBlank { return nil }
                var row = row; row.name = IngredientParser.trim(line.raw); return row
            }; return section
        }
        return copy.isValidDraft
    }
}
extension RecipeIngredient {
    nonisolated var isBlank: Bool { [quantity,unit,name,preparation,note].allSatisfy { IngredientParser.trim($0).isEmpty } }
}
