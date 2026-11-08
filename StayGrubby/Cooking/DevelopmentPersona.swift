#if DEBUG
import Foundation
import SwiftData

/// A fictional home cook, rebuilt from the same choices in each new isolated store.
@MainActor
enum DevelopmentPersona {
    private struct Cook {
        var dish: String
        var version: String
        var cuisine: String
        var course: DishCategory
        var reaction: InitialReaction
        var preference: Int
        var notes: String
        var contains: Set<Allergen> = []
        var diet: Set<DietaryTag> = []
    }

    private static let cooks: [Cook] = [
        .init(dish: "Red Lentil Soup", version: "Weeknight pot", cuisine: "Turkish", course: .soup, reaction: .liked, preference: 8, notes: "Lemon at the table kept it bright.", diet: [.vegan]),
        .init(dish: "Harissa Chicken", version: "Oven-roasted batch", cuisine: "Moroccan", course: .main, reaction: .fine, preference: 5, notes: "Good crust. The pan was crowded and the onions steamed."),
        .init(dish: "Miso Butter Udon", version: "", cuisine: "Japanese", course: .pastaNoodles, reaction: .liked, preference: 11, notes: "A splash of noodle water made the sauce glossy.", contains: [.milk, .soy, .wheat]),
        .init(dish: "Lemon Olive Oil Cake", version: "First bake", cuisine: "Italian", course: .dessert, reaction: .fine, preference: 4, notes: "The crumb needed another five minutes.", contains: [.egg, .wheat], diet: [.vegetarian]),
        .init(dish: "Charred Broccoli with Tahini", version: "", cuisine: "Mediterranean", course: .side, reaction: .liked, preference: 7, notes: "Leave the stalks thick enough to stay juicy.", contains: [.sesame], diet: [.vegan]),
        .init(dish: "Black Bean Tacos", version: "", cuisine: "Mexican", course: .main, reaction: .liked, preference: 9, notes: "Pickled red onions were worth making ahead.", diet: [.vegan]),
        .init(dish: "Crispy Rice Salad", version: "", cuisine: "Thai", course: .salad, reaction: .fine, preference: 3, notes: "Dressed too early. The rice lost its crunch.", contains: [.peanuts, .fish]),
        .init(dish: "Harissa Chicken", version: "Smoky Sunday", cuisine: "Moroccan", course: .main, reaction: .liked, preference: 13, notes: "Salted overnight and finished on the grill. Repeat this.", diet: [.dairyFree]),
        .init(dish: "Scallion Pancakes", version: "", cuisine: "Chinese", course: .appetizer, reaction: .liked, preference: 10, notes: "Resting the dough made it much easier to roll.", contains: [.wheat, .sesame]),
        .init(dish: "Grapefruit Granita", version: "", cuisine: "Italian", course: .dessert, reaction: .disliked, preference: 1, notes: "Too bitter after freezing. Try orange next time.", diet: [.vegan]),
        .init(dish: "Lemon Olive Oil Cake", version: "Extra zest", cuisine: "Italian", course: .dessert, reaction: .liked, preference: 12, notes: "Rubbed the zest into the sugar before mixing.", contains: [.egg, .wheat], diet: [.vegetarian]),
        .init(dish: "Ginger-Soy Salmon", version: "", cuisine: "Japanese", course: .main, reaction: .fine, preference: 6, notes: "Pull the salmon a little earlier next time.", contains: [.fish, .soy]),
        .init(dish: "Red Lentil Soup", version: "Smoked paprika", cuisine: "Turkish", course: .soup, reaction: .liked, preference: 8, notes: "Equally good as the first pot. More smoky than bright.", diet: [.vegan]),
        .init(dish: "Skillet Cornbread", version: "", cuisine: "Southern / Soul Food", course: .bakedGood, reaction: .fine, preference: 2, notes: "Preheat the skillet longer for a darker crust.", contains: [.egg, .milk, .wheat], diet: [.vegetarian])
    ]

    static func seed(context: ModelContext, marker: URL) throws {
        guard !FileManager.default.fileExists(atPath: marker.path) else { return }
        let ranking = try CookingStore.prepare(context: context)
        var dishes = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Dish>()).map { ($0.name, $0) })
        let preferences = Dictionary(uniqueKeysWithValues: cooks.enumerated().map { (id($0.offset), $0.element.preference) })
        for (index, cook) in cooks.enumerated() where !ranking.items.contains(where: { $0.id == id(index) }) {
            var draft = CookingDraft()
            draft.dishName = cook.dish
            draft.versionTitle = cook.version
            draft.category = cook.course
            draft.cuisine = CuisineCatalog.existing(cook.cuisine)
            draft.cookedAt = date(index)
            draft.notes = cook.notes
            draft.contains = cook.contains
            draft.dietary = cook.diet
            if cook.dish == "Harissa Chicken" {
                draft.publicDescription = "Charred harissa chicken with onions and lemon."
                draft.privateNotes = "Avery likes the extra-charred pieces. Keep a mild portion aside."
                var source = DishSourceDraft(type: .friendFamily)
                source.friendName = "Avery"
                draft.source = source
            }
            var session = RankingEngine(itemID: id(index), orderedIDs: ranking.orderedItems.map(\.id), reaction: cook.reaction)
            while let opponent = session.nextOpponent {
                guard let preference = preferences[opponent] else { throw CookingStore.StoreError.invalidDraft }
                let answer: ComparisonAnswer = cook.preference == preference ? .tooTough : (cook.preference > preference ? .newItem : .existingItem)
                session.answer(answer, at: date(index).addingTimeInterval(Double(session.answers.count)))
            }
            let attempt = try CookingStore.create(draft: draft, existingDish: dishes[cook.dish], session: session, context: context)
            dishes[cook.dish] = attempt.dish
        }
        try Data().write(to: marker, options: .atomic)
    }

    static func populate(_ review: SocialReview, context: ModelContext) throws {
        let attempts = try context.fetch(FetchDescriptor<CookingAttempt>())
        let byItem = Dictionary(uniqueKeysWithValues: attempts.map { ($0.rankedItemID, $0) })
        let avery = SocialPerson(id: id(101), displayName: "Avery Chen", username: "avery_at_the_stove", relationship: .friends)
        let ines = SocialPerson(id: id(102), displayName: "Inés Rivera", username: "ines_cooks", relationship: .friends)
        let jonah = SocialPerson(id: id(103), displayName: "Jonah Brooks", username: "jonah_bakes", relationship: .incoming)
        let maya = SocialPerson(id: UUID(uuidString: "10000000-0000-0000-0000-000000000099")!,
            displayName: "Maya Ortiz", username: "maya_at_home", relationship: .none)
        review.identity = .init(displayName: maya.displayName, username: maya.username, discoverable: false)
        review.people = [avery, ines, jonah]

        let chickenID = id(201), soupID = id(202), cakeID = id(203), beansID = id(204)
        var chicken = RecipeContent(title: "Harissa Chicken", description: "Grilled chicken thighs with sweet charred onion.",
            ingredients: ["1 1/2 lb chicken thighs", "2 tbsp harissa", "1 lemon", "1 red onion", "1 tsp kosher salt"],
            steps: ["Rub the thighs with harissa and salt. Refrigerate overnight.", "Grill the thighs and onion over medium heat until the chicken reaches 165°F.", "Rest briefly and finish with lemon."],
            course: "main", cuisine: "Moroccan", yield: "4 servings", prepMinutes: 15, cookMinutes: 25)
        let originalChicken = recipe(chickenID, chicken, day: 1, creator: avery)
        chicken.steps[0] = "Rub the thighs with harissa, lemon zest and salt. Refrigerate overnight."
        chicken.tips = "Start the onion on the cooler side of the grill."
        var currentChicken = recipe(chickenID, chicken, day: 1, creator: avery)
        currentChicken.revision = 2
        currentChicken.updatedAt = date(9).timeIntervalSince1970

        let soup = recipe(soupID, .init(title: "Red Lentil Soup", description: "Silky red lentils with cumin and lemon.",
            ingredients: ["1 cup red lentils", "1 yellow onion", "4 cups vegetable stock", "1 tsp cumin", "1 lemon"],
            steps: ["Soften the chopped onion and toast the cumin.", "Add the lentils and stock. Simmer until tender, about 25 minutes.", "Blend and finish with lemon juice."],
            course: "soup", cuisine: "Turkish", yield: "4 servings", prepMinutes: 10, cookMinutes: 30), day: 0)
        let cake = recipe(cakeID, .init(title: "Lemon Olive Oil Cake",
            ingredients: ["1 1/2 cups flour", "2 eggs", "3/4 cup sugar", "1/2 cup olive oil", "2 lemons", "1 tsp baking powder"],
            steps: ["Rub lemon zest into the sugar. Whisk in the eggs and olive oil.", "Fold in the flour and baking powder. Bake in an 8-inch pan at 350°F until the center springs back."],
            course: "dessert", cuisine: "Italian", yield: "8 servings", prepMinutes: 15, cookMinutes: 40,
            allergens: .init(contains: ["egg", "wheat"])), day: 10)
        let beans = recipe(beansID, .init(title: "Rosemary White Beans", description: "A slow pot of beans to spoon over toast.",
            ingredients: ["2 cups cooked cannellini beans", "1 sprig rosemary", "2 cloves garlic", "1 tbsp olive oil"],
            steps: ["Sizzle sliced garlic and rosemary in the oil.", "Add the beans with a splash of their cooking liquid. Simmer until creamy."],
            course: "main", cuisine: "Italian", yield: "3 servings", prepMinutes: 5, cookMinutes: 20), day: 11)

        review.recipes = [chickenID: currentChicken, soupID: soup, cakeID: cake, beansID: beans]
        review.recipeVersions[chickenID] = [originalChicken, currentChicken]
        review.recipeActivityTimes[chickenID] = (id(401), originalChicken.createdAt)
        for (recipeID, index) in [(chickenID, 7), (soupID, 12), (cakeID, 10)] {
            review.cookRecipeLinks[recipeID] = byItem[id(index)]?.id
        }
        if byItem[id(7)] != nil {
            let origin = id(301)
            review.recipeClaims[origin] = .init(id: origin, itemID: id(7), kind: "recipe", completed: true,
                metadata: .init(title: originalChicken.content.title, course: "main"), recipeOriginID: origin, recipeSnapshot: originalChicken.content)
            review.recipeClaimSnapshots[origin] = .init(id: origin, recipeID: chickenID, creatorName: avery.displayName,
                snapshot: originalChicken.content, revision: originalChicken.revision)
        }

        let peerPost = id(501)
        review.posts = [.init(id: peerPost, author: avery, title: "Smashed Cucumber Salad", versionTitle: nil,
            scoreText: "8.1", achievement: nil, createdAt: date(12).timeIntervalSince1970, photoPath: nil,
            published: true, isAuthor: false, moderationState: "active", likeCount: 1, liked: true,
            postDescription: "Chilled cucumbers, black vinegar and a generous spoon of chili crisp.",
            metadata: .init(course: "salad", cuisine: CuisineCatalog.existing("Chinese")))]
        if let cook = byItem[id(7)] {
            let post = id(502)
            review.posts.append(.init(id: post, author: maya, title: "Harissa Chicken", versionTitle: cook.versionTitle,
                scoreText: "8.8",
                achievement: nil, createdAt: date(13).timeIntervalSince1970, photoPath: nil,
                published: true, isAuthor: true, moderationState: "active", likeCount: 1, commentCount: 1,
                postDescription: "A little smoke and a lot of lemon. The overnight rub made the difference.",
                metadata: .init(course: "main", cuisine: cook.dish?.cuisine)))
            review.postCookIDs[post] = cook.id
            review.comments[post] = [.init(id: id(601), author: ines, body: "The char on the onions is my favorite part.",
                createdAt: date(13).timeIntervalSince1970 + 3600, canDelete: true, isAuthor: false)]
            review.notices.append(.init(id: id(701), kind: "comment", actor: ines, targetID: post, postID: post,
                createdAt: date(13).timeIntervalSince1970 + 3600, read: false))
        }
        review.notices.append(.init(id: id(702), kind: "request", actor: jonah, targetID: jonah.id, postID: nil,
            createdAt: date(11).timeIntervalSince1970, read: true))
    }

    private static func recipe(_ id: UUID, _ content: RecipeContent, day: Int, creator: SocialPerson? = nil) -> Recipe {
        let time = date(day).timeIntervalSince1970
        return .init(id: id, isOwner: creator == nil, creator: creator, content: content.preparedForSave(),
                     visibility: creator == nil ? "private" : "friends", revision: 1, createdAt: time, updatedAt: time, saved: false)
    }

    private static func date(_ index: Int) -> Date {
        Date(timeIntervalSince1970: 1_770_379_200 + Double(index) * 7 * 86_400)
    }

    private static func id(_ index: Int) -> UUID {
        UUID(uuidString: "4A9A0000-0000-4000-8000-" + String(format: "%012d", index))!
    }
}
#endif
