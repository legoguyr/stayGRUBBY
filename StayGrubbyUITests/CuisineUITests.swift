import XCTest

final class CuisineUITests: StayGrubbyUITestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func reach(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<7 {
            let query = String(describing: element)
            let isRootField = ["dish-cuisine", "dish-source-type", "dish-name"].contains { query.contains($0) }
            if isRootField ? app.cookingFieldIsVisible(element) : (element.exists && element.isHittable) { return }
            if isRootField { app.scrollCookingFormToward(element) } else { app.swipeUp() }
        }
        XCTFail("Cuisine control could not be reached: \(element)")
    }
    /// A lone top Dish renders as the tall Signature hero; tap its upper area (its centre may sit under the tab bar).
    @MainActor private func openDish(_ row: XCUIElement, _ app: XCUIApplication) {
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        // Clearing filters swaps the row for the hero; let it settle, then retry a missed tap.
        for _ in 0..<3 {
            Thread.sleep(forTimeInterval: 0.8)
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
            if app.buttons["cook-more-actions"].waitForExistence(timeout: 4) { return }
        }
        XCTAssertTrue(app.buttons["cook-more-actions"].waitForExistence(timeout: 5), "row \(row.frame) app \(app.frame) hittable \(row.isHittable)")
    }
    @MainActor private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        // Read the query description, not the element: Cuisine only exists once Details is open.
        let query = String(describing: element)
        if query.contains("dish-cuisine") { app.openCookingDetails(); element.press(forDuration: 0.2); return }
        if query.contains("save-cook-metadata") || query.contains("Continue") { app.closeCookingDetails() }
        reach(element, in: app); element.tap()
    }
    @MainActor private func select(_ text: String, id: String, in app: XCUIApplication) {
        let search = app.textFields["cuisine-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText(text)
        let option = app.buttons[id]
        XCTAssertTrue(option.waitForExistence(timeout: 5)); option.tap()
    }
    @MainActor private func saveEdit(in app: XCUIApplication) {
        let save = app.buttons["save-cook-metadata"]
        for _ in 0..<2 {
            tap(save, in: app)
            if app.buttons["cook-more-actions"].waitForExistence(timeout: 5) && !save.exists { return }
        }
        XCTFail("Edit did not save")
    }
    @MainActor func testNewEditCustomRemovalPersistenceAndRankingFilter() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--test-dark"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.revealCreation(); app.buttons["new-dish"].tap()
        let name = app.textFields["dish-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Cuisine Soup\n")
        tap(app.buttons["dish-cuisine"], in: app)
        select(" italian ", id: "cuisine-option-italian", in: app)
        XCTAssertTrue(app.buttons["dish-cuisine"].label.contains("Italian"))
        tap(app.buttons["Continue"], in: app); tap(app.buttons["Liked it"], in: app)
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 15))
        app.buttons["ranking-result-close"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Cuisine Soup'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let globalLabel = row.label
        app.openRankingFilterGroup("cuisine")
        select("Italian", id: "cuisine-option-italian", in: app); app.closeRankingFilters()
        XCTAssertTrue(row.waitForExistence(timeout: 5)); XCTAssertEqual(row.label, globalLabel)
        app.buttons["clear-filters"].tap()
        openDish(row, app); app.cookAction("detail-edit-cook").tap()
        tap(app.buttons["dish-cuisine"], in: app)
        select("Basque Home Cooking", id: "cuisine-add", in: app)
        XCTAssertTrue(app.buttons["dish-cuisine"].label.contains("Basque Home Cooking"))
        saveEdit(in: app)
        app.terminate(); app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.openRankingFilterGroup("cuisine")
        select("Basque", id: "cuisine-option-custom:basque home cooking", in: app); app.closeRankingFilters()
        XCTAssertTrue(row.waitForExistence(timeout: 5)); XCTAssertEqual(row.label, globalLabel)
        app.buttons["clear-filters"].tap()
        app.openRankingFilterGroup("cuisine")
        select("Italian", id: "cuisine-option-italian", in: app); app.closeRankingFilters()
        XCTAssertTrue(app.staticTexts["No filter matches"].waitForExistence(timeout: 5))
        XCTAssertFalse(row.exists)
        app.buttons["clear-filters"].tap()
        openDish(row, app); app.cookAction("detail-edit-cook").tap()
        tap(app.buttons["dish-cuisine"], in: app)
        let search = app.textFields["cuisine-search"]
        search.tap(); search.typeText(" BASQUE   HOME-COOKING ")
        XCTAssertTrue(app.buttons["cuisine-option-custom:basque home cooking"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["cuisine-add"].exists)
        app.buttons["cuisine-clear"].tap()
        saveEdit(in: app)
        app.cookAction("detail-edit-cook").tap()
        // Cuisine lives in Details ("This Dish").
        app.openCookingDetails()
        XCTAssertTrue(app.buttons["dish-cuisine"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["dish-cuisine"].label.contains("None"))
        app.closeCookingDetails(); app.buttons["Cancel"].tap()
    }

    @MainActor func testLightLargeTypePickerSelectionAndCancelAreOptional() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--test-light", "--test-large-type"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.revealCreation(); app.buttons["new-dish"].tap()
        tap(app.buttons["dish-cuisine"], in: app)
        XCTAssertTrue(app.buttons["cuisine-option-american"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Cuisine light accessibility size"; shot.lifetime = .keepAlways; add(shot)
        select("Mediterranian", id: "cuisine-option-mediterranean", in: app)
        XCTAssertTrue(app.buttons["dish-cuisine"].label.contains("Mediterranean"))
        tap(app.buttons["dish-cuisine"], in: app)
        app.buttons["cuisine-clear"].tap()
        XCTAssertTrue(app.buttons["dish-cuisine"].label.contains("None"))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["ranking-empty-title"].waitForExistence(timeout: 5))
    }
}
