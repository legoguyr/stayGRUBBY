import XCTest

final class ReviewEnvironmentUITests: StayGrubbyUITestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func avoidLabelHeight(_ app: XCUIApplication) -> CGFloat {
        app.openRankingFilterGroup("avoid")
        XCTAssertTrue(app.buttons["filters-done"].firstMatch.waitForExistence(timeout: 10))
        let milk = app.buttons["filter-avoid-milk"]
        XCTAssertTrue(milk.waitForExistence(timeout: 10))
        let label = milk.staticTexts.firstMatch
        XCTAssertTrue(label.exists)
        let height = label.frame.height
        app.closeRankingFilters()
        return height
    }

    @MainActor func testAccessibilityReviewScalesRootAndSheetThenReturnsToDefaultOnSameProxy() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--discovery-fixture"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        let defaultHeader = app.rankingHeader.frame.height
        let defaultMilk = avoidLabelHeight(app)
        app.terminate()
        app.launchArguments.append("--test-large-type")
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        XCTAssertGreaterThan(app.rankingHeader.frame.height, defaultHeader * 1.3)
        XCTAssertGreaterThan(avoidLabelHeight(app), defaultMilk * 1.3)
        app.terminate()
        // Leave the old UIKit pair in place to exercise normalization of a reused proxy.
        app.launchArguments.removeAll { $0 == "--test-large-type" }
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        XCTAssertEqual(app.rankingHeader.frame.height, defaultHeader, accuracy: 1)
        XCTAssertEqual(avoidLabelHeight(app), defaultMilk, accuracy: 1)
    }

    @MainActor func testBareReviewFlagsDoNotScaleOnboardingAndFreshLaunchDoesNotInheritTestSize() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.staticTexts["onboarding-brand"].waitForExistence(timeout: 15))
        // The canonical wordmark is fixed artwork, not a Dynamic Type probe.
        // Measure scalable copy and compare the same ranking header at both sizes.
        let title = app.staticTexts["Good food.\nYour signature."]
        XCTAssertTrue(title.exists)
        let normal = title.frame.height
        app.terminate()
        app.launchArguments = ["--test-large-type", "--test-light", "--test-reduce-motion"]
        app.launch()
        XCTAssertTrue(app.staticTexts["onboarding-brand"].waitForExistence(timeout: 15))
        XCTAssertEqual(title.frame.height, normal, accuracy: 1)
        app.terminate()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--discovery-fixture"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        let normalRankingHeader = app.rankingHeader.frame.height
        app.terminate()
        app.launchArguments.append("--test-large-type")
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        XCTAssertGreaterThan(app.rankingHeader.frame.height, normalRankingHeader * 1.3)
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.staticTexts["onboarding-brand"].waitForExistence(timeout: 15))
        XCTAssertEqual(title.frame.height, normal, accuracy: 1)
    }
}
