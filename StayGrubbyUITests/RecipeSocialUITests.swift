import XCTest

final class RecipeSocialUITests: StayGrubbyUITestCase {
    @MainActor func testSharedRecipeReaderHasNoOwnerControlsAndSavesIndependentCopy() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--social-review-feed", "--recipes-review", "--recipes-review-feed", "--test-light"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.tabBars.buttons["Grub List"].tap()
        let open = app.buttons["post-open-20000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(open.waitForExistence(timeout: 8)); open.tap()
        let recipe = app.buttons["post-recipe"]
        for _ in 0..<4 { if recipe.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(recipe.waitForExistence(timeout: 8)); recipe.tap()
        XCTAssertTrue(app.staticTexts["shared-recipe-title"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["recipe-edit"].exists)
        XCTAssertFalse(app.buttons["recipe-history"].exists)
        XCTAssertFalse(app.buttons["recipe-link"].exists)
        let fork = app.buttons["shared-recipe-fork"]
        for _ in 0..<6 { if fork.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(fork.isHittable); fork.tap()
        app.revealRecipeActions(); XCTAssertTrue(app.buttons["recipe-edit"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["recipe-title"].exists)
    }
    @MainActor func testComposerRecipeChoiceStartsOffAndCancelDoesNotPublish() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--recipes-review", "--test-dark"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15)); app.revealCreation(); app.buttons["new-dish"].tap()
        let name = app.textFields["dish-name"]; XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Recipe sharing check")
        app.buttons["Continue"].tap(); app.buttons["Liked it"].tap()
        let share = app.buttons["share-with-friends"]; XCTAssertTrue(share.waitForExistence(timeout: 15)); share.tap()
        let toggle = app.switches["post-include-recipe"]
        for _ in 0..<4 { if toggle.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(toggle.waitForExistence(timeout: 8)); XCTAssertEqual(toggle.value as? String, "0")
        let control = toggle.switches.firstMatch
        XCTAssertTrue(control.exists); XCTAssertTrue(control.isHittable); control.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed, app.debugDescription)
        app.buttons["Cancel"].tap(); XCTAssertTrue(share.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "social-share-success").firstMatch.exists)
    }
}
