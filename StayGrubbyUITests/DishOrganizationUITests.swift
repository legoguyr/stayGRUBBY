import XCTest

/// Dish/Recipe integrity and Smart Collections (November 18, 2026): Rank a Dish offers an explicit
/// "another cook" choice for a known Dish, a cook logged under the wrong Dish becomes its own Dish
/// without losing its ranking, and both Dishes can share a collection.
final class DishOrganizationUITests: StayGrubbyUITestCase {
    /// Opens a Grub Rank row's Dish page; the first tap after a sheet closes is sometimes swallowed.
    @MainActor private func openDish(_ row: XCUIElement, _ app: XCUIApplication) {
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        for _ in 0..<3 { row.tap(); if app.segmentedControls["dish-tabs"].waitForExistence(timeout: 4) { return } }
        XCTFail("Dish page did not open")
    }
    /// The Cook Name field sits below the Dish fields (and collections); bring it on screen first.
    @MainActor private func nameCook(_ title: String, _ app: XCUIApplication) {
        let field = app.textFields["version-title"]
        for _ in 0..<5 where !app.cookingFieldIsVisible(field) { app.scrollCookingFormToward(field) }
        field.tap(); field.typeText(title)
        if app.buttons["cook-keyboard-done"].exists { app.buttons["cook-keyboard-done"].tap() }
    }
    @MainActor func testSeparateACookIntoItsOwnDishAndGroupThemInACollection() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--test-light", "--test-reduce-motion", "--feature-flag", "dish_collections"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))

        // First Dish: Risotto, cook "Butternut Squash".
        app.revealCreation(); app.buttons["new-dish"].tap()
        let name = app.textFields["dish-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Risotto")
        nameCook("Butternut Squash", app)
        app.buttons["Continue"].tap(); app.buttons["Liked it"].tap()
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 15)); app.buttons["ranking-result-close"].tap()

        // Rank a Dish with the same name: the app asks, it never merges on its own.
        app.revealCreation(); app.buttons["new-dish"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("risotto")
        // Close the keyboard: the floating Continue bar otherwise sits over the prompt.
        if app.buttons["cook-keyboard-done"].exists { app.buttons["cook-keyboard-done"].tap() }
        let match = app.buttons["cook-existing-match"]
        XCTAssertTrue(match.waitForExistence(timeout: 5), "A matching Dish is offered explicitly")
        match.tap()
        let inherited = app.staticTexts["inherited-dish-name"]
        XCTAssertTrue(inherited.waitForExistence(timeout: 10)); XCTAssertEqual(inherited.label, "Risotto")
        nameCook("Mushroom", app)
        app.buttons["Continue"].tap(); app.buttons["Liked it"].tap()
        let prefer = app.buttons["Prefer Risotto — Mushroom"]
        XCTAssertTrue(prefer.waitForExistence(timeout: 10)); prefer.tap()
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 15)); app.buttons["ranking-result-close"].tap()

        // The Mushroom cook was really a different Dish: separate it from the Dish page.
        let risottoRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Risotto'")).firstMatch
        openDish(risottoRow, app)
        let separate = app.buttons["dish-separate-cooks"]
        for _ in 0..<8 where !separate.isHittable { app.swipeUp() }
        separate.tap()
        let toggle = app.switches["separate-toggle-Mushroom"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 8)); toggle.switches.firstMatch.tap()
        let newName = app.textFields["separate-name-Mushroom"]
        XCTAssertTrue(newName.waitForExistence(timeout: 5))
        XCTAssertEqual(newName.value as? String, "Mushroom Risotto", "Cook Name + the Dish's last word is the starting suggestion")
        XCTAssertFalse(app.switches["separate-toggle-Butternut Squash"].isEnabled, "The Dish always keeps one cook")
        let folder = app.switches["separate-folder-toggle"]
        for _ in 0..<4 where !folder.isHittable { app.swipeUp() }
        folder.switches.firstMatch.tap()
        app.buttons["separate-save"].tap()

        // Two Dishes now, each keeping its ranked cook; both in the Risotto folder.
        if !app.rankingHeader.exists { app.navigationBars.buttons.element(boundBy: 0).tap() }
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 10))
        let separated = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Mushroom Risotto'")).firstMatch
        openDish(separated, app)
        XCTAssertTrue(app.buttons["dish-explore-Risotto"].waitForExistence(timeout: 8), "Explore Risotto folder callout")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Separated Dish with its collection"; shot.lifetime = .keepAlways; add(shot)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let original = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Butternut Squash'")).firstMatch // the Dish that stays
        openDish(original, app)
        XCTAssertTrue(app.buttons["dish-explore-Risotto"].waitForExistence(timeout: 8), "Both Dishes are in the folder")
        // Folders tab: one Risotto folder holding both Dishes, never merged.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.segmentedControls["grub-rank-sections"].waitForExistence(timeout: 8))
        app.segmentedControls["grub-rank-sections"].buttons["Folders"].tap()
        let card = app.descendants(matching: .any).matching(identifier: "folder-Risotto").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8), app.debugDescription); XCTAssertTrue(card.label.contains("2 Dishes"), card.label)
        let folders = XCTAttachment(screenshot: app.screenshot()); folders.name = "Grub Rank Folders"; folders.lifetime = .keepAlways; add(folders)
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "collection-dish-Mushroom Risotto").firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "collection-dish-Risotto").firstMatch.exists)
        let inside = XCTAttachment(screenshot: app.screenshot()); inside.name = "Risotto folder"; inside.lifetime = .keepAlways; add(inside)
    }

    /// Food Bible → Recipe → its exact Dish, by Dish ID. A similarly named Dish never borrows the Recipe.
    @MainActor func testRecipeOpensItsOwnDishAmongSimilarlyNamedDishes() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--test-light", "--test-reduce-motion"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        func rank(_ dish: String, prefer: String?) {
            app.revealCreation(); app.buttons["new-dish"].tap()
            let name = app.textFields["dish-name"]; XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText(dish)
            if app.buttons["cook-keyboard-done"].exists { app.buttons["cook-keyboard-done"].tap() }
            app.buttons["Continue"].tap(); app.buttons["Liked it"].tap()
            if let prefer { let button = app.buttons["Prefer \(prefer)"]; XCTAssertTrue(button.waitForExistence(timeout: 10)); button.tap() }
            XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 15)); app.buttons["ranking-result-close"].tap()
            let notNow = app.buttons["Not Now"]
            if notNow.waitForExistence(timeout: 1), notNow.isHittable { notNow.tap() }
        }
        rank("Saffron Risotto", prefer: nil)
        rank("Mushroom Risotto", prefer: "Mushroom Risotto")

        // Give only Mushroom Risotto a Recipe, from its own Dish page.
        let mushroom = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Mushroom Risotto'")).firstMatch
        openDish(mushroom, app)
        let add = app.buttons["dish-add-recipe"]
        for _ in 0..<6 where !add.isHittable { app.swipeUp() }
        XCTAssertTrue(add.waitForExistence(timeout: 10)); add.tap()
        XCTAssertTrue(app.buttons["dish-recipe-manual"].waitForExistence(timeout: 8)); app.buttons["dish-recipe-manual"].tap()
        XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout: 8))
        if app.buttons["recipe-keyboard-done"].exists { app.buttons["recipe-keyboard-done"].tap() }
        app.buttons["recipe-save"].tap()
        XCTAssertTrue(app.segmentedControls["dish-tabs"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Food Bible: the Recipe opens Mushroom Risotto, never Saffron Risotto.
        app.tabBars.buttons["Food Bible"].tap()
        let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-' AND label CONTAINS 'Mushroom Risotto'")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        let open = app.buttons["recipe-open-dish"]
        XCTAssertTrue(open.waitForExistence(timeout: 10)); XCTAssertTrue(open.label.contains("Mushroom Risotto"))
        open.tap()
        XCTAssertEqual(app.staticTexts["dish-title"].label, "Mushroom Risotto")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-' AND label CONTAINS 'Saffron'")).firstMatch.exists)

        // Saffron Risotto has no Recipe.
        app.tabBars.buttons["Grub Rank"].tap()
        if !app.rankingHeader.exists { app.navigationBars.buttons.element(boundBy: 0).tap() }
        let saffron = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Saffron Risotto'")).firstMatch
        openDish(saffron, app)
        app.segmentedControls["dish-tabs"].buttons["Recipe"].tap()
        XCTAssertTrue(app.buttons["dish-link-recipe"].waitForExistence(timeout: 10), "No inherited Recipe")
    }
}
