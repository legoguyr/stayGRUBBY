import XCTest

final class Stage4RecipeUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--discovery-fixture", "--bible-review", "--stage4-review", "--recipe-photo-review", "--test-reduce-motion"] + extra
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.tabBars.buttons["Food Bible"].tap()
        XCTAssertTrue(app.buttons["bible-add"].waitForExistence(timeout: 8)); return app
    }
    @MainActor private func recipe(_ title: String, _ app: XCUIApplication) {
        let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-' AND label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 8), app.debugDescription); entry.press(forDuration: 0.2)
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 8))
    }
    @MainActor private func action(_ id: String, _ app: XCUIApplication) {
        let menu = app.buttons["recipe-actions"]; XCTAssertTrue(menu.waitForExistence(timeout: 5)); menu.tap()
        XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 5), app.debugDescription); app.buttons[id].press(forDuration: 0.2)
    }
    @MainActor private func shot(_ name: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    @MainActor func testFiltersComposeResetAndDirectionalSorting() throws {
        let app = launch(["--test-light"])
        app.buttons["bible-filter-course"].tap()
        XCTAssertTrue(app.buttons["bible-filter-option-soup"].waitForExistence(timeout: 5)); app.buttons["bible-filter-option-soup"].tap(); app.buttons["filters-done"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-'"))
        XCTAssertEqual(rows.count, 1); XCTAssertTrue(rows.firstMatch.label.contains("Lemon Soup"))
        app.buttons["bible-filter-contains"].tap(); app.buttons["bible-contains-milk"].tap(); app.buttons["filters-done"].tap()
        XCTAssertTrue(app.staticTexts["No matching recipes"].waitForExistence(timeout: 5))
        app.buttons["bible-clear-filters"].tap(); XCTAssertEqual(rows.count, 2)
        let search = app.textFields["bible-search"]; search.tap(); search.typeText("lemon\n")
        XCTAssertEqual(rows.count, 1); app.buttons["bible-search-clear"].tap()
        for label in ["A–Z", "Z–A", "Newest Added", "Oldest Added"] {
            app.buttons["bible-sort"].press(forDuration: 0.2)
            XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 5)); app.buttons[label].tap()
            XCTAssertTrue(app.buttons["bible-sort"].label.contains(label))
        }
        shot("Stage 4 Food Bible browse light", app)
    }
    @MainActor func testUnitsServingsAndCompactActionsLeaveCanonicalRecipeIntact() throws {
        let app = launch(["--test-dark"]); recipe("Braised Short Ribs", app)
        XCTAssertFalse(app.buttons["recipe-units"].exists)
        XCTAssertFalse(app.buttons["Metric"].exists)
        let servings = app.steppers["recipe-servings"]
        for _ in 0..<6 { if servings.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(servings.buttons["recipe-servings-Increment"].exists, app.debugDescription); servings.buttons["recipe-servings-Increment"].tap()
        XCTAssertEqual(servings.value as? String, "5")
        shot("V1 written quantities and serving scaling dark", app)
        action("recipe-history", app)
        XCTAssertTrue(app.navigationBars["Version History"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["recipe-version-1"].exists)
        app.buttons["Done"].tap(); action("recipe-edit", app)
        let yield = app.textFields["recipe-yield"]
        XCTAssertTrue(yield.waitForExistence(timeout: 5)); XCTAssertEqual(yield.value as? String, "4 servings")
    }
    @MainActor func testSpecificVersionLinkChangeUnlinkAndPhotoOwnership() throws {
        let app = launch(["--test-light"]); recipe("Braised Short Ribs", app)
        let hero = app.descendants(matching: .any).matching(identifier: "recipe-hero").firstMatch
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Recipe photo'"), object: hero)], timeout: 8), .completed)
        action("recipe-link", app)
        let versions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'choose-cook-'"))
        XCTAssertTrue(versions.firstMatch.waitForExistence(timeout: 5)); XCTAssertGreaterThanOrEqual(versions.count, 2); versions.firstMatch.tap()
        XCTAssertTrue(app.buttons["recipe-linked-cook"].waitForExistence(timeout: 8))
        XCTAssertEqual(hero.value as? String, "Recipe photo")
        action("recipe-link", app)
        XCTAssertGreaterThanOrEqual(versions.count, 2); versions.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["recipe-linked-cook"].waitForExistence(timeout: 8))
        action("recipe-detach", app); app.buttons["Unlink"].tap()
        XCTAssertTrue(app.buttons["recipe-linked-cook"].waitForNonExistence(timeout: 8))
        XCTAssertEqual(hero.value as? String, "Recipe photo")
        shot("Stage 4 owned photo survives unlink", app)
    }
    @MainActor func testAccessibleRecipeMenuAndFilters() throws {
        let app = launch(["--test-light", "--test-large-type"])
        app.buttons["bible-filter-course"].tap(); XCTAssertTrue(app.buttons["bible-filter-option-soup"].waitForExistence(timeout: 5))
        app.buttons["bible-filter-option-soup"].tap(); app.buttons["filters-done"].tap()
        recipe("Lemon Soup", app); action("recipe-edit", app)
        XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout: 5))
        shot("Stage 4 accessible Recipe editor", app)
    }
    @MainActor func testExactCookPhotoFallbackAndSharedSourceControls() throws {
        let app = launch(["--test-dark"]); recipe("Braised Short Ribs", app)
        action("recipe-edit", app)
        XCTAssertTrue(app.buttons["recipe-photo-remove"].waitForExistence(timeout: 5)); app.buttons["recipe-photo-remove"].tap(); app.buttons["recipe-save"].tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 8))
        let hero = app.descendants(matching: .any).matching(identifier: "recipe-hero").firstMatch
        func photo(_ value: String) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: hero)], timeout: 8), .completed)
        }
        photo("Dish family photo")
        for (version, expected) in [("Smoky Sunday", "Linked cook photo"), ("Golden sear", "StayGrubby placeholder")] {
            action("recipe-link", app)
            XCTAssertTrue(app.navigationBars["Link a Dish"].waitForExistence(timeout: 5))
            let choice = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'choose-cook-' AND label CONTAINS %@", version)).firstMatch
            XCTAssertTrue(choice.waitForExistence(timeout: 5)); choice.tap()
            XCTAssertTrue(app.buttons["recipe-linked-cook"].waitForExistence(timeout: 8)); photo(expected)
        }
        action("recipe-edit", app)
        XCTAssertTrue(app.buttons["recipe-photo-fixture"].waitForExistence(timeout: 5)); app.buttons["recipe-photo-fixture"].tap()
        let details = app.buttons["Details & source"]
        for _ in 0..<12 { if details.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(details.isHittable); details.tap()
        let cuisine = app.buttons["recipe-cuisine"]
        for _ in 0..<4 { if cuisine.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(cuisine.isHittable); cuisine.tap()
        XCTAssertTrue(app.buttons["cuisine-clear"].waitForExistence(timeout: 5)); app.buttons["cuisine-clear"].tap()
        let source = app.textFields["recipe-source-name"]
        for _ in 0..<4 { if source.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(source.isHittable); XCTAssertEqual(source.value as? String, "The Home Cookbook")
        source.tap(); source.typeText(" notes"); app.buttons["recipe-keyboard-done"].tap(); app.buttons["recipe-save"].tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 8)); photo("Recipe photo")
        shot("Stage 4 exact cook fallback and independent Recipe replacement", app)
    }

    @MainActor func testOwnerCorrectionsReaderAndRankMyVersion() throws {
        let app = launch(["--test-dark", "--test-large-type"]); recipe("Braised Short Ribs", app)
        let attribution = app.staticTexts["recipe-attribution"], make = app.buttons["recipe-make"]
        XCTAssertEqual(attribution.label, "Created by Fixture Author"); XCTAssertLessThan(attribution.frame.minY, make.frame.minY)
        XCTAssertTrue(make.label.contains("Rank My Version"))
        let allergens = app.descendants(matching:.any).matching(identifier:"recipe-allergen-information").firstMatch
        XCTAssertGreaterThan(allergens.frame.minY, app.staticTexts["recipe-method-heading"].frame.minY)
        XCTAssertFalse(app.staticTexts["Servings and times may include estimates. Adjust for your kitchen."].exists)
        for _ in 0..<6 { if make.isHittable && make.frame.maxY < app.tabBars.firstMatch.frame.minY { break }; app.swipeUp() }
        make.tap(); XCTAssertTrue(app.navigationBars["New Version"].waitForExistence(timeout:8))
        XCTAssertTrue(app.staticTexts["inherited-dish-name"].waitForExistence(timeout:5)); XCTAssertEqual(app.staticTexts["inherited-dish-name"].label,"Braised Short Ribs with Polenta")
        app.buttons["Cancel"].tap(); XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8))
        app.revealRecipeActions(); XCTAssertEqual(app.buttons["recipe-link"].label,"Link a Dish"); app.buttons["recipe-link"].tap()
        XCTAssertTrue(app.navigationBars["Link a Dish"].waitForExistence(timeout:5))
        let choices = app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'choose-cook-'"))
        XCTAssertGreaterThanOrEqual(choices.count,2); XCTAssertFalse(app.buttons["choose-dish-Braised Short Ribs with Polenta"].exists)
        let search = app.textFields["parent-dish-search"]; search.tap(); search.typeText("Sea Bass\n")
        XCTAssertEqual(choices.count,1); XCTAssertTrue(choices.firstMatch.label.contains("Sea Bass"))
        app.buttons["parent-dish-search-clear"].tap(); search.tap(); search.typeText("Golden sear\n")
        XCTAssertEqual(choices.count,1); XCTAssertTrue(choices.firstMatch.label.contains("Braised Short Ribs")); XCTAssertTrue(choices.firstMatch.label.contains("Golden sear"))
        shot("Stage 4 owner correction flat version selector",app)
        choices.firstMatch.tap(); XCTAssertTrue(app.buttons["recipe-linked-cook"].waitForExistence(timeout:8))
    }

}
