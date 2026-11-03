import XCTest

final class DishFoundationUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ args: [String], store: String = UUID().uuidString) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store",store,"--discovery-fixture","--social-review","--social-review-ready","--recipes-review"] + args
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15)); return app
    }
    @MainActor private func shot(_ title: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = title; a.lifetime = .keepAlways; add(a)
    }
    @MainActor func testDishTextSaveCancelRelaunchAndScopedBrandHeader() {
        let store = UUID().uuidString, app = launch(["--test-light"], store: store)
        func open() {
            let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'")).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 8)); row.tap()
            app.buttons["cook-more-actions"].tap(); app.buttons["dish-text-edit"].tap()
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "dish-text-public").firstMatch.waitForExistence(timeout: 8))
        }
        open()
        let pub = app.descendants(matching: .any).matching(identifier: "dish-text-public").firstMatch, priv = app.descendants(matching: .any).matching(identifier: "dish-text-private").firstMatch
        pub.tap(); pub.typeText("Bright, lemony test dish")
        priv.tap(); priv.typeText("Only my technique notes")
        app.buttons["dish-text-save"].tap()
        XCTAssertTrue(app.buttons["detail-edit-cook"].waitForExistence(timeout: 8))
        app.buttons["cook-more-actions"].tap(); app.buttons["dish-text-edit"].tap()
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "dish-text-public").firstMatch.value as? String,"Bright, lemony test dish")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "dish-text-private").firstMatch.value as? String,"Only my technique notes")
        app.descendants(matching: .any).matching(identifier: "dish-text-private").firstMatch.tap(); app.descendants(matching: .any).matching(identifier: "dish-text-private").firstMatch.typeText(" unsaved")
        app.buttons["Cancel"].tap(); app.terminate()
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15)); open()
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "dish-text-private").firstMatch.value as? String,"Only my technique notes")
        app.buttons["Cancel"].tap()
        app.tabBars.buttons["Food Bible"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "primary-brand-title").firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["bible-add"].exists)
        shot("Stage 1 Food Bible brand light", app)
    }
    @MainActor func testBrandHeaderAndTextEditorInDarkAccessibilityAppearance() {
        let app = launch(["--test-dark","--test-large-type","--test-reduce-motion"])
        app.tabBars.buttons["Food Bible"].tap()
        let brand = app.descendants(matching: .any).matching(identifier:"primary-brand-title").firstMatch
        XCTAssertTrue(brand.waitForExistence(timeout: 8)); XCTAssertTrue(app.buttons["bible-add"].isHittable)
        shot("Stage 1 compact brand dark accessibility", app)
        app.tabBars.buttons["Grub Rank"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'")).firstMatch
        XCTAssertTrue(row.exists); row.tap(); app.buttons["cook-more-actions"].tap(); app.buttons["dish-text-edit"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "dish-text-public").firstMatch.waitForExistence(timeout: 8))
        shot("Stage 1 Dish text dark accessibility", app)
        app.buttons["Cancel"].tap()
    }
}
