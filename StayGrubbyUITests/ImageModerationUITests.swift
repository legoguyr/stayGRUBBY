import XCTest

final class ImageModerationUITests: StayGrubbyUITestCase {
    @MainActor private func settings(staff: Bool) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--test-dark", "--test-reduce-motion"]
        if staff { app.launchArguments.append("--image-review-fixture") }
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.tabBars.buttons["My Kitchen"].tap()
        let settings = app.buttons["settings-open"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8)); settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8))
        return app
    }
    @MainActor func testOrdinaryAccountHasNoImageReviewEntry() {
        let app = settings(staff: false)
        XCTAssertFalse(app.buttons["image-review-open"].waitForExistence(timeout: 2))
    }
    @MainActor func testStaffApprovesThenHidesSharedOriginal() {
        let app = settings(staff: true)
        let entry = app.buttons["image-review-open"]
        for _ in 0..<4 where !entry.isHittable { app.swipeUp() }
        XCTAssertTrue(entry.waitForExistence(timeout: 8)); entry.tap()
        let row = app.buttons["review-image-90000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(row.waitForExistence(timeout: 8)); row.tap()
        let approve = app.buttons["review-image-approve"]
        XCTAssertTrue(approve.waitForExistence(timeout: 8))
        XCTAssertTrue(approve.isEnabled); approve.tap()
        XCTAssertTrue(app.navigationBars["Image Review"].waitForExistence(timeout: 8))
        app.segmentedControls.buttons["Approved"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 8)); row.tap()
        let hide = app.buttons["review-image-reject"]
        XCTAssertTrue(hide.waitForExistence(timeout: 8)); XCTAssertEqual(hide.label,"Hide Image"); hide.tap()
        XCTAssertTrue(app.navigationBars["Image Review"].waitForExistence(timeout: 8))
        app.segmentedControls.buttons["Rejected"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 8))
    }
}
