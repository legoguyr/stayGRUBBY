import XCTest

/// Connected UI Phase 1 (November 15, 2026): one Dish page with Dish & Ranking and Recipe tabs, Food Bible
/// My Recipes / Saved Recipes, and saves that reference (never copy) another creator's Recipe.
final class ConnectedDishUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ arguments: [String]) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--test-reduce-motion"] + arguments
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        return app
    }
    @MainActor private func reach(_ element: XCUIElement, _ app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), app.debugDescription)
        for _ in 0..<10 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func shot(_ name: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    @MainActor func testDishPageTabsShareOneHeaderAndSwitchWithoutLosingTheRanking() throws {
        let app = launch(["--discovery-fixture", "--bible-review", "--stage4-review", "--recipe-photo-review", "--test-light"])
        let cook = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'")).firstMatch
        XCTAssertTrue(cook.waitForExistence(timeout: 10)); cook.tap()
        let tabs = app.segmentedControls["dish-tabs"]
        XCTAssertTrue(tabs.waitForExistence(timeout: 10))
        XCTAssertTrue(tabs.buttons["Dish & Ranking"].isSelected)
        let rank = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH 'overall'")).firstMatch
        XCTAssertTrue(rank.waitForExistence(timeout: 5)); let rankBefore = rank.label
        // Make sure this Dish has a Recipe (Add Recipe writes it on the same Dish).
        let view = app.buttons["dish-view-recipe"], add = app.buttons["dish-add-recipe"]
        for _ in 0..<8 where !(view.exists || add.exists) { app.swipeUp() }
        if !view.exists {
            reach(add, app); add.tap()
            XCTAssertTrue(app.buttons["dish-recipe-manual"].waitForExistence(timeout: 5)); app.buttons["dish-recipe-manual"].tap()
            XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout: 8)); app.buttons["recipe-save"].tap()
        }
        reach(view, app); view.tap()
        // The Recipe tab is the same page: header stays, Recipe content is already there.
        XCTAssertTrue(tabs.buttons["Recipe"].isSelected)
        XCTAssertTrue(app.buttons["recipe-make"].waitForExistence(timeout: 3))
        // MVP stabilization: the cook count is a plain header metric beside score and rank, never a control.
        let count = app.descendants(matching: .any)["dish-cook-count"]
        XCTAssertTrue(count.exists, "Verified cook count in the shared header"); XCTAssertTrue(count.label.hasPrefix("Cooked "), count.label)
        XCTAssertFalse(app.buttons["dish-cook-count"].exists); XCTAssertFalse(app.descendants(matching: .any)["recipe-makes"].exists)
        let recipeHeroOnRecipeTab = app.descendants(matching: .any)["recipe-hero"].exists
        XCTAssertFalse(app.buttons["recipe-fork"].exists)
        shot("Connected Dish page · Recipe tab", app)
        // Back and forth is immediate (no loading state) and the ranking is unchanged.
        for _ in 0..<3 {
            app.swipeDown(); app.swipeDown()
            tabs.buttons["Dish & Ranking"].tap()
            XCTAssertTrue(app.buttons["cook-more-actions"].waitForExistence(timeout: 2))
            XCTAssertFalse(app.descendants(matching: .any)["Opening the Recipe"].exists)
            tabs.buttons["Recipe"].tap()
            XCTAssertTrue(app.buttons["recipe-make"].waitForExistence(timeout: 2))
        }
        tabs.buttons["Dish & Ranking"].tap()
        // One header photo for the page: the same source on both tabs.
        XCTAssertEqual(app.descendants(matching: .any)["recipe-hero"].exists, recipeHeroOnRecipeTab)
        XCTAssertEqual(app.descendants(matching: .any)["dish-cook-count"].label, count.label)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH 'overall'")).firstMatch.label, rankBefore)
        let cooks = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'version-row-'")).firstMatch
        reach(cooks, app)
        shot("Connected Dish page · Dish & Ranking tab", app)
    }

    @MainActor func testSavedRecipeIsACreditedReferenceSeparateFromMyRecipes() throws {
        let app = launch(["--recipes-review", "--stage5-review", "--test-dark"])
        app.tabBars.buttons["My Kitchen"].tap(); XCTAssertTrue(app.buttons["friends-open"].waitForExistence(timeout: 8))
        app.buttons["friends-open"].tap()
        let friend = app.buttons["friend-person-friend_cook"]; XCTAssertTrue(friend.waitForExistence(timeout: 15)); friend.tap()
        let open = app.buttons["kitchen-recipes-open"]; reach(open, app); open.tap()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'kitchen-recipe-' AND label CONTAINS 'Sous Chef Lemon Cake'")).firstMatch
        reach(card, app); card.tap()
        let save = app.buttons["recipe-save"]; reach(save, app)
        XCTAssertFalse(app.buttons["recipe-fork"].exists, "No in-app copy of another creator's Recipe")
        XCTAssertEqual(save.label, "Save Recipe"); save.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == 'recipe-save' AND label == 'Saved to Food Bible'")).firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        // The Sous Chef's Recipes open in a sheet; close it to reach the tab bar.
        for _ in 0..<4 where !app.tabBars.buttons["Food Bible"].isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        }
        app.tabBars.buttons["Food Bible"].tap()
        let library = app.segmentedControls["bible-library"]; XCTAssertTrue(library.waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-' AND label CONTAINS 'Sous Chef Lemon Cake'")).firstMatch.exists,
                       "A save never becomes one of My Recipes")
        library.buttons["Saved Recipes"].tap()
        let saved = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-saved-' AND label CONTAINS 'Sous Chef Lemon Cake'")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 8)); XCTAssertTrue(saved.label.contains("by "), saved.label)
        shot("Food Bible Saved Recipes dark", app)
        saved.tap()
        let unsave = app.buttons["recipe-save"]; reach(unsave, app); XCTAssertEqual(unsave.label, "Saved to Food Bible"); unsave.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == 'recipe-save' AND label == 'Save Recipe'")).firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["bible-saved-empty"].waitForExistence(timeout: 8))
    }

    /// Read caching: switching tabs and coming back neither refetches nor shows a loading screen; pull to
    /// refresh still refreshes (one request), and a content change makes the next appearance refresh.
    @MainActor func testThePassAndFoodBibleReuseLoadedContentAcrossTabSwitches() throws {
        let app = launch(["--recipes-review", "--stage5-review", "--request-log", "--test-light"])
        let log = app.descendants(matching: .any)["review-request-log"]
        func count(_ key: String) -> Int {
            let entry = log.label.split(separator: " ").first { $0.hasPrefix(key + "=") }
            return entry.flatMap { Int($0.split(separator: "=")[1]) } ?? 0
        }
        app.tabBars.buttons["The Pass"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["grub-list"].waitForExistence(timeout: 10))
        let feedLoaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in count("social_feed.activity_page") >= 1 }, object: nil)
        wait(for: [feedLoaded], timeout: 10)
        app.tabBars.buttons["Food Bible"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-'")).firstMatch.waitForExistence(timeout: 10))
        let feed = count("social_feed.activity_page"), bible = count("recipes.library_index")
        XCTAssertGreaterThan(bible, 0)
        for _ in 0..<3 {
            app.tabBars.buttons["The Pass"].tap()
            XCTAssertFalse(app.descendants(matching: .any)["Loading posts"].exists, "Posts stay on screen")
            app.tabBars.buttons["Grub Rank"].tap()
            app.tabBars.buttons["Food Bible"].tap()
            XCTAssertFalse(app.descendants(matching: .any)["Opening your cookbook"].exists, "The cookbook stays on screen")
        }
        XCTAssertEqual(count("social_feed.activity_page"), feed, log.label)
        XCTAssertEqual(count("recipes.library_index"), bible, log.label)
        shot("Read caching · request log after tab switches", app)
        // Pull to refresh is an explicit refresh: exactly one more cookbook read.
        // (A synthesized pull is occasionally swallowed by the simulator; retry the gesture, not the assertion.)
        for _ in 0..<3 where count("recipes.library_index") == bible {
            let start = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-'")).firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 420)), withVelocity: .slow, thenHoldForDuration: 0.6)
            let refreshed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in count("recipes.library_index") > bible }, object: nil)
            _ = XCTWaiter.wait(for: [refreshed], timeout: 5)
        }
        XCTAssertEqual(count("recipes.library_index"), bible + 1, log.label)
    }

    /// My Kitchen statistics open Grub Rank's All Dishes: one row per Dish (Nov 18, 2026: no Top / All
    /// toggle). Search and filters are cleared.
    @MainActor func testKitchenStatisticsOpenGrubRankInTheMatchingView() throws {
        let app = launch(["--discovery-fixture", "--test-light"])
        func count(_ id: String) -> Int { Int(app.descendants(matching: .any)[id].label.split(separator: " ").first ?? "") ?? -1 }
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'"))
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 10)); app.showAllVersions()
        app.tabBars.buttons["My Kitchen"].tap()
        let dishes = app.descendants(matching: .any)["profile-dish-count"]; XCTAssertTrue(dishes.waitForExistence(timeout: 10))
        let dishCount = count("profile-dish-count"), makes = count("profile-entry-count")
        XCTAssertGreaterThan(makes, dishCount, "The fixture has Dishes with several cooks")
        dishes.tap()
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        for _ in 0..<16 where rows.count < dishCount { app.swipeUp() }
        XCTAssertLessThanOrEqual(rows.count, dishCount, "All Dishes lists one row per Dish")
        app.tabBars.buttons["My Kitchen"].tap()
        let total = app.descendants(matching: .any)["profile-entry-count"]; XCTAssertTrue(total.waitForExistence(timeout: 10)); total.tap()
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["discovery-result-count"].exists, "No search or filter narrows the list")
        shot("Grub Rank from Total Makes", app)
    }
}
