import XCTest

final class RecipeSocialUITests: StayGrubbyUITestCase {
    @MainActor func testSharedRecipeReaderHasNoOwnerControlsAndSavesAReference() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--social-review-feed", "--recipes-review", "--recipes-review-feed", "--test-light"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.tabBars.buttons["The Pass"].tap()
        let open = app.buttons["post-open-20000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(open.waitForExistence(timeout: 8)); open.tap()
        // The post page keeps the exact posted revision one tap away; View Recipe opens the latest version.
        XCTAssertTrue(app.buttons["post-recipe"].waitForExistence(timeout: 8))
        let recipe = app.buttons["post-recipe-as-posted"]
        for _ in 0..<4 { if recipe.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(recipe.waitForExistence(timeout: 8)); recipe.tap()
        XCTAssertTrue(app.staticTexts["shared-recipe-title"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["recipe-share-link"].exists)
        app.revealRecipeActions()
        XCTAssertTrue(app.buttons["recipe-send-friend"].waitForExistence(timeout:5))
        XCTAssertEqual(app.buttons["recipe-send-friend"].label,"Send Current Recipe to Sous Chefs")
        XCTAssertFalse(app.buttons["recipe-edit"].exists)
        XCTAssertFalse(app.buttons["recipe-history"].exists)
        XCTAssertFalse(app.buttons["recipe-link"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.55)).tap()
        XCTAssertTrue(app.buttons["recipe-send-friend"].waitForNonExistence(timeout:5))
        // Connected UI: no in-app copy. The current Recipe opens with Save (a reference), still not owned.
        let current = app.buttons["shared-recipe-open-current"]
        for _ in 0..<6 { if current.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(current.isHittable); current.tap()
        XCTAssertTrue(app.waitForRecipeReader(timeout: 8))
        XCTAssertTrue(app.buttons["recipe-make"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["recipe-fork"].exists, "No in-app copy action")
        // In this fixture the post's current Recipe is the viewer's own, so it offers no Save of itself.
        XCTAssertFalse(app.buttons["recipe-save"].exists)
    }
    /// A Dish without a Recipe shows no Recipe section at all, and Cancel publishes nothing.
    @MainActor func testComposerWithoutRecipeHasNoAttachmentAndCancelDoesNotPublish() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--recipes-review", "--test-dark"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15)); app.revealCreation(); app.buttons["new-dish"].tap()
        let name = app.textFields["dish-name"]; XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Recipe sharing check")
        app.buttons["Continue"].tap(); app.buttons["Liked it"].tap()
        let share = app.cookAction("share-with-friends"); XCTAssertTrue(share.waitForExistence(timeout: 15)); share.tap()
        XCTAssertTrue(app.buttons["social-share-publish"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.switches["post-include-recipe"].waitForExistence(timeout: 3), "No Recipe, no attachment section")
        XCTAssertFalse(app.descendants(matching: .any)["post-recipe-preview"].exists)
        app.buttons["Cancel"].tap(); XCTAssertTrue(share.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "social-share-success").firstMatch.exists)
    }
}
