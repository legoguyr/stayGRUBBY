import XCTest

final class RecipeImportUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ extra: [String] = [], dish: String = "Matzo Ball Soup", expectImport: Bool = true, fixture: Data? = nil) -> XCUIApplication {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--ui-test-store",UUID().uuidString,"--social-review","--social-review-ready","--recipes-review","--recipe-import-review","--bible-v2-empty","--score-unlock-fixture",extra.contains("--bible-review") ? "10" : "1"]+extra
        if let fixture { app.launchEnvironment["STAYGRUBBY_RECIPE_TEST_RESPONSE"] = fixture.base64EncodedString() }
        app.launchWithReviewOptions();XCTAssertTrue(app.rankingHeader.waitForExistence(timeout:20))
        for _ in 0..<3 { app.tabBars.buttons["Food Bible"].tap(); if app.textFields["bible-search"].waitForExistence(timeout:3) { break } };XCTAssertTrue(app.buttons["bible-add"].waitForExistence(timeout:8))
        app.buttons["bible-add"].tap();XCTAssertTrue(app.buttons["bible-import"].waitForExistence(timeout:8));app.buttons["bible-import"].tap()
        if expectImport {
            if app.buttons["recipe-disclosure-continue"].waitForExistence(timeout:3) { app.buttons["recipe-disclosure-continue"].tap() }
            XCTAssertTrue(app.textViews["recipe-import-text"].waitForExistence(timeout:8))
        }
        return app
    }
    @MainActor private func input(_ app:XCUIApplication) {
        let text=app.textViews["recipe-import-text"];text.tap();text.typeText("Soup\n2 carrots\nstock\ncook chicken until done")
        // Dismiss keyboard through a real scroll gesture, preserving pasted text.
        app.swipeUp();allowCloud(app)
    }
    @MainActor private func allowCloud(_ app: XCUIApplication) {
        XCTAssertFalse(app.switches["recipe-import-consent"].exists)
        XCTAssertTrue(app.buttons["recipe-import-format"].isEnabled)
    }
    @MainActor private func shot(_ app:XCUIApplication,_ name:String) {let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
    @MainActor func testImportReviewExplicitSaveSameDishAndReopen() {
        let app=launch(["--test-light"]);input(app);shot(app,"Import recipe consent light")
        app.buttons["recipe-import-format"].tap();XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:10));XCTAssertEqual(app.textFields["recipe-edit-title"].value as? String,"Soup")
        XCTAssertTrue(app.otherElements["recipe-import-review"].exists || app.staticTexts["Some ingredients have no definite quantity. The original wording is preserved."].exists)
        shot(app,"Imported draft review before Save")
        app.buttons["recipe-save"].tap();XCTAssertTrue(app.buttons["bible-add"].waitForExistence(timeout:8));XCTAssertTrue(app.textViews["recipe-import-text"].waitForNonExistence(timeout:8))
        let entry=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'bible-entry-'"));XCTAssertEqual(entry.count,1);entry.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8));XCTAssertEqual(app.staticTexts["recipe-title"].label,"Soup")
        shot(app,"Imported recipe saved and reopened")
    }
    @MainActor func testQuotaFailureManualFallbackKeepsEntireOriginalAndCancelReturnsText() {
        let app=launch(["--test-dark","--recipe-import-failure"]);input(app)
        app.buttons["recipe-import-format"].tap();XCTAssertTrue(app.staticTexts["recipe-import-error"].waitForExistence(timeout:8));shot(app,"Import unavailable raw text retained dark")
        app.buttons["recipe-import-manual"].tap();XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:8));XCTAssertEqual(app.textFields["recipe-edit-title"].value as? String,"Recipe")
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
    @MainActor func testStandaloneImportDoesNotOverwriteExistingLinkedRecipe() {
        let app=launch(["--bible-review","--test-dark"])
        XCTAssertTrue(app.textViews["recipe-import-text"].exists)
        app.buttons["recipe-import-cancel"].tap()
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.textFields["bible-search"].waitForExistence(timeout:8))
        let search=app.textFields["bible-search"];search.tap();search.typeText("Braised")
        let card=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'bible-entry-'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout:8));card.tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8))
        XCTAssertTrue(app.staticTexts["recipe-title"].label.contains("Braised"))
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
        app.swipeUp(); allowCloud(app)
        app.buttons["recipe-import-format"].tap()
        XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:15))
        XCTAssertEqual(app.textFields["recipe-edit-title"].value as? String, "Kale Pasta")
        XCTAssertFalse(app.staticTexts["recipe-import-error"].exists)
        XCTAssertEqual(app.textFields["recipe-yield"].value as? String, "2")
        XCTAssertEqual(app.textFields["recipe-total-minutes"].value as? String, "30")
        shot(app,"Canonical unchanged kale draft — not saved")
        app.buttons["recipe-editor-cancel"].tap()
        XCTAssertTrue(input.waitForExistence(timeout:8))
        XCTAssertEqual(input.value as? String, source)
    }

    @MainActor func testCreatorMetadataExplicitSaveAndReopen() throws {
        struct Fixture: Decodable { var raw: String }
        let bundle = Bundle(for: RecipeImportUITests.self)
        let url = try XCTUnwrap(bundle.url(forResource: "RecipeEngineKaleUI", withExtension: "json", subdirectory: "Fixtures") ?? bundle.url(forResource: "RecipeEngineKaleUI", withExtension: "json"))
        let data = try Data(contentsOf: url), object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String:Any])
        let source = try JSONDecoder().decode(Fixture.self, from: data).raw
        let response = try JSONSerialization.data(withJSONObject: XCTUnwrap(object["extraction"]))
        let app = launch(["--test-dark"], fixture: response)
        app.textViews["recipe-import-text"].tap(); app.textViews["recipe-import-text"].typeText(source)
        app.swipeUp(); allowCloud(app); app.buttons["recipe-import-format"].tap()
        XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:15))
        XCTAssertEqual(app.textFields["recipe-yield"].value as? String, "2")
        XCTAssertEqual(app.textFields["recipe-total-minutes"].value as? String, "30")
        app.buttons["recipe-save"].tap()
        XCTAssertTrue(app.buttons["bible-add"].waitForExistence(timeout:10))
        XCTAssertTrue(app.textViews["recipe-import-text"].waitForNonExistence(timeout:8))
        let entries = app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'bible-entry-'"))
        XCTAssertEqual(entries.count,1); entries.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:10))
        XCTAssertEqual(app.staticTexts["recipe-title"].label,"Kale Pasta")
        for _ in 0..<4 where !app.staticTexts["Contains: Milk"].exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Contains: Milk"].exists)
        XCTAssertTrue(app.staticTexts["Possible: Wheat"].exists)
        shot(app,"Creator metadata and allergens saved and reopened — isolated store")
    }

    @MainActor private func reach(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<20 {
            if !element.exists { app.swipeUp(); continue }
            let f=element.frame, top:CGFloat=155, bottom:CGFloat=app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY-25 : app.frame.maxY-110
            if element.exists && element.isHittable && f.minY>=top && f.maxY<=bottom { return }
            let dy:CGFloat=f.height>0 ? max(-240,min(240,(top+bottom)/2-f.midY)) : -180
            let start=app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0)).withOffset(CGVector(dx:0,dy:(top+bottom)/2))
            start.press(forDuration:0.05,thenDragTo:start.withOffset(CGVector(dx:0,dy:dy)),withVelocity:.slow,thenHoldForDuration:0.1)
        }
        XCTAssertTrue(element.exists && element.isHittable,app.debugDescription)
    }
    @MainActor private func openSavedRecipe(_ app: XCUIApplication) {
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout:20));app.tabBars.buttons["Food Bible"].tap()
        let card=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'bible-entry-'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout:8));card.tap();XCTAssertTrue(app.buttons["recipe-edit"].waitForExistence(timeout:8));app.buttons["recipe-edit"].tap();XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:8))
    }
    @MainActor func testCookbookAllMetadataAndSharedAllergenChecklistSurviveSaveAndRelaunch() throws {
        let bundle=Bundle(for:RecipeImportUITests.self)
        let url=try XCTUnwrap(bundle.url(forResource:"RecipeEngineKaleUI",withExtension:"json",subdirectory:"Fixtures") ?? bundle.url(forResource:"RecipeEngineKaleUI",withExtension:"json"))
        let object=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:url)) as? [String:Any])
        let source=try XCTUnwrap(object["raw"] as? String),fixture=try JSONSerialization.data(withJSONObject:XCTUnwrap(object["extraction"]))
        let app=launch(["--test-light","--recipe-persistence-review"],fixture:fixture)
        app.textViews["recipe-import-text"].tap();app.textViews["recipe-import-text"].typeText(source);app.swipeUp();allowCloud(app);app.buttons["recipe-import-format"].tap()
        XCTAssertTrue(app.textFields["recipe-yield"].waitForExistence(timeout:15))
        XCTAssertEqual(app.textFields["recipe-yield"].value as? String,"2")
        XCTAssertEqual(app.textFields["Preparation time in minutes"].value as? String,"15")
        XCTAssertEqual(app.textFields["Cooking time in minutes"].value as? String,"20")
        XCTAssertEqual(app.textFields["recipe-total-minutes"].value as? String,"30")
        let contains=app.buttons["recipe-allergen-contains"];reach(contains,app:app);contains.tap()
        let milk=app.buttons["recipe-allergen-contains-milk"],egg=app.buttons["recipe-allergen-contains-egg"]
        XCTAssertTrue(milk.waitForExistence(timeout:5));XCTAssertEqual(milk.value as? String,"Selected");milk.tap();egg.tap()
        XCTAssertEqual(milk.value as? String,"Not selected");XCTAssertEqual(egg.value as? String,"Selected");shot(app,"Recipe reuses approved allergen checklist")
        app.buttons["recipe-allergen-contains-done"].tap()
        let possible=app.buttons["recipe-allergen-possible"];reach(possible,app:app);possible.tap()
        let wheat=app.buttons["recipe-allergen-possible-wheat"];reach(wheat,app:app);XCTAssertEqual(wheat.value as? String,"Selected")
        app.buttons["recipe-allergen-possible-done"].tap();app.buttons["recipe-save"].tap()
        XCTAssertTrue(app.textViews["recipe-import-text"].waitForNonExistence(timeout:8))
        app.terminate();app.launchWithReviewOptions();openSavedRecipe(app)
        XCTAssertEqual(app.textFields["recipe-yield"].value as? String,"2");XCTAssertEqual(app.textFields["recipe-total-minutes"].value as? String,"30")
        reach(app.buttons["recipe-allergen-contains"],app:app);app.buttons["recipe-allergen-contains"].tap()
        XCTAssertEqual(app.buttons["recipe-allergen-contains-milk"].value as? String,"Not selected");XCTAssertEqual(app.buttons["recipe-allergen-contains-egg"].value as? String,"Selected")
        shot(app,"Corrected Recipe allergens retained after relaunch")
    }
    @MainActor func testNativeIngredientAndStepDragAcrossSectionsPersistsAfterRelaunch() throws {
        let raw="Soup: add carrots and stock. Add salt. Serve carrots. Garnish: add parsley."
        let fixture=Data(#"{"title":"Soup","yield":null,"source":null,"components":[{"title":"Soup","ingredients":["carrots","stock","salt"],"steps":["Add carrots and stock.","Add salt.","Serve carrots."]},{"title":"Garnish","ingredients":["parsley"],"steps":["Add parsley."]}]}"#.utf8)
        let app=launch(["--test-dark","--recipe-persistence-review"],fixture:fixture)
        app.textViews["recipe-import-text"].tap();app.textViews["recipe-import-text"].typeText(raw);app.swipeUp();allowCloud(app);app.buttons["recipe-import-format"].tap()
        XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:15))
        let first=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'recipe-ingredient-row-'")).firstMatch;reach(first,app:app);first.tap()
        reach(app.buttons["recipe-reorder-ingredients"],app:app);app.buttons["recipe-reorder-ingredients"].tap()
        let table=app.tables["recipe-order-table"];XCTAssertTrue(table.waitForExistence(timeout:5));XCTAssertFalse(app.keyboards.firstMatch.exists)
        let originalIDs=Set(table.cells.allElementsBoundByIndex.map(\.identifier));XCTAssertEqual(table.cells.count,4)
        drag(table.cells.element(boundBy:0),to:table.cells.element(boundBy:2),after:true)
        XCTAssertEqual(table.cells.allElementsBoundByIndex.map(\.label),["stock","salt","carrots","parsley"])
        drag(table.cells.element(boundBy:2),to:table.cells.element(boundBy:3),after:true)
        app.buttons["recipe-order-done"].tap();app.buttons["recipe-reorder-ingredients"].tap()
        XCTAssertEqual(Set(table.cells.allElementsBoundByIndex.map(\.identifier)),originalIDs)
        XCTAssertEqual(table.cells.allElementsBoundByIndex.first(where:{$0.label=="carrots"})?.value as? String,"Garnish")
        let ingredientOrder=table.cells.allElementsBoundByIndex.map(\.label);shot(app,"Native ingredient drag within and between components")
        app.buttons["recipe-order-done"].tap()
        reach(app.buttons["recipe-reorder-steps"],app:app);app.buttons["recipe-reorder-steps"].tap()
        XCTAssertTrue(table.waitForExistence(timeout:5));XCTAssertEqual(table.cells.count,4)
        drag(table.cells.element(boundBy:0),to:table.cells.element(boundBy:1),after:true)
        XCTAssertEqual(table.cells.element(boundBy:0).label,"Add salt.")
        drag(table.cells.matching(NSPredicate(format:"label == %@","Serve carrots.")).firstMatch,to:table.cells.matching(NSPredicate(format:"label == %@","Add parsley.")).firstMatch,after:true)
        app.buttons["recipe-order-done"].tap();app.buttons["recipe-reorder-steps"].tap()
        XCTAssertEqual(table.cells.allElementsBoundByIndex.first(where:{$0.label=="Serve carrots."})?.value as? String,"Garnish")
        let stepOrder=table.cells.allElementsBoundByIndex.map(\.label);shot(app,"Native method drag within and between components")
        app.buttons["recipe-order-done"].tap();app.buttons["recipe-save"].tap()
        XCTAssertTrue(app.textViews["recipe-import-text"].waitForNonExistence(timeout:8))
        let entry=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'bible-entry-'")).firstMatch;XCTAssertTrue(entry.waitForExistence(timeout:8));entry.tap();XCTAssertTrue(app.buttons["recipe-edit"].waitForExistence(timeout:8));app.buttons["recipe-edit"].tap();XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:8))
        reach(app.buttons["recipe-reorder-steps"],app:app);app.buttons["recipe-reorder-steps"].tap();XCTAssertEqual(table.cells.allElementsBoundByIndex.map(\.label),stepOrder);app.buttons["recipe-order-done"].tap()
        app.terminate();app.launchWithReviewOptions();openSavedRecipe(app)
        reach(app.buttons["recipe-reorder-ingredients"],app:app);app.buttons["recipe-reorder-ingredients"].tap();XCTAssertEqual(table.cells.allElementsBoundByIndex.map(\.label),ingredientOrder);XCTAssertEqual(Set(table.cells.allElementsBoundByIndex.map(\.identifier)),originalIDs);app.buttons["recipe-order-done"].tap()
        reach(app.buttons["recipe-reorder-steps"],app:app);app.buttons["recipe-reorder-steps"].tap();XCTAssertEqual(table.cells.allElementsBoundByIndex.map(\.label),stepOrder);XCTAssertEqual(table.cells.count,4)
        shot(app,"Ingredient and method ordering survived relaunch")
    }
    @MainActor private func drag(_ source:XCUIElement,to target:XCUIElement,after:Bool) {
        source.coordinate(withNormalizedOffset:CGVector(dx:0.94,dy:0.5)).press(forDuration:0.8,thenDragTo:target.coordinate(withNormalizedOffset:CGVector(dx:0.94,dy:after ? 0.85 : 0.15)),withVelocity:.slow,thenHoldForDuration:0.3)
    }

}
