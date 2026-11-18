import XCTest

/// Connected Recipe sharing (November 16, 2026): the composer recognizes the Dish's own Recipe, a private
/// Recipe needs an explicit choice, posts link the live Recipe, and a Recipe can join an existing post.
final class ConnectedRecipeSharingUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ appearance: String) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--recipes-review",
                               "--discovery-fixture", "--bible-review", "--test-reduce-motion", appearance]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        return app
    }
    @MainActor private func shot(_ name: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    /// Food Bible → the Dish whose Recipe is "Braised Short Ribs with Polenta" → Post to The Pass.
    @MainActor private func openComposer(_ app: XCUIApplication) {
        app.tabBars.buttons["Food Bible"].tap()
        let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-' AND label CONTAINS 'Braised Short Ribs'")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        let tabs = app.segmentedControls["dish-tabs"]; XCTAssertTrue(tabs.waitForExistence(timeout: 10))
        tabs.buttons["Dish & Ranking"].tap()
        app.cookAction("share-with-friends").tap()
        XCTAssertTrue(app.navigationBars["Post to The Pass"].waitForExistence(timeout: 10))
    }
    /// Lists render rows lazily: scroll until the element exists and is hittable.
    @MainActor private func reach(_ element: XCUIElement, _ app: XCUIApplication) {
        _ = element.waitForExistence(timeout: 4)
        for _ in 0..<8 where !(element.exists && element.isHittable) { app.swipeUp(); _ = element.waitForExistence(timeout: 1) }
        XCTAssertTrue(element.exists, app.debugDescription)
    }

    @MainActor func testDishRecipeIsRecognizedPrivateNeedsExplicitShareAndPostLinksTheRecipe() throws {
        let app = launch("--test-light")
        openComposer(app)
        let preview = app.descendants(matching: .any)["post-recipe-preview"]
        reach(preview, app)
        XCTAssertTrue(preview.label.contains("Braised Short Ribs with Polenta"), preview.label)
        let toggle = app.switches["post-include-recipe"]
        reach(toggle, app)
        // The fixture Recipe is private: never preselected, and the control says it will be shared.
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertEqual(toggle.label, "Share Recipe with Sous Chefs")
        XCTAssertTrue(app.staticTexts["post-recipe-private-note"].exists)
        XCTAssertTrue(preview.label.contains("Private Recipe · not included"), "The composer states the Recipe's sharing at a glance")
        shot("Composer · private Recipe attachment", app)
        reach(toggle, app)
        XCTAssertTrue(toggle.waitUntilSettled()); toggle.tapSwitchControl()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: toggle)], timeout: 5), .completed)
        XCTAssertFalse(app.staticTexts["post-recipe-linked-note"].exists, "A private Recipe keeps its sharing note until posted")
        XCTAssertTrue(app.descendants(matching: .any)["post-recipe-preview"].label.contains("will be shared with your Sous Chefs"))
        let publish = app.buttons["social-share-publish"]; reach(publish, app); publish.tap()
        XCTAssertTrue(app.descendants(matching: .any)["social-share-success"].waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertFalse(app.buttons["social-add-recipe-to-post"].exists, "Already attached")
        app.buttons["social-share-done"].tap()
        // The Pass: the post links the Recipe; View Recipe opens its latest version, now shared with Sous Chefs.
        app.tabBars.buttons["The Pass"].tap()
        let recipe = app.buttons["post-recipe"]
        XCTAssertTrue(recipe.waitForExistence(timeout: 10)); reach(recipe, app); recipe.tap()
        XCTAssertTrue(app.waitForRecipeReader(timeout: 10))
        let shared = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Shared with current Sous Chefs'")).firstMatch
        reach(shared, app); XCTAssertTrue(shared.exists)
        shot("Linked Recipe opened from The Pass", app)
    }

    @MainActor func testRecipeCanJoinAnExistingPostWithoutDuplicatingIt() throws {
        let app = launch("--test-dark")
        openComposer(app)
        let toggle = app.switches["post-include-recipe"]; reach(toggle, app)
        XCTAssertEqual(toggle.value as? String, "0", "Posting without the Recipe")
        let publish = app.buttons["social-share-publish"]; reach(publish, app); publish.tap()
        XCTAssertTrue(app.descendants(matching: .any)["social-share-success"].waitForExistence(timeout: 15))
        let add = app.buttons["social-add-recipe-to-post"]; reach(add, app); add.tap()
        let addToggle = app.switches["post-include-recipe"]
        XCTAssertTrue(addToggle.waitForExistence(timeout: 10)); XCTAssertTrue(addToggle.waitUntilSettled()); addToggle.tapSwitchControl()
        let confirm = app.buttons["post-share-recipe"]; XCTAssertTrue(confirm.waitForExistence(timeout: 5)); XCTAssertTrue(confirm.isEnabled)
        shot("Add Recipe to an existing post", app)
        confirm.tap()
        XCTAssertTrue(add.waitForNonExistence(timeout: 10), "The same post now carries the Recipe")
        app.buttons["social-share-done"].tap()
        app.tabBars.buttons["The Pass"].tap()
        XCTAssertTrue(app.buttons["post-recipe"].waitForExistence(timeout: 10))
        let ownPosts = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'feed-post-'"))
        XCTAssertEqual(ownPosts.count, 1, "No duplicate post")
    }
}
