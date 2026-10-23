import XCTest

final class FoodBibleUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--recipes-review"] + extra
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.tabBars.buttons["Food Bible"].tap(); XCTAssertTrue(app.buttons["bible-tickets"].waitForExistence(timeout: 8)); return app
    }
    @MainActor private func reach(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<14 {
            let frame = element.frame
            let top: CGFloat = 150
            let bottom: CGFloat = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY - 30 : app.frame.maxY - 110
            if element.exists && element.isHittable && frame.minY >= top && frame.maxY <= bottom { return }
            let delta: CGFloat
            if frame.height > 0 { delta = max(-160, min(160, (top + bottom) / 2 - frame.midY)) }
            else { delta = 140 }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: (top + bottom) / 2))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)), withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTAssertTrue(element.exists && element.isHittable, app.debugDescription)
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor func testEmptyCookbookAndSeparateTickets() {
        let app = launch(["--test-light"])
        XCTAssertTrue(app.otherElements["bible-empty"].waitForExistence(timeout: 8) || app.staticTexts["Your recipes will live here."].exists)
        XCTAssertFalse(app.segmentedControls["recipe-library-mode"].exists)
        capture(app, "Food Bible empty · light")
        app.buttons["bible-tickets"].tap(); XCTAssertTrue(app.staticTexts["tickets-empty"].waitForExistence(timeout: 8))
        capture(app, "Tickets Want to Cook · light")
    }
    @MainActor func testCookbookSearchFiltersMultiComponentReaderAndExistingVersion() {
        let app = launch(["--test-dark", "--bible-review", "--score-unlock-fixture", "10"])
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-'")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-'")).count, 2)
        capture(app, "Cookbook photo and placeholder · dark")
        let search = app.textFields["bible-search"]; search.tap(); search.typeText("Braised")
        app.swipeUp(); XCTAssertTrue(app.staticTexts["Braised Short Ribs with Polenta"].waitForExistence(timeout: 8))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 8)); capture(app, "Recipe linked Dish photography · dark")
        reach(app.staticTexts["Short rib"], app: app); XCTAssertTrue(app.staticTexts["Short rib"].exists)
        reach(app.staticTexts["Polenta"], app: app); XCTAssertTrue(app.staticTexts["1 cup cornmeal"].exists)
        capture(app, "Recipe components · dark")
        reach(app.buttons["recipe-make"], app: app); app.buttons["recipe-make"].tap()
        XCTAssertTrue(app.navigationBars["New Version"].waitForExistence(timeout: 8))
        app.buttons["Cancel"].tap(); XCTAssertTrue(app.buttons["recipe-make"].waitForExistence(timeout: 8))
    }
    @MainActor func testAddRecipeToSameDishEditAndDetachPreservesCook() {
        let app = launch(["--test-light", "--score-unlock-fixture", "1"])
        app.buttons["bible-add"].tap(); XCTAssertTrue(app.buttons["Matzo Ball Soup"].waitForExistence(timeout: 8)); app.buttons["Matzo Ball Soup"].tap()
        let add = app.buttons["dish-add-recipe"]; XCTAssertTrue(add.waitForExistence(timeout: 8)); add.tap()
        XCTAssertEqual(app.textFields["recipe-edit-title"].value as? String, "Matzo Ball Soup")
        app.buttons["recipe-add-ingredient"].tap()
        let ingredient = app.textFields["recipe-ingredient-name"]; XCTAssertTrue(ingredient.waitForExistence(timeout: 5)); ingredient.tap(); ingredient.typeText("stock")
        reach(app.buttons["recipe-add-step"], app: app); app.buttons["recipe-add-step"].tap()
        let step = app.textFields["recipe-step-text"]; reach(step, app: app); step.tap(); step.typeText("Simmer gently")
        capture(app, "Single component manual recipe editor · light")
        app.buttons["recipe-save"].tap(); XCTAssertTrue(app.buttons["dish-view-recipe"].waitForExistence(timeout: 8))
        app.buttons["Done"].tap()
        let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-'")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 8)); entry.tap()
        reach(app.buttons["recipe-edit"], app: app); app.buttons["recipe-edit"].tap()
        let title = app.textFields["recipe-edit-title"]; XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText(" Sunday")
        app.buttons["recipe-save"].tap(); XCTAssertTrue(app.staticTexts["Matzo Ball Soup Sunday"].waitForExistence(timeout: 8))
        reach(app.buttons["recipe-detach"], app: app); app.buttons["recipe-detach"].tap()
        let confirm = app.sheets.buttons["Remove Recipe from Dish"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        XCTAssertTrue(app.staticTexts["Your recipes will live here."].waitForExistence(timeout: 8))
        app.tabBars.buttons["Grub Rank"].tap(); XCTAssertTrue(app.staticTexts["Matzo Ball Soup"].waitForExistence(timeout: 8)); XCTAssertFalse(app.staticTexts["Matzo Ball Soup Sunday"].exists)
    }
    @MainActor func testLargeTypeSimpleReaderAndComponentEditorControls() {
        let app = launch(["--test-light", "--test-large-type", "--test-reduce-motion", "--bible-review", "--score-unlock-fixture", "10"])
        let search = app.textFields["bible-search"]; search.tap(); search.typeText("Lemon")
        app.swipeUp()
        let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-'")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 8)); reach(entry, app: app); entry.tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 8)); capture(app, "Simple recipe · accessibility portrait")
        reach(app.buttons["recipe-edit"], app: app); app.buttons["recipe-edit"].tap()
        let add = app.buttons["recipe-add-component"]; reach(add, app: app); add.tap()
        let names = app.textFields.matching(identifier: "Component name · optional")
        XCTAssertTrue(names.firstMatch.waitForExistence(timeout: 5)); reach(names.element(boundBy: names.count - 1), app: app); names.element(boundBy: names.count - 1).tap(); names.element(boundBy: names.count - 1).typeText("Garnish")
        capture(app, "Multi-component editor · accessibility portrait")
        app.buttons["Cancel"].tap(); XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Garnish"].exists)
    }
}
