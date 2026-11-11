import XCTest

/// The Pass is shared Cook activity: a cook that has a photo is posted with it by default, and the post
/// shows it; Recipes never appear as Pass items (November 11, 2026).
final class PassPhotoUITests: StayGrubbyUITestCase {
    @MainActor func testPostingACookWithAPhotoShowsThePhotoOnThePass() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--discovery-fixture", "--social-review", "--social-review-ready", "--test-light", "--test-reduce-motion"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.showAllVersions()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Smoky Sunday'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), app.debugDescription); row.tap()
        let share = app.cookAction("share-with-friends")
        XCTAssertTrue(share.waitForExistence(timeout: 10)); share.tap()
        let toggle = app.switches["social-share-photo"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 8))
        XCTAssertEqual(toggle.value as? String, "1", "A cook with a photo is posted with it by default")
        let publish = app.buttons["social-share-publish"]
        for _ in 0..<5 where !publish.isHittable { app.swipeUp() }
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: publish)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 10), .completed, app.debugDescription)
        XCTAssertEqual(publish.label, "Post to The Pass")
        publish.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "social-share-success").firstMatch.waitForExistence(timeout: 10), app.debugDescription)
        app.buttons["social-share-done"].tap()
        app.tabBars.buttons["The Pass"].tap()
        XCTAssertTrue(app.navigationBars["The Pass"].waitForExistence(timeout: 8))
        // The review mock titles every post generically; the newest post is this share.
        let post = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'post-open-'")).firstMatch
        XCTAssertTrue(post.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue((post.value as? String ?? "").contains("Food photo"), "The posted cook carries its photo: \(post.value ?? "nil")")
        XCTAssertFalse(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'feed-recipe-'")).firstMatch.exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "The Pass post with photo"; shot.lifetime = .keepAlways; add(shot)
    }
}
