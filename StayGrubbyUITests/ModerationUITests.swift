import XCTest

/// Staff moderation (PUBLIC_MVP_MODERATION.md) against the isolated review backend's synthetic reports.
/// Never touches real reports: `--social-review` replaces the server entirely.
final class ModerationUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ arguments: [String]) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--test-reduce-motion",
                               "--social-review-ready", "--test-light"] + arguments
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        for _ in 0..<3 {
            app.tabBars.buttons["My Kitchen"].tap()
            if app.buttons["settings-open"].waitForExistence(timeout: 3) { break }
        }
        app.buttons["settings-open"].tap()
        XCTAssertTrue(app.buttons["privacy-policy-open"].waitForExistence(timeout: 8) || app.navigationBars["Settings"].waitForExistence(timeout: 2))
        return app
    }
    @MainActor private func shot(_ name: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    @MainActor private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    /// Back to the queue once the confirmation has fully closed.
    @MainActor private func backToQueue(_ app: XCUIApplication) {
        for _ in 0..<4 {
            if app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 2) { app.navigationBars.buttons.firstMatch.tap() }
            if element(app, "moderation-queue").waitForExistence(timeout: 3) { return }
        }
        XCTFail("Did not return to the queue")
    }
    @MainActor private func report(_ app: XCUIApplication, _ n: Int) -> XCUIElement {
        element(app, "moderation-report-30000000-0000-0000-0000-\(String(format: "%012d", n))")
    }

    @MainActor func testModerationIsHiddenFromNonStaffAndWithoutTheFlag() throws {
        // Flag on, but the server says this account is not staff.
        var app = launch(["--feature-flag", "staff_moderation"])
        XCTAssertFalse(element(app, "settings-moderation").waitForExistence(timeout: 3))
        app.terminate()
        // Staff on the server, but the flag is off: no request and no row.
        app = launch(["--moderation-review"])
        XCTAssertFalse(element(app, "settings-moderation").waitForExistence(timeout: 3))
    }

    @MainActor func testStaffReviewDismissHidePaginationAndDeletedContent() throws {
        let app = launch(["--moderation-review", "--feature-flag", "staff_moderation"])
        let entry = element(app, "settings-moderation")
        XCTAssertTrue(entry.waitForExistence(timeout: 8)); shot("Settings · Moderation (staff)", app)
        entry.tap()

        // Queue: first page of 25, then Load More reaches the last two.
        XCTAssertTrue(report(app, 1).waitForExistence(timeout: 8)); shot("Moderation · queue", app)
        XCTAssertFalse(report(app, 26).exists)
        for _ in 0..<12 where !app.buttons["moderation-load-more"].isHittable { app.swipeUp() }
        app.buttons["moderation-load-more"].tap()
        XCTAssertTrue(report(app, 27).waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["moderation-load-more"].exists, "No more pages after the last two")
        for _ in 0..<12 where !report(app, 1).isHittable { app.swipeDown() }

        // Dismiss a comment report (with the reporter's note) after confirming.
        report(app, 1).tap()
        XCTAssertTrue(app.staticTexts["Posted the same link many times."].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Synthetic reported comment 1"].exists); shot("Moderation · comment report", app)
        app.buttons["moderation-dismiss"].tap()
        app.buttons["moderation-confirm-dismiss"].firstMatch.tap()
        XCTAssertTrue(element(app, "moderation-outcome").waitForExistence(timeout: 8))
        XCTAssertEqual(element(app, "moderation-outcome").label, "Report dismissed")
        backToQueue(app)
        XCTAssertTrue(report(app, 2).waitForExistence(timeout: 8))
        XCTAssertFalse(report(app, 1).exists, "A handled report leaves the queue")

        // Hide a post after confirming.
        report(app, 2).tap()
        XCTAssertTrue(app.staticTexts["Synthetic Cook 2"].waitForExistence(timeout: 8))
        app.buttons["moderation-hide"].tap()
        XCTAssertTrue(app.staticTexts["Hide this content?"].waitForExistence(timeout: 4)); shot("Moderation · hide confirmation", app)
        app.buttons["moderation-confirm-hide"].firstMatch.tap()
        XCTAssertTrue(element(app, "moderation-outcome").waitForExistence(timeout: 8))
        XCTAssertEqual(element(app, "moderation-outcome").label, "Content hidden")
        backToQueue(app)

        // Deleted content: only Dismiss is possible.
        XCTAssertTrue(report(app, 5).waitForExistence(timeout: 8))
        report(app, 5).tap()
        XCTAssertTrue(element(app, "moderation-subject-missing").waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["moderation-hide"].isEnabled)
        XCTAssertTrue(app.buttons["moderation-dismiss"].isEnabled); shot("Moderation · deleted content", app)
    }

    @MainActor func testAReportAnotherModeratorHandledShowsAlreadyHandled() throws {
        let app = launch(["--moderation-review", "--moderation-review-conflict", "--feature-flag", "staff_moderation"])
        element(app, "settings-moderation").tap()
        XCTAssertTrue(report(app, 3).waitForExistence(timeout: 8))
        report(app, 3).tap()
        XCTAssertTrue(app.buttons["moderation-dismiss"].waitForExistence(timeout: 8))
        app.buttons["moderation-dismiss"].tap()
        app.buttons["moderation-confirm-dismiss"].firstMatch.tap()
        XCTAssertTrue(element(app, "moderation-outcome").waitForExistence(timeout: 8))
        XCTAssertEqual(element(app, "moderation-outcome").label, "Already handled")
        backToQueue(app)
        XCTAssertTrue(report(app, 4).waitForExistence(timeout: 8))
        XCTAssertFalse(report(app, 3).exists)
    }
}
