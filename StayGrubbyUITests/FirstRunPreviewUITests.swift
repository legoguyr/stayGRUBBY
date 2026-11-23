import XCTest

/// Debug-only first-run preview (Build 7): the real Welcome, setup, tour and empty Grub Rank run on a
/// signed-in account (Settings › Developer Tools — Debug Only) and exit back to it unchanged.
final class FirstRunPreviewUITests: StayGrubbyUITestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func openPreview(_ app: XCUIApplication) {
        for _ in 0..<3 {
            app.tabBars.buttons["My Kitchen"].tap()
            if app.buttons["settings-open"].waitForExistence(timeout: 3) { break }
        }
        app.buttons["settings-open"].tap()
        let open = app.buttons["internal-preview-open"]
        XCTAssertTrue(open.waitForExistence(timeout: 8))
        for _ in 0..<6 where !open.isHittable { app.swipeUp() }
        open.tap()
        XCTAssertTrue(app.buttons["internal-preview-sign-in"].waitForExistence(timeout: 8), "Starts at the simulated Welcome")
        XCTAssertTrue(app.descendants(matching: .any)["internal-preview-banner"].exists)
    }

    @MainActor func testPreviewRunsTheRealJourneyAndExitsWithTheAccountUnchanged() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--test-light"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.openAccountProfileSettings()
        let realUsername = app.textFields["social-username"].value as? String
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        openPreview(app)
        XCTAssertTrue(app.staticTexts["onboarding-brand"].exists, "The real Welcome")
        app.buttons["internal-preview-sign-in"].tap()
        let title = app.staticTexts["onboarding-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8)); XCTAssertEqual(title.label, "Set up your Kitchen")
        XCTAssertEqual(app.textFields["onboarding-username"].value as? String, "username", "Starts empty, never the real profile")
        app.textFields["onboarding-name"].tap(); app.typeText("Preview Cook")
        app.textFields["onboarding-username"].tap(); app.typeText("preview_cook")
        app.buttons["onboarding-continue"].tap()
        XCTAssertTrue(app.buttons["onboarding-private"].waitForExistence(timeout: 8)); app.buttons["onboarding-continue"].tap()
        XCTAssertTrue(app.staticTexts["Add a profile photo"].waitForExistence(timeout: 8)); app.buttons["onboarding-continue"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["tutorial-page-0"].waitForExistence(timeout: 8), "The real tour")
        app.buttons["tutorial-skip"].tap()
        XCTAssertTrue(app.buttons["ranking-empty-rank-dish"].waitForExistence(timeout: 8), "The real empty Grub Rank")
        app.buttons["internal-preview-exit"].tap()
        XCTAssertTrue(app.buttons["internal-preview-open"].waitForExistence(timeout: 8), "Back in Settings")

        // Exiting mid-setup and reopening starts fresh: nothing from the preview was kept.
        app.buttons["internal-preview-open"].tap()
        app.buttons["internal-preview-sign-in"].tap()
        XCTAssertTrue(app.textFields["onboarding-username"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.textFields["onboarding-username"].value as? String, "username")
        app.buttons["internal-preview-exit"].tap()

        // The real account is unchanged.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.openAccountProfileSettings()
        XCTAssertEqual(app.textFields["social-username"].value as? String, realUsername)
        XCTAssertNotEqual(realUsername, "preview_cook")
    }
}
