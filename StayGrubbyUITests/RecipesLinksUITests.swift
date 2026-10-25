import XCTest

final class RecipesLinksUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--recipes-review"] + extra
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15)); return app
    }
    @MainActor private func profile(_ app: XCUIApplication) {
        for _ in 0..<3 {
            app.tabBars.buttons["My Kitchen"].tap()
            if app.buttons["settings-open"].waitForExistence(timeout: 3) { return }
        }
        XCTAssertTrue(app.buttons["settings-open"].waitForExistence(timeout: 8), app.debugDescription)
    }
    @MainActor func testRecipeActionsDoNotExposeTickets() {
        let app = launch(["--test-light", "--bible-review", "--score-unlock-fixture", "10"])
        app.tabBars.buttons["Food Bible"].tap()
        XCTAssertTrue(app.textFields["bible-search"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["bible-tickets"].exists)
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 8)); rows.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["recipe-ticket"].exists)
        XCTAssertFalse(app.buttons["Save Ticket 🎟️"].exists)
        XCTAssertFalse(app.buttons["Remove Ticket"].exists)
    }
    @MainActor func testProfileLinkResolvesAndExistingFriendActionWorks() {
        let app = XCUIApplication(); continueAfterFailure = false
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--review-profile-url", "https://staygrubby.com/@new_cook"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.buttons["friend-action-request"].waitForExistence(timeout: 15)); app.buttons["friend-action-request"].tap()
        XCTAssertTrue(app.buttons["friend-action-cancel"].waitForExistence(timeout: 8))
    }
    @MainActor func testPrivateLinkCannotOpenProfile() {
        let app = XCUIApplication(); continueAfterFailure = false
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--profile-link-private", "--review-profile-url", "https://staygrubby.com/@new_cook"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.staticTexts["Kitchen unavailable"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["friend-action-request"].exists)
    }
    @MainActor func testRunItBackKeepsRecipeAndSocialOriginSeparate() {
        let app = launch(["--test-light", "--social-review-feed", "--recipes-review-feed"])
        app.tabBars.buttons["Grub List"].tap()
        let action = app.buttons["recreate-20000000-0000-0000-0000-000000000001"]
        for _ in 0..<5 { if action.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(action.waitForExistence(timeout: 8)); action.tap()
        XCTAssertTrue(app.buttons["View recipe"].waitForExistence(timeout: 8)); XCTAssertTrue(app.staticTexts["Run It Back from Friendly Cook’s cooking"].exists)
        app.buttons["shared-begin"].tap()
        XCTAssertTrue(app.textFields["dish-name"].waitForExistence(timeout: 8)); XCTAssertEqual(app.textFields["dish-name"].value as? String, "Harissa Chicken with Roasted Peppers")
        app.buttons["Continue"].tap(); XCTAssertTrue(app.buttons["Liked it"].waitForExistence(timeout: 5)); app.buttons["Liked it"].tap()
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 12)); XCTAssertFalse(app.staticTexts["result-score"].exists)
    }
    @MainActor func testOwnProfileLinkDoesNotOfferSelfFriendship() {
        let app = XCUIApplication(); continueAfterFailure = false
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--recipes-review", "--review-profile-url", "https://staygrubby.com/@review_cook"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.staticTexts["Your Kitchen"].waitForExistence(timeout: 15)); XCTAssertFalse(app.buttons["friend-action-request"].exists)
    }
    @MainActor func testKitchenShareAndSettingsSousChefsHierarchy() {
        let app = launch(["--test-light"]); profile(app)
        XCTAssertTrue(app.buttons["share-my-kitchen"].waitForExistence(timeout: 8)); app.buttons["share-my-kitchen"].tap()
        let copy = app.cells.matching(identifier: "actionGroupCell").matching(NSPredicate(format: "label == %@", "Copy")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 10), app.debugDescription)
        let close = app.buttons["Close"]
        if close.exists { close.tap() }
        else { app.otherElements["PopoverDismissRegion"].tap() }
        XCTAssertTrue(copy.waitForNonExistence(timeout: 8))
        app.buttons["friends-open"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["Find Sous Chefs"].waitForExistence(timeout: 8)); app.segmentedControls.buttons["Requests"].tap()
        XCTAssertTrue(app.buttons["friend-person-incoming_cook"].waitForExistence(timeout: 8))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["settings-open"].tap()
        XCTAssertTrue(app.buttons["Sent Requests"].waitForExistence(timeout: 8)); XCTAssertTrue(app.buttons["Blocked Accounts"].exists)
    }
}
