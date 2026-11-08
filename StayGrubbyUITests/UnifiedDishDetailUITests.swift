import XCTest

/// D2 Unified Dish Detail: Recipes section with Main Recipe, Cooks section, the Recipe
/// reader's Dish block and the Food Bible Cooked filter. Isolated review fixtures only.
final class UnifiedDishDetailUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--discovery-fixture",
                               "--bible-review", "--stage4-review", "--recipe-photo-review", "--test-reduce-motion"] + extra
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        return app
    }
    @MainActor private func reach(_ element: XCUIElement, _ app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), app.debugDescription)
        for _ in 0..<10 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func chooseRecipe(_ app: XCUIApplication, index: Int) {
        let choices = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'choose-recipe-'"))
        XCTAssertTrue(choices.firstMatch.waitForExistence(timeout: 10)); XCTAssertGreaterThan(choices.count, index)
        choices.element(boundBy: index).tap()
    }
    @MainActor private func shot(_ name: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    @MainActor func testDishAndRecipeAreOneDish() throws {
        let app = launch(["--test-light"])
        let cook = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'")).firstMatch
        XCTAssertTrue(cook.waitForExistence(timeout: 10)); let rowLabel = cook.label; cook.tap()
        XCTAssertTrue(app.buttons["cook-more-actions"].waitForExistence(timeout: 10))
        reach(app.buttons["detail-new-version"], app)
        XCTAssertEqual(app.buttons["detail-new-version"].label, "Cook Again")
        // One Recipe side per Dish: View Recipe, or Add Recipe that writes this Dish's Recipe.
        let view = app.buttons["dish-view-recipe"], add = app.buttons["dish-add-recipe"]
        for _ in 0..<8 where !(view.exists || add.exists) { app.swipeUp() }
        if !view.exists {
            reach(add, app); add.tap()
            XCTAssertTrue(app.buttons["dish-recipe-manual"].waitForExistence(timeout: 5)); app.buttons["dish-recipe-manual"].tap()
            let title = app.textFields["recipe-edit-title"]; XCTAssertTrue(title.waitForExistence(timeout: 8))
            app.buttons["recipe-save"].tap()
        }
        reach(view, app); shot("D3 Dish View Recipe light", app)
        XCTAssertFalse(app.descendants(matching: .any)["MAIN RECIPE"].exists)
        view.tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["recipe-not-cooked"].exists)
        let cooks = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'version-row-'")).firstMatch
        reach(cooks, app)
        let heading = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Your cooks of'")).firstMatch
        XCTAssertTrue(heading.exists)
        XCTAssertTrue(rowLabel.contains(heading.label.replacingOccurrences(of: "Your cooks of ", with: "")), "\(heading.label) vs \(rowLabel)")
        app.revealRecipeActions(); XCTAssertFalse(app.buttons["recipe-link"].exists)
        shot("D3 Recipe face of the same Dish light", app)
    }

    @MainActor func testFoodBibleCookedFilterAndNotCookedYetState() throws {
        let app = launch(["--test-dark"])
        app.tabBars.buttons["Food Bible"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10)); let before = rows.count
        // A standalone Recipe is a Recipe-only Dish: not cooked yet.
        app.buttons["bible-add"].tap(); XCTAssertTrue(app.buttons["bible-manual"].waitForExistence(timeout: 8)); app.buttons["bible-manual"].tap()
        let title = app.textFields["recipe-edit-title"]; XCTAssertTrue(title.waitForExistence(timeout: 8)); title.tap(); title.typeText("Uncooked Granita")
        app.buttons["recipe-keyboard-done"].tap(); app.buttons["recipe-save"].tap()
        let added = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == %d", before + 1), object: rows)
        XCTAssertEqual(XCTWaiter.wait(for: [added], timeout: 10), .completed); let total = rows.count
        app.openBibleFilterGroup("cooked")
        XCTAssertTrue(app.buttons["bible-filter-option-notCooked"].waitForExistence(timeout: 5))
        app.buttons["bible-filter-option-notCooked"].tap(); app.buttons["filters-done"].tap()
        let notCooked = rows.count
        XCTAssertGreaterThanOrEqual(notCooked, 1); XCTAssertLessThan(notCooked, total)
        do {
            rows.firstMatch.press(forDuration: 0.2)
            XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.descendants(matching: .any)["recipe-not-cooked"].waitForExistence(timeout: 5))
            shot("D2 Not cooked yet dark", app)
            app.navigationBars.buttons.firstMatch.tap()
        }
        app.openBibleFilterGroup("cooked")
        app.buttons["bible-filter-option-notCooked"].tap(); app.buttons["bible-filter-option-cooked"].tap(); app.buttons["filters-done"].tap()
        XCTAssertEqual(rows.count + notCooked, total)
        app.buttons["bible-clear-filters"].tap(); XCTAssertEqual(rows.count, total)
        // The new Recipe is its own Dish in Food Bible, but an uncooked Dish is not in Grub Rank.
        XCTAssertTrue(rows.matching(NSPredicate(format: "label CONTAINS 'Uncooked Granita'")).firstMatch.exists)
        app.tabBars.buttons["Grub Rank"].tap()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Uncooked Granita'")).firstMatch.exists)
    }
}
