import XCTest

/// Stage F: creation and linking around one Dish identity (FOOD_ARCHITECTURE §7).
final class StageFAddRecipeUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ extra: [String] = [], fixtures: Bool = true) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--test-reduce-motion"]
            + (fixtures ? ["--discovery-fixture", "--bible-review", "--stage4-review"] : []) + extra
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        return app
    }
    @MainActor private func reach(_ element: XCUIElement, _ app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), app.debugDescription)
        for _ in 0..<10 where !element.isHittable { app.swipeUp() }
    }
    @MainActor private func shot(_ name: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    @MainActor private func saveManualRecipe(_ title: String, _ app: XCUIApplication, replacing: Bool = false) {
        let field = app.textFields["recipe-edit-title"]; XCTAssertTrue(field.waitForExistence(timeout: 8))
        if replacing, let current = field.value as? String, !current.isEmpty {
            field.tap(); field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        } else { field.tap() }
        field.typeText(title); app.buttons["recipe-keyboard-done"].tap(); app.buttons["recipe-save"].tap()
    }

    @MainActor func testNewDishRecipeOffersRankNowAndRankedDishGetsItsRecipe() throws {
        let app = launch(["--test-light"])
        app.tabBars.buttons["Food Bible"].tap(); XCTAssertTrue(app.buttons["bible-add"].waitForExistence(timeout: 8))
        // One compact screen: New Dish + Recipe (Paste / Add Manually) or Add to a Ranked Dish.
        app.buttons["bible-add"].tap()
        XCTAssertTrue(app.buttons["bible-manual"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["bible-import"].exists && app.buttons["bible-ranked-dish"].exists)
        shot("F Food Bible add choices light", app)
        app.buttons["bible-manual"].tap(); saveManualRecipe("Stage F Soup", app)
        XCTAssertTrue(app.buttons["rank-prompt-rank"].waitForExistence(timeout: 10)); shot("F Rank now prompt light", app)
        app.buttons["rank-prompt-rank"].tap()
        XCTAssertTrue(app.navigationBars["Rank My Version"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["inherited-dish-name"].label, "Stage F Soup")
        app.buttons["Cancel"].tap()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-' AND label CONTAINS 'Stage F Soup'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))

        // Add to a Ranked Dish: only ranked Dishes without a Recipe are offered.
        app.buttons["bible-add"].tap(); XCTAssertTrue(app.buttons["bible-ranked-dish"].waitForExistence(timeout: 8))
        app.buttons["bible-ranked-dish"].tap()
        let dish = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'choose-dish-'")).firstMatch
        XCTAssertTrue(dish.waitForExistence(timeout: 8)); let dishName = dish.identifier.replacingOccurrences(of: "choose-dish-", with: ""); dish.tap()
        XCTAssertTrue(app.staticTexts["add-recipe-dish"].waitForExistence(timeout: 8)); XCTAssertEqual(app.staticTexts["add-recipe-dish"].label, dishName)
        app.buttons["dish-recipe-manual"].tap(); saveManualRecipe("Family method", app)
        XCTAssertFalse(app.buttons["rank-prompt-rank"].waitForExistence(timeout: 3), "An existing Dish is already ranked")
        let ranked = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-' AND label CONTAINS %@", dishName)).firstMatch
        XCTAssertTrue(ranked.waitForExistence(timeout: 10), "Food Bible shows the ranked Dish with its new Recipe")
    }

    @MainActor func testDishUsesExistingFoodBibleRecipeAsOneDish() throws {
        let app = launch(["--test-dark"])
        // An uncooked Food Bible Recipe…
        app.tabBars.buttons["Food Bible"].tap(); app.buttons["bible-add"].tap()
        XCTAssertTrue(app.buttons["bible-manual"].waitForExistence(timeout: 8)); app.buttons["bible-manual"].tap()
        saveManualRecipe("Grandma Stew Method", app); app.skipRankPrompt()
        // …becomes a ranked Dish's Recipe from Dish Detail.
        app.tabBars.buttons["Grub Rank"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        var opened = false
        for index in 0..<min(rows.count, 6) {
            rows.element(boundBy: index).tap(); XCTAssertTrue(app.buttons["cook-more-actions"].waitForExistence(timeout: 10))
            let add = app.buttons["dish-add-recipe"], view = app.buttons["dish-view-recipe"]
            for _ in 0..<8 where !(add.exists || view.exists) { app.swipeUp() }
            if add.exists { opened = true; break }
            app.navigationBars.buttons.firstMatch.tap()
        }
        XCTAssertTrue(opened, "A ranked Dish without a Recipe exists in the fixture")
        reach(app.buttons["dish-add-recipe"], app); app.buttons["dish-add-recipe"].tap()
        XCTAssertTrue(app.buttons["dish-recipe-existing"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["dish-recipe-manual"].exists && app.buttons["dish-recipe-import"].exists)
        app.buttons["dish-recipe-existing"].tap()
        let search = app.textFields["existing-recipe-search"]; XCTAssertTrue(search.waitForExistence(timeout: 8))
        search.tap(); search.typeText("Grandma"); XCTAssertTrue(app.buttons["existing-recipe-search-clear"].exists)
        let choice = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'existing-recipe-' AND label CONTAINS 'Grandma Stew'")).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 8)); shot("F Use a Food Bible Recipe dark", app); choice.tap()
        let confirm = app.buttons.matching(identifier: "existing-recipe-confirm").firstMatch; XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        XCTAssertTrue(app.buttons["dish-view-recipe"].waitForExistence(timeout: 10))
        app.buttons["dish-view-recipe"].tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 10)); XCTAssertEqual(app.staticTexts["recipe-title"].label, "Grandma Stew Method")
        XCTAssertFalse(app.descendants(matching: .any)["recipe-not-cooked"].exists)
        // The empty Recipe-only Dish is gone: Food Bible lists the Recipe once, under the ranked Dish.
        app.tabBars.buttons["Food Bible"].tap()
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-' AND label CONTAINS 'Grandma Stew'"))
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 10)); XCTAssertEqual(cards.count, 1)
    }

    @MainActor func testRankingANewDishOffersAddARecipe() throws {
        let app = launch(["--test-light"], fixtures: false)
        app.revealCreation(); app.buttons["new-dish"].tap()
        let name = app.textFields["dish-name"]; XCTAssertTrue(name.waitForExistence(timeout: 8)); name.tap(); name.typeText("Prompt Pasta\n")
        app.buttons["Continue"].tap(); XCTAssertTrue(app.buttons["Liked it"].waitForExistence(timeout: 8)); app.buttons["Liked it"].tap()
        let prompt = app.descendants(matching: .any)["recipe-prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 10)); shot("F Add a Recipe prompt light", app)
        XCTAssertTrue(app.buttons["ranking-result-close"].exists)
        app.buttons["recipe-prompt-add"].tap()
        XCTAssertTrue(app.buttons["dish-recipe-manual"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts["add-recipe-dish"].label, "Prompt Pasta")
        app.buttons["add-recipe-done"].tap()
        XCTAssertTrue(prompt.waitForNonExistence(timeout: 8), "The prompt closes after Add Recipe or Not Now")
        app.buttons["ranking-result-close"].tap()
    }
}
