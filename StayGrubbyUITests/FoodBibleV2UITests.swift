import XCTest

final class FoodBibleV2UITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ appearance: String) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--recipes-review", "--bible-v2-empty", "--recipe-import-review", "--recipe-persistence-review", "--recipe-photo-review", "--score-unlock-fixture", "1", appearance]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout:20)); openBible(app); return app
    }
    @MainActor private func openBible(_ app: XCUIApplication) {
        for _ in 0..<3 { app.tabBars.buttons["Food Bible"].tap(); if app.textFields["bible-search"].waitForExistence(timeout:3) { break } }
        XCTAssertTrue(app.buttons["bible-add"].waitForExistence(timeout:8))
    }
    @MainActor private func reach(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<20 {
            let f=element.frame, top:CGFloat=155, bottom:CGFloat=app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY-25 : app.frame.maxY-110
            if element.exists && element.isHittable && f.minY>=top && f.maxY<=bottom { return }
            let dy:CGFloat=f.height>0 ? max(-240,min(240,(top+bottom)/2-f.midY)) : -180
            let start=app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0)).withOffset(CGVector(dx:0,dy:(top+bottom)/2))
            start.press(forDuration:0.05,thenDragTo:start.withOffset(CGVector(dx:0,dy:dy)),withVelocity:.slow,thenHoldForDuration:0.1)
        }
        XCTAssertTrue(element.exists && element.isHittable,app.debugDescription)
    }
    @MainActor private func screenshot(_ app: XCUIApplication, _ name: String) { let a = XCTAttachment(screenshot:app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a) }
    @MainActor func testFirstUseDisclosureCancelManualAndDurableAcknowledgement() {
        let app = launch("--test-light")
        app.buttons["bible-add"].tap(); app.buttons["bible-import"].tap()
        XCTAssertTrue(app.buttons["recipe-disclosure-continue"].waitForExistence(timeout:8)); XCTAssertFalse(app.textViews["recipe-import-text"].exists)
        screenshot(app,"Paste Recipe first-use disclosure light")
        app.buttons["recipe-import-cancel"].tap(); app.buttons["bible-import"].tap()
        XCTAssertTrue(app.buttons["recipe-disclosure-continue"].waitForExistence(timeout:8))
        app.buttons["recipe-disclosure-manual"].tap(); XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:8)); XCTAssertFalse(app.staticTexts["recipe-import-progress"].exists)
        app.buttons["recipe-editor-cancel"].tap()
        XCTAssertTrue(app.buttons["recipe-disclosure-continue"].waitForExistence(timeout:8)); app.buttons["recipe-disclosure-continue"].tap()
        XCTAssertTrue(app.textViews["recipe-import-text"].waitForExistence(timeout:8)); XCTAssertFalse(app.switches["recipe-import-consent"].exists)
        app.terminate(); app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout:20)); openBible(app)
        app.buttons["bible-add"].tap(); app.buttons["bible-import"].tap()
        XCTAssertTrue(app.textViews["recipe-import-text"].waitForExistence(timeout:8)); XCTAssertFalse(app.buttons["recipe-disclosure-continue"].exists)
    }
    @MainActor func testStandaloneSaveEditHistoryRestoreForkAndRelaunch() {
        let app = launch("--test-dark")
        app.buttons["bible-add"].tap(); app.buttons["bible-manual"].tap()
        let title = app.textFields["recipe-edit-title"]; XCTAssertTrue(title.waitForExistence(timeout:8)); title.tap(); title.typeText("Independent Soup"); app.buttons["recipe-keyboard-done"].tap(); app.buttons["recipe-save"].tap()
        let card = app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'bible-entry-'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout:8)); let identity = card.identifier; card.tap(); XCTAssertTrue(app.buttons["recipe-edit"].waitForExistence(timeout:8))
        app.buttons["recipe-edit"].tap(); XCTAssertTrue(title.waitForExistence(timeout:8)); title.tap(); title.typeText(" updated"); app.buttons["recipe-keyboard-done"].tap(); app.buttons["recipe-save"].tap()
        reach(app.buttons["recipe-history"],app:app); app.buttons["recipe-history"].tap(); XCTAssertTrue(app.buttons["recipe-version-1"].waitForExistence(timeout:8)); app.buttons["recipe-version-1"].tap()
        reach(app.buttons["recipe-restore"],app:app); screenshot(app,"Recipe history and restore dark"); app.buttons["recipe-restore"].tap(); app.buttons["Create New Current Version"].tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8)); XCTAssertEqual(app.staticTexts["recipe-title"].label,"Independent Soup")
        reach(app.buttons["recipe-save-new"],app:app); app.buttons["recipe-save-new"].tap(); XCTAssertTrue(title.waitForExistence(timeout:8)); title.tap(); title.typeText(" copy"); app.buttons["recipe-keyboard-done"].tap(); app.buttons["recipe-save"].tap()
        app.terminate(); app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout:20)); openBible(app)
        let cards = app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'bible-entry-'")); XCTAssertTrue(cards.firstMatch.waitForExistence(timeout:8)); XCTAssertEqual(cards.count,2); XCTAssertTrue(app.buttons[identity].exists)
        screenshot(app,"Independent Recipes persisted once each")
    }
    @MainActor func testRecipePhotoSaveRemoveAndServingProjection() {
        let app = launch("--test-light")
        app.buttons["bible-add"].tap(); app.buttons["bible-manual"].tap()
        let title = app.textFields["recipe-edit-title"]; XCTAssertTrue(title.waitForExistence(timeout:8)); title.tap(); title.typeText("Photo Soup"); app.buttons["recipe-keyboard-done"].tap()
        app.buttons["recipe-photo-fixture"].tap()
        let yield = app.textFields["recipe-yield"]; reach(yield,app:app); yield.tap(); yield.typeText("Serves 4"); app.buttons["recipe-keyboard-done"].tap()
        app.buttons["recipe-save"].tap()
        let card = app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'bible-entry-'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout:8)); card.tap(); XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8))
        let hero = app.otherElements["recipe-hero"]
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == 'Recipe photo'"),object:hero)],timeout:8),.completed)
        reach(app.steppers["recipe-servings"],app:app); app.steppers["recipe-servings"].buttons["recipe-servings-Increment"].tap(); XCTAssertEqual(app.steppers["recipe-servings"].value as? String,"5",app.debugDescription)
        app.buttons["recipe-edit"].tap(); XCTAssertTrue(yield.waitForExistence(timeout:8)); XCTAssertEqual(yield.value as? String,"Serves 4")
        reach(app.buttons["recipe-photo-remove"],app:app); app.buttons["recipe-photo-remove"].tap(); app.buttons["recipe-save"].tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8)); screenshot(app,"Recipe photo removed with branded fallback; serving projection never saved")
        app.terminate();app.launchWithReviewOptions();XCTAssertTrue(app.rankingHeader.waitForExistence(timeout:20));openBible(app);XCTAssertTrue(card.waitForExistence(timeout:8));card.tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8));XCTAssertEqual(hero.value as? String,"StayGrubby placeholder")
    }

}
