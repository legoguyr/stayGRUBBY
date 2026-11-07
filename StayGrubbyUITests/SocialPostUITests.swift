import XCTest

final class SocialPostUITests: StayGrubbyUITestCase {
    @MainActor func testCookingStaysPrivateUntilExplicitPublishAndLockedScoreIsOmitted() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--test-dark"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15)); app.revealCreation(); app.buttons["new-dish"].tap()
        let name = app.textFields["dish-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Private Social Soup")
        app.buttons["Continue"].tap(); app.buttons["Liked it"].tap()
        let share = app.cookAction("share-with-friends")
        XCTAssertTrue(share.waitForExistence(timeout: 15))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "social-share-success").firstMatch.exists)
        share.tap()
        XCTAssertTrue(app.staticTexts["social-share-score-locked"].waitForExistence(timeout: 5))
        let firstPublish = app.buttons["social-share-publish"]
        for _ in 0..<5 where !firstPublish.isHittable { app.swipeUp() }
        XCTAssertTrue(firstPublish.waitForExistence(timeout: 8), app.debugDescription)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(share.waitForExistence(timeout: 5)); share.tap()
        let publish = app.buttons["social-share-publish"]
        for _ in 0..<5 where !publish.isHittable { app.swipeUp() }
        XCTAssertTrue(publish.waitForExistence(timeout: 8), app.debugDescription)
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: publish)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 8), .completed, app.debugDescription)
        publish.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "social-share-success").firstMatch.waitForExistence(timeout: 10)); app.buttons["social-share-done"].tap()
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 5)); app.buttons["ranking-result-close"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Private Social Soup'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); XCTAssertTrue(row.label.contains("score locked"))
        row.tap()
        let shareAgain = app.cookAction("share-with-friends")
        XCTAssertTrue(shareAgain.waitForExistence(timeout: 5))
        shareAgain.tap()
        XCTAssertTrue(app.staticTexts["Already Shared"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["social-share-publish"].exists)
        XCTAssertTrue(app.buttons["View Post"].exists)
    }
}
