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

    @MainActor func testCookAgainStartOffersTheDishRecipeOrWithout() throws {
        let app = launch(["--test-light"])
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        var withRecipe = false, withoutRecipe = false
        for index in 0..<min(rows.count, 6) where !(withRecipe && withoutRecipe) {
            rows.element(boundBy: index).tap(); XCTAssertTrue(app.buttons["cook-more-actions"].waitForExistence(timeout: 10))
            let view = app.buttons["dish-view-recipe"], add = app.buttons["dish-add-recipe"]
            for _ in 0..<8 where !(add.exists || view.exists) { app.swipeUp() }
            let hasRecipe = view.exists
            if (hasRecipe && !withRecipe) || (!hasRecipe && !withoutRecipe) {
                reach(app.buttons["detail-new-version"], app); app.buttons["detail-new-version"].tap()
                if hasRecipe {
                    // Cook Again on a Dish with a Recipe: choose the Recipe (exact revision) or not.
                    XCTAssertTrue(app.buttons["cook-again-recipe"].waitForExistence(timeout: 10)); XCTAssertTrue(app.buttons["cook-again-without"].exists)
                    shot("F Cook Again start light", app)
                    app.buttons["cook-again-recipe"].tap()
                    XCTAssertTrue(app.navigationBars["Rank My Version"].waitForExistence(timeout: 10))
                    XCTAssertTrue(app.staticTexts["inherited-dish-name"].exists, "The cook stays on this Dish")
                    withRecipe = true
                } else {
                    XCTAssertTrue(app.navigationBars["Cook Again"].waitForExistence(timeout: 10))
                    XCTAssertFalse(app.buttons["cook-again-recipe"].exists)
                    withoutRecipe = true
                }
                // The cook editor is grouped by owner.
                XCTAssertTrue(app.staticTexts["THIS DISH"].exists || app.staticTexts["This Dish"].exists)
                XCTAssertTrue(app.staticTexts["THIS COOK"].exists || app.staticTexts["This cook"].exists)
                app.buttons["Cancel"].tap()
            }
            app.navigationBars.buttons.firstMatch.tap()
        }
        XCTAssertTrue(withRecipe && withoutRecipe, "Fixture has Dishes with and without a Recipe")
    }

    @MainActor func testRecipeDietAsWrittenAndFoodBibleDietFilter() throws {
        let app = launch(["--test-dark"])
        app.tabBars.buttons["Food Bible"].tap(); app.buttons["bible-add"].tap()
        XCTAssertTrue(app.buttons["bible-manual"].waitForExistence(timeout: 8)); app.buttons["bible-manual"].tap()
        let field = app.textFields["recipe-edit-title"]; XCTAssertTrue(field.waitForExistence(timeout: 8)); field.tap(); field.typeText("Vegan Chili")
        app.buttons["recipe-keyboard-done"].tap()
        let details = app.buttons["Details & source"]
        for _ in 0..<12 where !details.isHittable { app.swipeUp() }
        details.tap()
        let diet = app.buttons["recipe-diet"]; reach(diet, app); diet.tap()
        XCTAssertTrue(app.buttons["filter-dietary-vegan"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["filter-dietary-halal"].exists, "Certification is never a Recipe property")
        app.buttons["filter-dietary-vegan"].tap(); app.buttons["dietary-done"].tap()
        XCTAssertTrue(diet.label.contains("Vegan"))
        app.buttons["recipe-save"].tap(); app.skipRankPrompt()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-' AND label CONTAINS 'Vegan Chili'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10)); card.tap()
        let info = app.staticTexts["recipe-diet-information"]; reach(info, app)
        XCTAssertTrue(info.label.contains("Vegan")); shot("F Recipe Diet as written dark", app)
        app.navigationBars.buttons.firstMatch.tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 8)); let total = rows.count
        app.openBibleFilterGroup("diet"); XCTAssertTrue(app.buttons["filter-dietary-vegan"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["filter-dietary-kosher"].exists)
        app.buttons["filter-dietary-vegan"].tap(); app.buttons["filters-done"].tap()
        XCTAssertTrue(rows.matching(NSPredicate(format: "label CONTAINS 'Vegan Chili'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertLessThan(rows.count, total)
        app.buttons["bible-clear-filters"].tap(); XCTAssertEqual(rows.count, total)
    }
}
