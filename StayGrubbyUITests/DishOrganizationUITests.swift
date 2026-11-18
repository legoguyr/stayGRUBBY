import XCTest

/// Dish/Recipe integrity and Smart Collections (November 18, 2026): Rank a Dish offers an explicit
/// "another cook" choice for a known Dish, a cook logged under the wrong Dish becomes its own Dish
/// without losing its ranking, and both Dishes can share a collection.
final class DishOrganizationUITests: StayGrubbyUITestCase {
    /// The Cook Name field sits below the Dish fields (and collections); bring it on screen first.
    @MainActor private func nameCook(_ title: String, _ app: XCUIApplication) {
        let field = app.textFields["version-title"]
        for _ in 0..<5 where !app.cookingFieldIsVisible(field) { app.scrollCookingFormToward(field) }
        field.tap(); field.typeText(title)
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

        // The Mushroom cook was really a different Dish: separate it.
        app.showAllVersions()
        let mushroomRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Mushroom'")).firstMatch
        XCTAssertTrue(mushroomRow.waitForExistence(timeout: 8)); mushroomRow.tap()
        app.cookAction("cook-separate").tap()
        let newName = app.textFields["move-cook-name"]
        XCTAssertTrue(newName.waitForExistence(timeout: 8))
        XCTAssertEqual(newName.value as? String, "Mushroom Risotto", "Cook Name + Dish name is the starting suggestion")
        XCTAssertTrue(app.descendants(matching: .any)["collection-remove-Risotto"].exists, "The old Dish name is offered as a collection")
        app.buttons["move-cook-confirm"].tap()

        // Two Dishes now, each keeping its ranked cook; both in the Risotto collection.
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 10))
        let separated = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Mushroom Risotto'")).firstMatch
        XCTAssertTrue(separated.waitForExistence(timeout: 8)); separated.tap()
        let chips = app.buttons["dish-collections"]
        XCTAssertTrue(chips.waitForExistence(timeout: 8)); XCTAssertTrue(chips.label.contains("Risotto"))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Separated Dish with its collection"; shot.lifetime = .keepAlways; add(shot)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let original = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Butternut Squash'")).firstMatch
        XCTAssertTrue(original.waitForExistence(timeout: 8)); original.tap()
        XCTAssertTrue(app.buttons["dish-collections"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["dish-collections"].label.contains("Risotto"), "The original Dish's collections are unchanged")
    }
}
