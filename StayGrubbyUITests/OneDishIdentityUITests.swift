import XCTest

/// One canonical Dish universe (FOOD_ARCHITECTURE §3.4): a Recipe created and ranked in Food Bible as
/// Dish A, and the same real-world Dish ranked separately as Dish B, become one Dish when combined.
final class OneDishIdentityUITests: StayGrubbyUITestCase {
    @MainActor func testRankedRecipeDishCombinesIntoTheRankedDish() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--test-light", "--test-reduce-motion"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        // Dish B: ranked in Grub Rank, no Recipe.
        app.revealCreation(); app.buttons["new-dish"].tap()
        let name = app.textFields["dish-name"]; XCTAssertTrue(name.waitForExistence(timeout: 8)); name.tap(); name.typeText("Shakshuka\n")
        app.buttons["Continue"].tap(); XCTAssertTrue(app.buttons["Liked it"].waitForExistence(timeout: 8)); app.buttons["Liked it"].tap()
        XCTAssertTrue(app.buttons["recipe-prompt-not-now"].waitForExistence(timeout: 10)); app.buttons["recipe-prompt-not-now"].tap()
        app.buttons["ranking-result-close"].tap()
        // Dish A: the same Dish's Recipe made in Food Bible, then ranked (Rank Now) on its own.
        app.tabBars.buttons["Food Bible"].tap(); app.buttons["bible-add"].tap()
        XCTAssertTrue(app.buttons["bible-manual"].waitForExistence(timeout: 8)); app.buttons["bible-manual"].tap()
        let title = app.textFields["recipe-edit-title"]; XCTAssertTrue(title.waitForExistence(timeout: 8)); title.tap(); title.typeText("Shakshuka Method")
        app.buttons["recipe-keyboard-done"].tap(); app.buttons["recipe-save"].tap()
        XCTAssertTrue(app.buttons["rank-prompt-rank"].waitForExistence(timeout: 10)); app.buttons["rank-prompt-rank"].tap()
        XCTAssertTrue(app.navigationBars["Rank My Version"].waitForExistence(timeout: 10))
        app.buttons["Continue"].tap(); XCTAssertTrue(app.buttons["Liked it"].waitForExistence(timeout: 8)); app.buttons["Liked it"].tap()
        let prefer = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Prefer'")).firstMatch
        if prefer.waitForExistence(timeout: 8) { prefer.tap() }
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 15)); app.buttons["ranking-result-close"].tap()
        XCTAssertTrue(app.buttons["rank-prompt-rank"].waitForNonExistence(timeout: 10), "The Add Recipe flow closes after ranking")
        XCTAssertTrue(app.buttons["bible-add"].waitForExistence(timeout: 10))
        // Two Dishes now exist for one real-world Dish.
        app.tabBars.buttons["Grub Rank"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10)); XCTAssertEqual(rows.count, 2)
        // Combine: on Dish B, use the Food Bible Recipe whose Dish A has a cook.
        rows.matching(NSPredicate(format: "label CONTAINS 'Shakshuka,' OR label ENDSWITH 'Shakshuka'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["cook-more-actions"].waitForExistence(timeout: 10))
        let addRecipe = app.buttons["dish-add-recipe"]; for _ in 0..<8 where !addRecipe.exists { app.swipeUp() }
        XCTAssertTrue(addRecipe.waitForExistence(timeout: 10)); addRecipe.tap()
        XCTAssertTrue(app.buttons["dish-recipe-existing"].waitForExistence(timeout: 8)); app.buttons["dish-recipe-existing"].tap()
        let choice = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'existing-recipe-' AND label CONTAINS 'Shakshuka Method'")).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 10)); XCTAssertTrue(choice.label.contains("1 cook"), choice.label)
        choice.tap()
        let confirm = app.buttons.matching(identifier: "existing-recipe-confirm").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); XCTAssertEqual(confirm.label, "Combine Dishes"); confirm.tap()
        // One Dish: both cooks, its Recipe, and Dish A is gone.
        XCTAssertTrue(app.buttons["dish-view-recipe"].waitForExistence(timeout: 10))
        let cooks = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'version-row-'"))
        for _ in 0..<8 where cooks.count < 2 { app.swipeUp() }
        XCTAssertEqual(cooks.count, 2)
        app.navigationBars.buttons.firstMatch.tap()
        app.showAllVersions()
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10)); XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.matching(NSPredicate(format: "label CONTAINS 'Shakshuka Method'")).count, 0, "No second Dish named after the Recipe remains")
        app.tabBars.buttons["Food Bible"].tap()
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-'"))
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 10)); XCTAssertEqual(cards.count, 1)
        XCTAssertTrue(cards.firstMatch.label.contains("Shakshuka"))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "One Dish after combining"; shot.lifetime = .keepAlways; add(shot)
    }
}
