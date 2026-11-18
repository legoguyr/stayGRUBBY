import XCTest

/// One Public Description (owner decision, November 18, 2026): the composer's description is the Dish's
/// Public Description, and editing the Dish's description updates its existing post's caption.
final class PublicDescriptionUITests: StayGrubbyUITestCase {
    @MainActor func testComposerAndDishEditKeepOnePublicDescription() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--test-light", "--test-reduce-motion"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15)); app.revealCreation(); app.buttons["new-dish"].tap()
        let name = app.textFields["dish-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Caption Soup")
        app.buttons["Continue"].tap(); app.buttons["Liked it"].tap()
        let share = app.cookAction("share-with-friends"); XCTAssertTrue(share.waitForExistence(timeout: 15)); share.tap()

        // The composer's field is the Dish's Public Description.
        let field = app.textViews["post-description-input"].exists ? app.textViews["post-description-input"] : app.textFields["post-description-input"]
        for _ in 0..<5 where !(field.exists && field.isHittable) { app.swipeUp() }
        XCTAssertTrue(field.waitForExistence(timeout: 8)); field.tap(); field.typeText("Bright and lemony")
        let publish = app.buttons["social-share-publish"]
        for _ in 0..<5 where !publish.isHittable { app.swipeUp() }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: publish)], timeout: 8), .completed)
        publish.tap()
        XCTAssertTrue(app.descendants(matching: .any)["social-share-success"].waitForExistence(timeout: 10)); app.buttons["social-share-done"].tap()
        app.buttons["ranking-result-close"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Caption Soup'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8)); row.tap()
        XCTAssertTrue(app.staticTexts["dish-public-description"].waitForExistence(timeout: 8), "Posting saved the description to the Dish")
        XCTAssertEqual(app.staticTexts["dish-public-description"].label, "Bright and lemony")

        // Editing the Dish's Public Description updates the existing post's caption.
        app.buttons["cook-more-actions"].tap(); app.buttons["dish-text-edit"].tap()
        let pub = app.descendants(matching: .any).matching(identifier: "dish-text-public").firstMatch
        // Place the cursor after the existing text, then replace it.
        XCTAssertTrue(pub.waitForExistence(timeout: 8)); pub.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        pub.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Bright and lemony".count)); pub.typeText("Smoky and lemony")
        app.buttons["dish-text-save"].tap()
        XCTAssertTrue(app.buttons["cook-more-actions"].waitForExistence(timeout: 8))
        let again = app.cookAction("share-with-friends"); again.tap()
        XCTAssertTrue(app.buttons["View Post"].waitForExistence(timeout: 8)); app.buttons["View Post"].tap()
        let caption = app.scrollViews["dish-details"].staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'post-description-'")).firstMatch
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Smoky and lemony'"), object: caption)
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 10), .completed, "The post's caption is the Dish's Public Description")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Caption follows the Dish Public Description"; shot.lifetime = .keepAlways; add(shot)
    }
}
