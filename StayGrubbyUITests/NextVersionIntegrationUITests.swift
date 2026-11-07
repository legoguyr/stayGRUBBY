import XCTest

final class NextVersionIntegrationUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--recipes-review", "--social-review-feed", "--recipes-review-feed", "--shared-review", "--test-reduce-motion"] + extra
        app.launchWithReviewOptions()
        return app
    }
    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name
        shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor func testDirectPostAndRecipeLinksAndUnavailableDestination() {
        let post = launch(["--review-profile-url", "https://staygrubby.com/p/20000000-0000-0000-0000-000000000001"])
        XCTAssertTrue(post.staticTexts["Harissa Chicken with Roasted Peppers"].waitForExistence(timeout: 12))
        let recipe = post.buttons["post-recipe"]
        for _ in 0..<5 { if recipe.isHittable { break }; post.swipeUp() }
        XCTAssertTrue(recipe.isHittable); recipe.tap()
        XCTAssertTrue(post.staticTexts["shared-recipe-title"].waitForExistence(timeout: 8))
        XCTAssertFalse(post.buttons["recipe-edit"].exists)
        post.terminate()
        let current = launch(["--review-profile-url", "staygrubby://open/r/60000000-0000-0000-0000-000000000001"])
        XCTAssertTrue(current.staticTexts["recipe-title"].waitForExistence(timeout: 12))
        current.revealRecipeActions(); XCTAssertTrue(current.buttons["recipe-edit"].exists)
        current.terminate()
        let missing = launch(["--review-profile-url", "https://staygrubby.com/p/ffffffff-ffff-ffff-ffff-ffffffffffff"])
        XCTAssertTrue(missing.staticTexts["Post unavailable"].waitForExistence(timeout: 12))
        XCTAssertFalse(missing.buttons["post-recipe"].exists)
    }
    @MainActor func testConnectedSurfacesInLightAndDarkAppearance() {
        for appearance in ["--test-light", "--test-dark"] {
            let app = launch([appearance])
            XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
            app.tabBars.buttons["My Kitchen"].tap()
            XCTAssertTrue(app.buttons["settings-open"].waitForExistence(timeout: 8))
            let bell = app.buttons["notifications-open"]
            XCTAssertTrue(bell.isHittable); capture("Kitchen header \(appearance)", app)
            bell.tap(); XCTAssertTrue(app.navigationBars["Tickets"].waitForExistence(timeout: 8))
            capture("Order Up \(appearance)", app)
            app.tabBars.buttons["Grub List"].tap()
            let recipe = app.buttons["post-recipe"]
            for _ in 0..<5 { if recipe.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(recipe.isHittable); capture("Feed Recipe entry \(appearance)", app); recipe.tap()
            XCTAssertTrue(app.staticTexts["shared-recipe-title"].waitForExistence(timeout: 8))
            XCTAssertTrue(app.buttons["shared-recipe-fork"].isHittable)
            capture("Shared Recipe primary actions \(appearance)", app)
            app.tabBars.buttons["Food Bible"].tap()
            let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-'")).firstMatch
            XCTAssertTrue(entry.waitForExistence(timeout: 8)); entry.tap()
            XCTAssertTrue(app.buttons["recipe-make"].waitForExistence(timeout: 8))
            XCTAssertTrue(app.buttons["recipe-make"].isHittable)
            capture("Recipe cooking entry \(appearance)", app)
            app.terminate()
        }
    }
    @MainActor func testLargeTypeKitchenHeaderAndSharedRecipeActions() {
        let app = launch(["--test-light", "--test-large-type"])
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.tabBars.buttons["My Kitchen"].tap()
        let bell = app.buttons["notifications-open"]
        XCTAssertTrue(bell.waitForExistence(timeout: 8)); XCTAssertTrue(bell.isHittable)
        XCTAssertTrue(app.buttons["settings-open"].isHittable)
        capture("Kitchen accessibility reduced motion", app)
        app.tabBars.buttons["Grub List"].tap()
        let recipe = app.buttons["post-recipe"]
        for _ in 0..<8 { if recipe.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(recipe.isHittable); recipe.tap()
        XCTAssertTrue(app.staticTexts["shared-recipe-title"].waitForExistence(timeout: 8))
        let copy = app.buttons["shared-recipe-fork"]
        for _ in 0..<6 { if copy.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(copy.isHittable); capture("Shared Recipe accessibility", app)
    }
}
