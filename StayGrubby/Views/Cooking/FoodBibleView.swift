import SwiftUI
import SwiftData

/// A derived cookbook of existing cooked Dishes. Tickets remain a separate Want to Cook destination.
struct FoodBibleView: View {
    @Environment(\.socialRequest) private var request
    @Environment(\.scenePhase) private var phase
    @Environment(\.dynamicTypeSize) private var textSize
    @Query private var dishes: [Dish]
    @State private var entries: [CookbookEntry] = []
    @State private var query = ""
    @State private var course = ""
    @State private var cuisine = ""
    @State private var loading = false
    @State private var failed = false
    @State private var more = false
    @State private var generation = UUID()
    @State private var choosing = false
    private var filterKey: String { query + "|" + course + "|" + cuisine }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGTheme.Space.large) {
                SGPageIntro(title: "Your Food Bible", subtitle: "Recipes for the dishes you’ve made.", eyebrow: "Your personal cookbook", showsTitle: false)
                NavigationLink { TicketsView() } label: {
                    HStack { Label("Tickets", systemImage: "ticket"); Spacer(); Text("Want to cook").foregroundStyle(.secondary); Image(systemName: "chevron.right") }
                        .padding(SGTheme.Space.medium).background(SGTheme.ColorToken.surface, in: RoundedRectangle(cornerRadius: SGTheme.Radius.card))
                }.buttonStyle(.plain).accessibilityIdentifier("bible-tickets")
                TextField("Search dishes or recipes", text: $query).sgField().accessibilityIdentifier("bible-search")
                ViewThatFits {
                    HStack { coursePicker; cuisineField }
                    VStack { coursePicker; cuisineField }
                }
                if loading && entries.isEmpty { ProgressView("Opening your cookbook") }
                if failed {
                    Text("Your cookbook couldn’t be loaded. Check your connection; your cooking history is safe.")
                    Button("Retry") { Task { await load() } }
                } else if !loading && entries.isEmpty {
                    VStack(alignment: .leading, spacing: SGTheme.Space.medium) {
                        Image(systemName: "book.closed").font(.largeTitle).foregroundStyle(.secondary).accessibilityHidden(true)
                        Text(filterKey == "||" ? "Your recipes will live here." : "No matching recipes.").font(SGTheme.TypeRole.title)
                        Text("Add a recipe to a dish you’ve cooked. It will appear here automatically.")
                    }.padding(.vertical, SGTheme.Space.large).accessibilityIdentifier("bible-empty")
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: textSize.isAccessibilitySize ? 300 : 155), alignment: .top)], alignment: .leading, spacing: SGTheme.Space.large) {
                    ForEach(entries) { entry in
                        NavigationLink { RecipeDetailView(id: entry.recipeID, dishID: entry.dishID) } label: { cookbookCard(entry) }
                            .buttonStyle(.plain).accessibilityIdentifier("bible-entry-\(entry.dishID)")
                    }
                }
                if more { Button("More recipes") { Task { await load(append: true) } }.disabled(loading) }
                Button("Add Recipe to a Dish", systemImage: "plus") { choosing = true }.buttonStyle(SGButtonStyle()).accessibilityIdentifier("bible-add")
                NavigationLink("Saved recipes not yet in your cookbook") { RecipeLibraryView() }.font(.footnote).accessibilityIdentifier("bible-saved-recipes")
            }.padding(SGTheme.Space.medium).frame(maxWidth: SGTheme.Size.contentMaximum).frame(maxWidth: .infinity)
        }.background(SGTheme.ColorToken.background).navigationTitle("Food Bible").navigationBarTitleDisplayMode(.inline)
            .task(id: filterKey) { try? await Task.sleep(for: .milliseconds(200)); guard !Task.isCancelled else { return }; await load() }
            .refreshable { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .socialContentChanged)) { _ in Task { await load() } }
            .onChange(of: phase) { _, next in generation = UUID(); entries = []; if next == .active { Task { await load() } } }
            .onDisappear { generation = UUID() }
            .sheet(isPresented: $choosing) { NavigationStack { CookedDishPicker() } }
    }
    private var coursePicker: some View {
        Picker("Course", selection: $course) { Text("All courses").tag(""); ForEach(DishCategory.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) } }.accessibilityIdentifier("bible-course")
    }
    private var cuisineField: some View { TextField("Cuisine · optional filter", text: $cuisine).sgField().accessibilityIdentifier("bible-cuisine") }
    private func cookbookCard(_ entry: CookbookEntry) -> some View {
        let dish = dishes.first { $0.id == entry.dishID }
        let cook = dish?.cookbookRepresentativeCook
        return VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            DishPhoto(media: cook?.primaryImage, thumbnail: true, name: entry.dishTitle).aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.card))
            Text(entry.dishTitle).font(SGTheme.TypeRole.headline).foregroundStyle(SGTheme.ColorToken.primaryText).fixedSize(horizontal: false, vertical: true)
            if entry.recipeTitle != entry.dishTitle { Text(entry.recipeTitle).font(.subheadline).foregroundStyle(.secondary) }
            Text([entry.cuisine, entry.course.flatMap { DishCategory(rawValue: $0)?.label }].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine).accessibilityHint("Opens recipe for this dish")
    }
    private func load(append: Bool = false) async {
        guard let request else { failed = true; loading = false; return }
        let token = UUID(); generation = token; loading = true; failed = false
        defer { if generation == token { loading = false } }
        do {
            var payload = SocialPayload(); payload.query = query; payload.course = course; payload.cuisine = cuisine
            if append { payload.beforeID = entries.last?.dishID }
            let page = try JSONDecoder().decode(CookbookPage.self, from: await request("recipes", "cookbook", payload))
            guard !Task.isCancelled, generation == token else { return }
            if append { let old = Set(entries.map(\.id)); entries += page.entries.filter { !old.contains($0.id) } } else { entries = page.entries }
            more = page.entries.count == 50
        } catch is CancellationError {} catch { if generation == token { entries = []; failed = true } }
    }
}

private struct CookedDishPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Dish.name) private var dishes: [Dish]
    var body: some View {
        SGEditorialList {
            Text("Choose something you’ve cooked. Your Dish, versions and ranking stay exactly as they are.")
            ForEach(dishes.filter { !$0.attempts.isEmpty }) { dish in
                NavigationLink(dish.name) { DishRecipeDestination(dish: dish, onDone: { dismiss() }) }
            }
            if dishes.isEmpty { Text("Cook and rank your first dish in Grub Rank, then add its recipe here.") }
        }.navigationTitle("Choose a Dish").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
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
