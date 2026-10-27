import XCTest

final class RecipeImportUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ extra: [String] = [], dish: String = "Matzo Ball Soup", expectImport: Bool = true, fixture: Data? = nil) -> XCUIApplication {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--ui-test-store",UUID().uuidString,"--social-review","--social-review-ready","--recipes-review","--recipe-import-review","--score-unlock-fixture",extra.contains("--bible-review") ? "10" : "1"]+extra
        if let fixture { app.launchEnvironment["STAYGRUBBY_RECIPE_TEST_RESPONSE"] = fixture.base64EncodedString() }
        app.launchWithReviewOptions();XCTAssertTrue(app.rankingHeader.waitForExistence(timeout:20))
        app.tabBars.buttons["Food Bible"].tap();XCTAssertTrue(app.buttons["bible-add"].waitForExistence(timeout:8))
        app.buttons["bible-add"].tap();XCTAssertTrue(app.buttons["bible-import"].waitForExistence(timeout:8));app.buttons["bible-import"].tap()
        if dish != "Matzo Ball Soup" { let search=app.textFields["choose-dish-search"];XCTAssertTrue(search.waitForExistence(timeout:5));search.tap();search.typeText(dish) }
        XCTAssertTrue(app.buttons[dish].waitForExistence(timeout:8));app.buttons[dish].tap()
        if expectImport { XCTAssertTrue(app.textViews["recipe-import-text"].waitForExistence(timeout:8)) }
        else { XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8)) };return app
    }
    @MainActor private func input(_ app:XCUIApplication) {
        let text=app.textViews["recipe-import-text"];text.tap();text.typeText("Soup\n2 carrots\nstock\ncook chicken until done")
        // Dismiss keyboard through a real scroll gesture, preserving pasted text.
        app.swipeUp();app.switches["recipe-import-consent"].tap()
    }
    @MainActor private func shot(_ app:XCUIApplication,_ name:String) {let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
    @MainActor func testImportReviewExplicitSaveSameDishAndReopen() {
        let app=launch(["--test-light"]);input(app);shot(app,"Import recipe consent light")
        app.buttons["recipe-import-format"].tap();XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:10));XCTAssertEqual(app.textFields["recipe-edit-title"].value as? String,"Soup")
        XCTAssertTrue(app.otherElements["recipe-import-review"].exists || app.staticTexts["Some ingredients have no definite quantity. The original wording is preserved."].exists)
        shot(app,"Imported draft review before Save")
        app.buttons["recipe-save"].tap();XCTAssertTrue(app.buttons["bible-add"].waitForExistence(timeout:8));XCTAssertFalse(app.textViews["recipe-import-text"].exists)
        let entry=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'bible-entry-'"));XCTAssertEqual(entry.count,1);entry.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8));XCTAssertEqual(app.staticTexts["recipe-title"].label,"Soup")
        shot(app,"Imported recipe saved and reopened")
    }
    @MainActor func testQuotaFailureManualFallbackKeepsEntireOriginalAndCancelReturnsText() {
        let app=launch(["--test-dark","--recipe-import-failure"]);input(app)
        app.buttons["recipe-import-format"].tap();XCTAssertTrue(app.staticTexts["recipe-import-error"].waitForExistence(timeout:8));shot(app,"Import unavailable raw text retained dark")
        app.buttons["recipe-import-manual"].tap();XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:8));XCTAssertEqual(app.textFields["recipe-edit-title"].value as? String,"Matzo Ball Soup")
        app.buttons["recipe-editor-cancel"].tap();XCTAssertTrue(app.textViews["recipe-import-text"].waitForExistence(timeout:8));XCTAssertEqual(app.textViews["recipe-import-text"].value as? String,"Soup\n2 carrots\nstock\ncook chicken until done")
        app.buttons["recipe-import-cancel"].tap();XCTAssertTrue(app.buttons["Keep Editing"].waitForExistence(timeout:5));app.buttons["Keep Editing"].tap()
        XCTAssertTrue(app.textViews["recipe-import-text"].exists)
    }
    @MainActor func testLargeTypeImportRetainsTextAcrossBackground() {
        let app=launch(["--test-large-type","--test-light"])
        shot(app,"Import large text layout");app.textViews["recipe-import-text"].tap();app.textViews["recipe-import-text"].typeText("Soup")
        XCUIDevice.shared.press(.home);app.activate();XCTAssertTrue(app.textViews["recipe-import-text"].waitForExistence(timeout:8));XCTAssertEqual(app.textViews["recipe-import-text"].value as? String,"Soup")
        app.buttons["recipe-import-cancel"].tap();app.buttons["Discard"].tap()
    }
    @MainActor func testImportChoiceOpensExistingRecipeWithoutOverwrite() {
        let app=launch(["--bible-review","--test-dark"],dish:"Braised Short Ribs with Polenta",expectImport:false)
        XCTAssertFalse(app.textViews["recipe-import-text"].exists)
        XCTAssertTrue(app.staticTexts["recipe-title"].label.contains("Braised"))
        XCTAssertTrue(app.buttons["recipe-edit"].exists)
        shot(app,"Existing recipe protected from import replacement")
    }

    @MainActor func testCanonicalKaleServerContractOpensEditorWithoutSaving() throws {
        struct Fixture: Decodable { var raw: String }
        let bundle = Bundle(for: RecipeImportUITests.self)
        let url = try XCTUnwrap(bundle.url(forResource: "RecipeEngineKaleUI", withExtension: "json", subdirectory: "Fixtures") ?? bundle.url(forResource: "RecipeEngineKaleUI", withExtension: "json"))
        let data = try Data(contentsOf: url), object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String:Any])
        let source = try JSONDecoder().decode(Fixture.self, from: data).raw
        let response = try JSONSerialization.data(withJSONObject: XCTUnwrap(object["extraction"]))
        let app = launch(["--test-light"], fixture: response)
        let input = app.textViews["recipe-import-text"]
        input.tap(); input.typeText(source)
        XCTAssertEqual(input.value as? String, source)
        app.swipeUp(); app.switches["recipe-import-consent"].tap()
        app.buttons["recipe-import-format"].tap()
        XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:15))
        XCTAssertEqual(app.textFields["recipe-edit-title"].value as? String, "Kale Pasta")
        XCTAssertFalse(app.staticTexts["recipe-import-error"].exists)
        shot(app,"Canonical unchanged kale draft — not saved")
        app.buttons["recipe-editor-cancel"].tap()
        XCTAssertTrue(input.waitForExistence(timeout:8))
        XCTAssertEqual(input.value as? String, source)
    }

}
