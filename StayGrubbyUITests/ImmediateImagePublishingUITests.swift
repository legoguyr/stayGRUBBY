import XCTest

final class ImmediateImagePublishingUITests: StayGrubbyUITestCase {
    @MainActor func testSettingsHasNoPrepublicationImageReview() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--test-dark", "--test-reduce-motion"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.tabBars.buttons["My Kitchen"].tap()
        let settings = app.buttons["settings-open"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8)); settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["image-review-open"].exists)
        XCTAssertFalse(app.staticTexts["Image Review"].exists)
    }
}
