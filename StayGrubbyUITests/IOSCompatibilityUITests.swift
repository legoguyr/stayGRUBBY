import XCTest

final class IOSCompatibilityUITests: StayGrubbyUITestCase {
    @MainActor func testFourTabsRecipeSocialKitchenAndSettings() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--recipes-review", "--stage5-review", "--social-review-feed", "--score-unlock-fixture", "10", "--test-light"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15)); XCTAssertEqual(app.tabBars.buttons.count, 4)
        app.tabBars.buttons["Grub List"].tap()
        XCTAssertTrue(app.buttons["post-open-20000000-0000-0000-0000-000000000001"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Food Bible"].tap()
        XCTAssertTrue(app.buttons["bible-add"].waitForExistence(timeout: 8))
        app.tabBars.buttons["My Kitchen"].tap()
        XCTAssertTrue(app.buttons["settings-open"].waitForExistence(timeout: 8)); app.buttons["settings-open"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["settings-sync"].exists)
        XCTAssertTrue(app.buttons["privacy-policy-open"].exists)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "iOS 17 target Settings smoke on installed runtime"; capture.lifetime = .keepAlways; add(capture)
    }
}
