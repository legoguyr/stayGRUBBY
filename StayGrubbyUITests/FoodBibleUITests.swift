import XCTest

final class FoodBibleUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--ui-test-store",UUID().uuidString,"--social-review","--social-review-ready","--recipes-review"]+extra
        app.launchWithReviewOptions();XCTAssertTrue(app.rankingHeader.waitForExistence(timeout:20))
        for _ in 0..<3 { app.tabBars.buttons["Food Bible"].tap();if app.textFields["bible-search"].waitForExistence(timeout:3){break} }
        XCTAssertTrue(app.buttons["bible-add"].waitForExistence(timeout:8));return app
    }
    @MainActor private func reach(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<20 {
            let f=element.frame, top:CGFloat=160, bottom:CGFloat=app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY-30 : app.frame.maxY-115
            if element.exists && element.isHittable && f.minY>=top && f.maxY<=bottom{return}
            let dy:CGFloat=f.height>0 ? max(-220,min(220,(top+bottom)/2-f.midY)) : -180
            let start=app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0)).withOffset(CGVector(dx:0,dy:(top+bottom)/2))
            start.press(forDuration:0.05,thenDragTo:start.withOffset(CGVector(dx:0,dy:dy)),withVelocity:.slow,thenHoldForDuration:0.1)
        };XCTAssertTrue(element.exists && element.isHittable,app.debugDescription)
    }
    @MainActor private func shot(_ app:XCUIApplication,_ name:String) {let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
    @MainActor private func entries(_ app:XCUIApplication)->XCUIElementQuery {app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'bible-entry-'"))}
    @MainActor func testEmptyCookbookChooseDishSearchAndNoTickets() {
        let app=launch(["--test-light","--score-unlock-fixture","10"])
        XCTAssertTrue(app.buttons["bible-empty-add"].waitForExistence(timeout:8));XCTAssertFalse(app.buttons["bible-tickets"].exists);shot(app,"Cookbook empty light")
        app.buttons["bible-add"].tap();app.buttons["bible-manual"].tap();let search=app.textFields["choose-dish-search"];XCTAssertTrue(search.waitForExistence(timeout:8));shot(app,"Choose Dish photos and fallback")
        search.tap();search.typeText("Sea Bass");XCTAssertTrue(app.buttons["Sea Bass with Corn Velouté"].waitForExistence(timeout:5));shot(app,"Choose Dish representative thumbnail");app.buttons["Clear search"].tap()
        search.tap();search.typeText("main");XCTAssertGreaterThan(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'choose-dish-'")).count,1);app.buttons["Clear search"].tap()
        search.tap();search.typeText("Matzo");XCTAssertTrue(app.buttons["Matzo Ball Soup"].waitForExistence(timeout:5));XCTAssertEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'choose-dish-'")).count,1)
        shot(app,"Choose Dish local search");app.buttons["Clear search"].tap();XCTAssertGreaterThan(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'choose-dish-'")).count,1)
        search.tap();search.typeText("Matzo");app.buttons["Matzo Ball Soup"].tap();XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:8));XCTAssertEqual(app.textFields["recipe-edit-title"].value as? String,"Matzo Ball Soup");shot(app,"New recipe identity and quiet editor")
        app.buttons["Cancel"].tap();XCTAssertFalse(app.buttons["Discard Changes"].exists)
    }
    @MainActor func testCookbookIngredientCuisineSourceSearchAndExistingRecipe() {
        let app=launch(["--test-dark","--bible-review","--score-unlock-fixture","10"])
        XCTAssertEqual(entries(app).count,2);shot(app,"Cookbook grid dark")
        let search=app.textFields["bible-search"]
        for term in ["cornmeal","ITALIAN","Home Cookbook"] {
            search.tap();search.typeText(term);XCTAssertGreaterThan(entries(app).count,0);shot(app,"Cookbook search "+term);app.buttons["bible-search-clear"].tap()
        }
        search.tap();search.typeText("Braised");XCTAssertEqual(entries(app).count,1);entries(app).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8));XCTAssertFalse(app.buttons["recipe-ticket"].exists);shot(app,"Recipe reader hero dark")
        reach(app.staticTexts["Polenta"].firstMatch,app:app);shot(app,"Reader ingredients and method dark")
        reach(app.buttons["recipe-make"],app:app);app.buttons["recipe-make"].tap();XCTAssertTrue(app.navigationBars["New Version"].waitForExistence(timeout:8));app.buttons["Cancel"].tap()
    }
    @MainActor func testCreateInlineRecipeSaveFailureRetryAndDetachPreservesCook() {
        let app=launch(["--test-light","--score-unlock-fixture","1","--recipe-save-failure"])
        app.buttons["bible-add"].tap();app.buttons["bible-manual"].tap();app.buttons["Matzo Ball Soup"].tap();XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:8))
        app.buttons["recipe-add-ingredient"].tap();let ingredient=app.textFields["recipe-ingredient-line"];XCTAssertTrue(ingredient.waitForExistence(timeout:5))
        ingredient.typeText("1 cup stock\n2 cloves garlic");app.buttons["recipe-keyboard-done"].tap()
        let addStep=app.buttons["recipe-add-step"];reach(addStep,app:app);addStep.tap();let step=app.textFields["recipe-step-text"];reach(step,app:app);step.tap();step.typeText("Simmer gently.\nTaste before serving.");shot(app,"Inline ingredient and multiline method");app.buttons["recipe-keyboard-done"].tap()
        app.buttons["recipe-save"].tap();XCTAssertTrue(app.staticTexts["recipe-save-error"].waitForExistence(timeout:8));XCTAssertTrue(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'recipe-ingredient-row-' AND label CONTAINS 'stock'")).firstMatch.exists)
        app.buttons["recipe-save"].tap();XCTAssertTrue(app.textFields["bible-search"].waitForExistence(timeout:8));XCTAssertEqual(entries(app).count,1);entries(app).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8));XCTAssertTrue(app.staticTexts["stock"].exists)
        reach(app.buttons["recipe-detach"],app:app);app.buttons["recipe-detach"].tap();app.sheets.buttons["Remove Recipe from Dish"].tap();XCTAssertTrue(app.buttons["bible-empty-add"].waitForExistence(timeout:8))
        app.tabBars.buttons["Grub Rank"].tap();XCTAssertTrue(app.staticTexts["Matzo Ball Soup"].waitForExistence(timeout:8))
    }
    @MainActor func testDraftBackgroundDiscardConfirmationAndOfflineOwnedReader() {
        let app=launch(["--test-light","--bible-review","--score-unlock-fixture","10","--recipe-offline-after-open"])
        let search=app.textFields["bible-search"];search.tap();search.typeText("Lemon");entries(app).firstMatch.tap();XCTAssertTrue(app.buttons["recipe-edit"].waitForExistence(timeout:8));app.buttons["recipe-edit"].tap()
        let title=app.textFields["recipe-edit-title"];title.tap();title.typeText(" unsaved draft");let edited = title.value as? String;XCTAssertTrue(edited?.contains("unsaved draft") == true);XCTAssertTrue(edited?.contains("Lemon Soup") == true);XCUIDevice.shared.press(.home);app.activate();XCTAssertTrue(title.waitForExistence(timeout:10));XCTAssertEqual(title.value as? String,edited)
        app.buttons["Cancel"].tap();XCTAssertTrue(app.buttons["Keep Editing"].waitForExistence(timeout:5));app.buttons["Keep Editing"].tap();XCTAssertEqual(title.value as? String,edited);shot(app,"Preserved draft after background")
        app.buttons["Cancel"].tap();app.buttons["Discard Changes"].tap();XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8));XCTAssertEqual(app.staticTexts["recipe-title"].label,"Lemon Soup");XCTAssertTrue(app.staticTexts["recipe-error"].waitForExistence(timeout:8));shot(app,"Owned recipe remains readable offline")
    }
    @MainActor func testLargeTypeReaderSectionsAndReorderMoveControls() {
        let app=launch(["--test-light","--test-large-type","--test-reduce-motion","--bible-review","--bible-long-review","--score-unlock-fixture","10"])
        let search=app.textFields["bible-search"];search.tap();search.typeText("Braised");app.keyboards.buttons["search"].tap();let card=entries(app).firstMatch;reach(card,app:app);card.tap();XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8));shot(app,"Large type recipe reader")
        app.buttons["recipe-edit"].tap();let names=app.textFields.matching(identifier:"recipe-section-name");XCTAssertTrue(names.firstMatch.waitForExistence(timeout:8))
        let action=app.buttons.matching(NSPredicate(format:"label BEGINSWITH 'Ingredient actions'")).firstMatch;reach(action,app:app);action.tap();app.buttons["Move to…"].tap();app.buttons["Polenta"].tap();shot(app,"Section move with independent handle")
        let add=app.buttons["recipe-add-component"];reach(add,app:app);add.tap();let name=names.element(boundBy:names.count-1);reach(name,app:app);name.tap();name.typeText("Garnish");app.buttons["recipe-keyboard-done"].tap();shot(app,"Large type section editor")
        app.buttons["Cancel"].tap();app.buttons["Discard Changes"].tap();XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8));XCTAssertFalse(app.staticTexts["Garnish"].exists)
    }
    @MainActor func testReorderMoveAndDeleteRowsAndSections() {
        let app=launch(["--test-dark","--bible-review","--score-unlock-fixture","10"])
        let search=app.textFields["bible-search"];search.tap();search.typeText("Braised");app.keyboards.buttons["search"].tap();entries(app).firstMatch.tap();XCTAssertTrue(app.buttons["recipe-edit"].waitForExistence(timeout:8));app.buttons["recipe-edit"].tap()
        let names=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'recipe-ingredient-row-'"))
        let addIngredient=app.buttons.matching(identifier:"recipe-add-ingredient").firstMatch;reach(addIngredient,app:app);addIngredient.tap()
        let newName=app.textFields["recipe-ingredient-line"];XCTAssertTrue(newName.waitForExistence(timeout:5));newName.typeText("salt");app.buttons["recipe-keyboard-done"].tap()
        let salt=app.buttons["Ingredient actions, salt"];reach(salt,app:app);salt.tap();app.buttons["Move Up"].tap();XCTAssertTrue(names.firstMatch.label.hasPrefix("salt."))
        reach(salt,app:app);salt.tap();app.buttons["Move to…"].tap();app.buttons["Polenta"].tap();XCTAssertTrue(names.element(boundBy:2).label.hasPrefix("salt."))
        reach(salt,app:app);salt.tap();XCTAssertFalse(app.buttons["Move Down"].isEnabled);app.buttons["Delete"].tap();app.sheets.buttons["Delete Row"].tap();XCTAssertEqual(names.count,2)
        let addStep=app.buttons.matching(identifier:"recipe-add-step").firstMatch;reach(addStep,app:app);addStep.tap()
        let steps=app.textFields.matching(identifier:"recipe-step-text"),newStep=steps.element(boundBy:1);reach(newStep,app:app);newStep.tap();newStep.typeText("Finish the sauce");app.buttons["recipe-keyboard-done"].tap()
        let finish=app.buttons["Step actions, Finish the sauce"];reach(finish,app:app);finish.tap();app.buttons["Move Up"].tap();XCTAssertEqual(steps.firstMatch.value as? String,"Finish the sauce")
        reach(finish,app:app);finish.tap();app.buttons["Move to…"].tap();app.buttons["Polenta"].tap();XCTAssertEqual(steps.element(boundBy:2).value as? String,"Finish the sauce")
        reach(finish,app:app);finish.tap();app.buttons["Delete"].tap();app.sheets.buttons["Delete Row"].tap();XCTAssertEqual(steps.count,2)
        let polenta=app.buttons["Section actions, Polenta"];reach(polenta,app:app);polenta.tap();app.buttons["Move Section Up"].tap();XCTAssertEqual(app.textFields.matching(identifier:"recipe-section-name").firstMatch.value as? String,"Polenta")
        reach(polenta,app:app);polenta.tap();app.buttons["Move Section Down"].tap();XCTAssertEqual(app.textFields.matching(identifier:"recipe-section-name").firstMatch.value as? String,"Short rib")
        let add=app.buttons["recipe-add-component"];reach(add,app:app);add.tap();let sectionNames=app.textFields.matching(identifier:"recipe-section-name"),last=sectionNames.element(boundBy:2);reach(last,app:app);last.tap();last.typeText("Garnish");app.buttons["recipe-keyboard-done"].tap()
        let garnish=app.buttons["Section actions, Garnish"];reach(garnish,app:app);garnish.tap();app.buttons["Delete Section"].tap();app.sheets.buttons["Delete Section"].tap();XCTAssertEqual(sectionNames.count,2)
        shot(app,"Dedicated reorder and move controls, draft intact")
        app.buttons["recipe-save"].tap();XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8))
    }

    @MainActor private func ingredientRows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'recipe-ingredient-row-'"))
    }
    @MainActor private func selectEntireLine(_ field: XCUIElement, app: XCUIApplication) {
        field.tap();field.press(forDuration:1.2)
        let selectAll=app.menuItems["Select All"], alternate=app.buttons["Select All"]
        if selectAll.waitForExistence(timeout:2) { selectAll.tap() }
        else if alternate.exists { alternate.tap() }
        else {
            let select=app.menuItems["Select"]
            if select.exists { select.tap() }
            if selectAll.exists { selectAll.tap() } else if alternate.exists { alternate.tap() }
            else { XCTFail("Native Select All unavailable: " + app.debugDescription);return }
        }
    }
    @MainActor private func replaceLine(_ field: XCUIElement, with text: String, app: XCUIApplication) {
        selectEntireLine(field,app:app);field.typeText(text)
    }
    @MainActor func testNaturalIngredientRapidEntryCorrectionAndSaveReopen() {
        let app=launch(["--test-dark","--score-unlock-fixture","1"])
        app.buttons["bible-add"].tap();app.buttons["bible-manual"].tap();app.buttons["Matzo Ball Soup"].tap();XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:8))
        app.buttons["recipe-add-ingredient"].tap();let line=app.textFields["recipe-ingredient-line"];XCTAssertTrue(line.waitForExistence(timeout:5));shot(app,"Blank natural ingredient and keyboard")
        line.typeText("1/4 cup of parsley\nparsley 300g\n2 cloves garlic minced\nsalt to taste\na generous handful of parsley\n3-4 tbsp olive oil\n28 oz crushed tomatoes\n1 tsp Calabrian chili\n1 can (28 oz) crushed tomatoes\n2 carrots peeled and sliced\n")
        XCTAssertEqual(line.value as? String,"e.g. 2 tbsp olive oil");shot(app,"Rapid Return retains keyboard and next line")
        line.typeText("\n");XCTAssertEqual(app.textFields.matching(identifier:"recipe-ingredient-line").count,1)
        app.buttons["recipe-keyboard-done"].tap();shot(app,"Parsed fractions metric range and freeform");XCTAssertEqual(ingredientRows(app).count,10,app.debugDescription)
        let garlic=ingredientRows(app).matching(NSPredicate(format:"label CONTAINS 'garlic'")).firstMatch;reach(garlic,app:app);garlic.tap()
        XCTAssertEqual(line.value as? String,"2 cloves garlic minced");replaceLine(line,with:"3 cloves garlic minced",app:app);app.buttons["recipe-keyboard-done"].tap()
        let actions=app.buttons["Ingredient actions, garlic"];reach(actions,app:app);actions.tap();app.buttons["Edit Details"].tap()
        let qty=app.textFields["ingredient-detail-quantity"];XCTAssertTrue(qty.waitForExistence(timeout:5));XCTAssertEqual(qty.value as? String,"3")
        app.textFields["ingredient-detail-note"].tap();app.textFields["ingredient-detail-note"].typeText("plus more for garnish");shot(app,"Structured correction is secondary")
        app.buttons["ingredient-details-done"].tap();app.buttons["recipe-save"].tap();XCTAssertTrue(app.textFields["bible-search"].waitForExistence(timeout:8));entries(app).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8));XCTAssertTrue(app.staticTexts["¼ cup"].exists);shot(app,"Reader natural quantity formatting")
        app.buttons["recipe-edit"].tap();XCTAssertEqual(ingredientRows(app).count,10)
        let restored=ingredientRows(app).matching(NSPredicate(format:"label CONTAINS 'garlic'")).firstMatch;reach(restored,app:app);XCTAssertTrue(restored.label.contains("3 clove"));XCTAssertTrue(restored.label.contains("plus more for garnish"))
    }
    @MainActor func testPartialNaturalLineSurvivesBackgroundAndCancel() {
        let app=launch(["--test-light","--score-unlock-fixture","1"])
        app.buttons["bible-add"].tap();app.buttons["bible-manual"].tap();app.buttons["Matzo Ball Soup"].tap();XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:8))
        app.buttons["recipe-add-ingredient"].tap();let line=app.textFields["recipe-ingredient-line"];XCTAssertTrue(line.waitForExistence(timeout:5));line.typeText("2 tbsp oli...")
        XCUIDevice.shared.press(.home);app.activate()
        if !line.exists { let row=ingredientRows(app).matching(NSPredicate(format:"label CONTAINS 'oli...'")).firstMatch;XCTAssertTrue(row.waitForExistence(timeout:8));row.tap() }
        XCTAssertEqual(line.value as? String,"2 tbsp oli...");shot(app,"Partial original line retained after app switch")
        app.buttons["recipe-editor-cancel"].tap();XCTAssertTrue(app.buttons["Keep Editing"].waitForExistence(timeout:5));app.buttons["Keep Editing"].tap()
        if !line.exists { ingredientRows(app).matching(NSPredicate(format:"label CONTAINS 'oli...'")).firstMatch.tap() }
        XCTAssertEqual(line.value as? String,"2 tbsp oli...")
        app.buttons["Cancel"].tap();app.buttons["Discard Changes"].tap();XCTAssertTrue(app.navigationBars["Choose a Dish"].waitForExistence(timeout:8));app.buttons["Done"].tap();XCTAssertTrue(app.buttons["bible-empty-add"].waitForExistence(timeout:8))
    }
    @MainActor func testNaturalIngredientSectionsAndLargeText() {
        let app=launch(["--test-light","--test-large-type","--test-reduce-motion","--bible-review","--score-unlock-fixture","10"])
        let search=app.textFields["bible-search"];search.tap();search.typeText("Braised");app.keyboards.buttons["search"].tap();entries(app).firstMatch.tap();XCTAssertTrue(app.buttons["recipe-edit"].waitForExistence(timeout:8));app.buttons["recipe-edit"].tap()
        let add=app.buttons.matching(identifier:"recipe-add-ingredient").element(boundBy:1);reach(add,app:app);add.tap();let line=app.textFields["recipe-ingredient-line"];XCTAssertTrue(line.waitForExistence(timeout:5));line.typeText("½ bunch parsley, finely chopped\n")
        line.typeText("a very long handful of fresh herbs from the garden for the final garnish");app.buttons["recipe-keyboard-done"].tap();shot(app,"Large type natural ingredients in Polenta section")
        let action=app.buttons["Ingredient actions, parsley"];reach(action,app:app);action.tap();app.buttons["Move to…"].tap();app.buttons["Short rib"].tap()
        let moved=ingredientRows(app).matching(NSPredicate(format:"label CONTAINS 'parsley'")).firstMatch;reach(moved,app:app);moved.tap();XCTAssertEqual(line.value as? String,"½ bunch parsley, finely chopped")
        app.buttons["recipe-keyboard-done"].tap();app.buttons["recipe-save"].tap();XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8))
    }

    @MainActor func testPasteIngredientLinesStaysInSelectedSection() {
        let app=launch(["--test-dark","--bible-review","--score-unlock-fixture","10"])
        let search=app.textFields["bible-search"];search.tap();search.typeText("Braised");entries(app).firstMatch.tap()
        app.buttons["recipe-edit"].tap();XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:8))
        let paste=app.buttons.matching(identifier:"recipe-paste-ingredients").element(boundBy:1);reach(paste,app:app);paste.tap()
        let input=app.textViews["bulk-ingredient-text"];XCTAssertTrue(input.waitForExistence(timeout:5));input.tap();input.typeText("• 2 tbsp olive oil\n1. 3 cloves garlic minced\n\n- 28 oz crushed tomatoes\n2) salt to taste")
        shot(app,"Bulk ingredient entry dark");app.buttons["bulk-ingredient-format"].tap()
        XCTAssertTrue(app.buttons["Ingredient actions, garlic"].waitForExistence(timeout:8));XCTAssertEqual(ingredientRows(app).count,6)
        let names=ingredientRows(app).allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(names[1].contains("cornmeal"));XCTAssertTrue(names[2].contains("olive oil"));XCTAssertTrue(names[3].contains("garlic"));XCTAssertTrue(names[4].contains("crushed tomatoes"));XCTAssertTrue(names[5].contains("salt"))
        shot(app,"Bulk ingredients formatted into Polenta")
        app.buttons["Cancel"].tap();app.buttons["Discard Changes"].tap();XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8))
    }

    @MainActor func testBulkIngredientsLargeTextAndCancelProtection() {
        let app=launch(["--test-light","--test-large-type","--test-reduce-motion","--bible-review","--score-unlock-fixture","10"])
        let search=app.textFields["bible-search"];search.tap();search.typeText("Braised");entries(app).firstMatch.tap();app.buttons["recipe-edit"].tap()
        XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:8))
        let paste=app.buttons.matching(identifier:"recipe-paste-ingredients").firstMatch;reach(paste,app:app);paste.tap()
        let input=app.textViews["bulk-ingredient-text"];XCTAssertTrue(input.waitForExistence(timeout:5));input.tap();input.typeText("1/2 cup cream\nsalt to taste")
        XCUIDevice.shared.press(.home);app.activate();XCTAssertTrue(input.waitForExistence(timeout:8));XCTAssertEqual(input.value as? String,"1/2 cup cream\nsalt to taste")
        app.navigationBars["Paste Ingredients"].buttons["Cancel"].tap();app.buttons["Keep Editing"].tap()
        let format=app.buttons["bulk-ingredient-format"];reach(format,app:app);shot(app,"Bulk large type Reduce Motion");format.tap()
        XCTAssertTrue(app.buttons["Ingredient actions, cream"].waitForExistence(timeout:8));XCTAssertEqual(ingredientRows(app).count,4)
        app.buttons["recipe-editor-cancel"].tap();app.buttons["Discard Changes"].tap()
    }

}
