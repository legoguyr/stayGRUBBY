import SwiftUI
import UIKit

enum RecipeOrderingKind: String, Identifiable { case ingredients, steps; var id: String { rawValue } }

/// Native row reordering lives outside the nested text-field ScrollView. No
/// text editing, deletion, external drops or copying is possible in this sheet.
struct RecipeOrderingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var content: RecipeContent
    let kind: RecipeOrderingKind
    var body: some View {
        NavigationStack {
            RecipeOrderingTable(content: $content, kind: kind)
                .navigationTitle(kind == .ingredients ? "Reorder ingredients" : "Reorder steps")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("recipe-order-done")
                } }
        }.presentationDragIndicator(.visible)
    }
}

private struct RecipeOrderingTable: UIViewControllerRepresentable {
    @Binding var content: RecipeContent
    let kind: RecipeOrderingKind
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UITableViewController {
        let controller = UITableViewController(style: .insetGrouped)
        controller.tableView.dataSource = context.coordinator
        controller.tableView.delegate = context.coordinator
        controller.tableView.allowsSelection = false
        controller.tableView.accessibilityIdentifier = "recipe-order-table"
        controller.tableView.rowHeight = UITableView.automaticDimension
        controller.tableView.estimatedRowHeight = 66
        controller.setEditing(true, animated: false)
        return controller
    }
    func updateUIViewController(_ controller: UITableViewController, context: Context) {
        context.coordinator.parent = self
        let next = content.orderedComponents
        if context.coordinator.parts != next {
            context.coordinator.parts = next
            controller.tableView.reloadData()
        }
    }
    final class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
        var parent: RecipeOrderingTable
        var parts: [RecipeComponent]
        init(_ parent: RecipeOrderingTable) { self.parent = parent; parts = parent.content.orderedComponents }
        func numberOfSections(in tableView: UITableView) -> Int { parts.count }
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { parent.kind == .ingredients ? parts[section].ingredients.count : parts[section].steps.count }
        func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { parts.count > 1 ? parts[section].title ?? "Section" : nil }
        func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { section == parts.count-1 ? "Drag a handle to change the order or move a row to another section. Changes are saved only when you Save the recipe." : nil }
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            let p = parts[indexPath.section]
            let id = parent.kind == .ingredients ? p.ingredients[indexPath.row].id : p.steps[indexPath.row].id
            let text = parent.kind == .ingredients ? p.ingredients[indexPath.row].displayText : p.steps[indexPath.row].instruction
            var configuration = cell.defaultContentConfiguration()
            configuration.text = text
            configuration.textProperties.numberOfLines = 0
            configuration.textProperties.font = .preferredFont(forTextStyle: .body)
            configuration.textProperties.adjustsFontForContentSizeCategory = true
            cell.contentConfiguration = configuration
            cell.showsReorderControl = true
            cell.accessibilityIdentifier = "recipe-order-row-\(id)"
            cell.accessibilityLabel = text
            cell.accessibilityValue = p.title ?? "Recipe"
            return cell
        }
        func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool { true }
        func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle { .none }
        func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool { false }
        func tableView(_ tableView: UITableView, moveRowAt source: IndexPath, to destination: IndexPath) {
            let p = parts[source.section]
            let id = parent.kind == .ingredients ? p.ingredients[source.row].id : p.steps[source.row].id
            var value = parent.content
            value.moveRecipeRow(id, from: p.id, to: parts[destination.section].id, ingredient: parent.kind == .ingredients, at: destination.row)
            // UIKit has already performed the visual move. Keep its snapshot in
            // sync before publishing, avoiding a reload while the finger lifts.
            parts = value.orderedComponents
            parent.content = value
        }
    }
}
