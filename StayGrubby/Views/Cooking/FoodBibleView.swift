import SwiftUI
import SwiftData

/// Derived from existing cooked Dishes and authorized Recipes; no separate library membership.
struct FoodBibleView: View {
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @Environment(\.dynamicTypeSize) private var textSize
    @Query private var dishes: [Dish]
    @State private var entries: [CookbookEntry] = []
    @State private var query = ""
    @State private var course = ""
    @State private var cuisine = ""
    @State private var alphabetical = false
    @State private var loading = true
    @State private var failed = false
    @State private var generation = UUID()
    @State private var choosing = false
    @State private var selected: CookbookRoute?
    @FocusState private var searching: Bool
    private var visible: [CookbookEntry] { CookbookSearch.entries(entries, query: query, course: course, cuisine: cuisine, alphabetical: alphabetical) }
    private var dishLookup: [UUID: Dish] { Dictionary(uniqueKeysWithValues: dishes.map { ($0.id,$0) }) }
    var body: some View {
        let lookup = dishLookup
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if loading && entries.isEmpty { ProgressView("Opening your cookbook").frame(maxWidth: .infinity) }
                if failed {
                    Label("Your cookbook needs a connection to refresh.", systemImage: "wifi.exclamationmark").font(.subheadline)
                    Button("Retry") { Task { await load() } }.buttonStyle(SGButtonStyle())
                }
                if !loading && visible.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: "book.closed").font(.system(size: 44, weight: .light)).foregroundStyle(SGTheme.ColorToken.accent).accessibilityHidden(true)
                        Text(entries.isEmpty ? "Your best recipes.\nAll in one place." : "Nothing on this page. Yet.").font(SGTheme.TypeRole.hero)
                        Text(entries.isEmpty ? "Keep the recipes for dishes you’ve cooked. Your photos, your little improvements, your Food Bible." : "Try another ingredient, dish or cuisine, or clear your filters.").foregroundStyle(.secondary)
                        Button(entries.isEmpty ? "Add Recipe" : "Clear search & filters") {
                            if entries.isEmpty { choosing = true } else { query = ""; course = ""; cuisine = "" }
                        }.buttonStyle(SGButtonStyle(prominent: true)).accessibilityIdentifier("bible-empty-add")
                    }.padding(.vertical, 32)
                }
                LazyVGrid(columns: textSize.isAccessibilitySize ? [GridItem(.flexible(minimum: 0), alignment: .top)] : [GridItem(.flexible(minimum: 0), alignment: .top), GridItem(.flexible(minimum: 0), alignment: .top)], alignment: .leading, spacing: 24) {
                    ForEach(visible) { entry in
                        Button { selected = .init(recipeID: entry.recipeID, dishID: entry.dishID) } label: {
                            CookbookCard(entry: entry, dish: lookup[entry.dishID])
                        }.buttonStyle(.plain).accessibilityIdentifier("bible-entry-\(entry.dishID)")
                    }
                }
                if !entries.isEmpty { Text("\(entries.count) recipes, made yours.").font(.footnote).foregroundStyle(.secondary) }
            }.padding(16).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.background(SGTheme.ColorToken.background).scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .top, spacing: 0) { searchHeader }
            .navigationTitle("Food Bible").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .primaryAction) { Button("Add Recipe", systemImage: "plus") { choosing = true }.accessibilityIdentifier("bible-add") } }
            .task { await load() }.refreshable { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
            .onChange(of: phase) { _, next in generation = UUID(); entries = []; if next == .active { Task { await load() } } }
            .sheet(isPresented: $choosing) { RecipeCreationChoice(entries: entries) }
            .navigationDestination(item: $selected) { route in RecipeDetailView(id: route.recipeID, dishID: route.dishID) }
    }
    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").accessibilityHidden(true)
                TextField("Dish, ingredient, cuisine…", text: $query).accessibilityLabel("Search your cookbook").accessibilityIdentifier("bible-search").focused($searching).submitLabel(.search).onSubmit { searching = false }
                if !query.isEmpty { Button("Clear search", systemImage: "xmark.circle.fill") { query = "" }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("bible-search-clear") }
            }.padding(.horizontal, 14).frame(minHeight: 48).background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: 14))
            HStack {
                Menu {
                    Picker("Course", selection: $course) { Text("All courses").tag(""); ForEach(DishCategory.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) } }
                    Picker("Cuisine", selection: $cuisine) { Text("All cuisines").tag(""); ForEach(Array(Set(entries.compactMap(\.cuisine))).sorted(), id: \.self) { Text($0).tag($0) } }
                } label: { Label(course.isEmpty && cuisine.isEmpty ? "All recipes" : "Filtered recipes", systemImage: "line.3.horizontal.decrease").frame(minHeight: 44) }.accessibilityIdentifier("bible-filters")
                Spacer()
                Menu { Picker("Sort recipes", selection: $alphabetical) { Text("Recently updated").tag(false); Text("A–Z").tag(true) } } label: { Label(alphabetical ? "A–Z" : "Recent", systemImage: "arrow.up.arrow.down").frame(minHeight: 44) }.accessibilityIdentifier("bible-sort")
            }.font(.subheadline).frame(minHeight: 44)
        }.padding(.horizontal, 16).padding(.top, 8).background(SGTheme.ColorToken.background)
    }
    private func load() async {
        guard let request else { failed = true; loading = false; return }
        let token = UUID(); generation = token; loading = true; failed = false
        defer { if generation == token { loading = false } }
        do { let next = try await CookbookIndex.load(request: request); guard !Task.isCancelled, generation == token else { return }; entries = next }
        catch is CancellationError {} catch { if generation == token { entries = []; failed = true } }
    }
}
private struct CookbookRoute: Hashable { let recipeID: UUID; let dishID: UUID }

struct CookbookPhoto: View {
    var dish: Dish?
    var name: String
    var compact = false
    var body: some View {
        if let media = dish?.cookbookRepresentativeCook?.primaryImage {
            DishPhoto(media: media, thumbnail: true, name: name)
        } else {
            ZStack {
                SGTheme.ColorToken.surface
                VStack(spacing: 10) {
                    Image(systemName: "fork.knife").font(.system(size: compact ? 23 : 32, weight: .ultraLight))
                    if !compact { Text("FROM YOUR KITCHEN").font(.system(.caption2, weight: .semibold)).tracking(1.2).lineLimit(2).multilineTextAlignment(.center) }
                }.foregroundStyle(SGTheme.ColorToken.accent).padding(8)
            }.accessibilityLabel("No photo for \(name)")
        }
    }
}
private struct CookbookCard: View {
    let entry: CookbookEntry
    var dish: Dish?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CookbookPhoto(dish: dish, name: entry.dishTitle).aspectRatio(0.9, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityHidden(true)
            Text(entry.recipeTitle).font(SGTheme.TypeRole.dish).foregroundStyle(SGTheme.ColorToken.primaryText).fixedSize(horizontal: false, vertical: true)
            Text([entry.cuisine, entry.duration.map { "\($0) min" } ?? entry.course.flatMap { DishCategory(rawValue: $0)?.label }].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .ignore).accessibilityLabel([entry.recipeTitle, entry.cuisine, entry.duration.map { "\($0) minutes" }].compactMap { $0 }.joined(separator: ", ")).accessibilityHint("Opens the recipe")
    }
}
struct CookedDishPicker: View {
    var entries: [CookbookEntry] = []
    var mode: RecipeCreationMode = .manual
    var onComplete: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Dish.name) private var dishes: [Dish]
    @State private var query = ""
    @State private var selected: Dish?
    private var eligible: [Dish] { dishes.filter { !$0.attempts.isEmpty && CookbookSearch.matches([$0.name,$0.cuisineLabel ?? "",$0.defaultCategory.label].joined(separator: " "), query: query) } }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("A recipe for something you’ve made.").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 12)
                ForEach(eligible) { dish in
                    Button { selected = dish } label: {
                        HStack(spacing: 14) {
                            CookbookPhoto(dish: dish, name: dish.name, compact: true).frame(width: 70, height: 78).clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(dish.name).font(.headline).foregroundStyle(SGTheme.ColorToken.primaryText)
                                Text([dish.cuisineLabel, dish.defaultCategory.label].compactMap { $0 }.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
                                Text(entries.contains { $0.dishID == dish.id } ? "View existing recipe" : "Add recipe").font(.caption).foregroundStyle(SGTheme.ColorToken.accent)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 12).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("choose-dish-\(dish.id)").accessibilityLabel(dish.name)
                    Divider()
                }
                if eligible.isEmpty { Text(query.isEmpty ? "Cook and rank a dish first, then keep its recipe here." : "No dishes match. Try a title, cuisine or course.").padding(.vertical, 24) }
            }.padding(.horizontal, 16)
        }.background(SGTheme.ColorToken.background).navigationTitle("Choose a Dish").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                HStack { Image(systemName: "magnifyingglass"); TextField("Search dishes, cuisine, course", text: $query).accessibilityIdentifier("choose-dish-search"); if !query.isEmpty { Button("Clear search", systemImage: "xmark.circle.fill") { query = "" }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44) } }.padding(14).background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: 12)).padding(16).background(SGTheme.ColorToken.background)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $selected) { dish in DishRecipeComposer(dish: dish, mode: mode) { if let onComplete { onComplete() } else { dismiss() } } }
    }
}
/// Resolve the authoritative current link once before creating; an existing Recipe opens directly.
private struct DishRecipeComposer: View {
    let dish: Dish
    var mode: RecipeCreationMode = .manual
    var done: () -> Void
    @Environment(\.socialRequest) private var request
    @State private var loaded = false
    @State private var recipe: Recipe?
    @State private var failed = false
    var body: some View {
        Group {
            if loaded {
                if let recipe { NavigationStack { RecipeDetailView(id: recipe.id, dishID: dish.id) } }
                else if mode == .imported { RecipeImportView(dish: dish, done: done) }
                else { RecipeEditor(dishID: dish.id, title: dish.name, course: dish.defaultCategoryCode, cuisine: dish.cuisineLabel) { _ in done() } }
            } else { VStack(spacing: 20) { if failed { Text("Couldn’t check this dish’s recipe."); Button("Retry") { Task { await load() } } } else { ProgressView("Opening recipe") } }.padding() }
        }.task { await load() }
    }
    private func load() async {
        guard let request else { failed = true; return }
        do { let response = try JSONDecoder().decode(DishRecipeResponse.self, from: await request("recipes", "dish", .init(dishID: dish.id))); try Task.checkCancellation(); recipe = response.recipe; loaded = true }
        catch is CancellationError {} catch { failed = true }
    }
}
struct DishRecipeDestination: View {
    let dish: Dish
    var onDone: (() -> Void)? = nil
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: SGTheme.Space.large) {
            Text(dish.name).font(SGTheme.TypeRole.hero)
            DishRecipeSection(dish: dish)
        }.padding(SGTheme.Space.medium) }.background(SGTheme.ColorToken.background).navigationTitle("Recipe")
            .toolbar { if let onDone { ToolbarItem(placement: .cancellationAction) { Button("Done", action: onDone) } } }
    }
}

struct DishRecipeSection: View {
    let dish: Dish
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @State private var recipe: Recipe?
    @State private var loaded = false
    @State private var failed = false
    @State private var creating = false
    @State private var selecting = false
    @State private var generation = UUID()
    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            SGSectionHeader(title: "Recipe")
            if let recipe {
                NavigationLink { RecipeDetailView(id: recipe.id, dishID: dish.id) } label: { Label("View Recipe", systemImage: "book") }.accessibilityIdentifier("dish-view-recipe")
                Text(recipe.content.title).font(.subheadline).foregroundStyle(.secondary)
            } else if loaded {
                Button("Add Recipe", systemImage: "plus") { creating = true }.buttonStyle(SGButtonStyle()).accessibilityIdentifier("dish-add-recipe")
                Button("Use a Saved Recipe") { selecting = true }.frame(minHeight: 44)
                Text("Saving a recipe adds this dish to Food Bible automatically.").font(.footnote).foregroundStyle(.secondary)
            }
            if failed { Button("Retry Recipe") { Task { await load() } }; Text("Recipe access needs a connection and completed cooking sync.").font(.footnote) }
        }.task(id: dish.id) { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
            .onChange(of: phase) { _, next in generation = UUID(); recipe = nil; loaded = false; if next == .active { Task { await load() } } }
            .onDisappear { generation = UUID() }
            .sheet(isPresented: $creating, onDismiss: { Task { await load() } }) { RecipeEditor(dishID: dish.id, title: dish.name, course: dish.defaultCategoryCode, cuisine: dish.cuisineLabel) { recipe = $0; loaded = true } }
            .sheet(isPresented: $selecting, onDismiss: { Task { await load() } }) { NavigationStack { RecipeLibraryView(dishID: dish.id) } }
    }
    private func load() async {
        guard let request else { return }; let token = UUID(); generation = token
        do {
            let page = try JSONDecoder().decode(DishRecipeResponse.self, from: await request("recipes", "dish", .init(dishID: dish.id)))
            guard !Task.isCancelled, token == generation else { return }; recipe = page.recipe; loaded = true; failed = false
        } catch is CancellationError {} catch { if token == generation { recipe = nil; loaded = false; failed = true } }
    }
}

// Presentation-only selection, reusing existing media without copying files or relationships.
extension Dish {
    var cookbookRepresentativeCook: CookingAttempt? {
        let ordered = attempts.sorted { $0.createdAt > $1.createdAt }
        return ordered.first { $0.primaryImage != nil } ?? ordered.first
    }
}
