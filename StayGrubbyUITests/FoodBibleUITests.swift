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
        app.buttons["bible-add"].tap();let search=app.textFields["choose-dish-search"];XCTAssertTrue(search.waitForExistence(timeout:8));shot(app,"Choose Dish photos and fallback")
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
        app.buttons["bible-add"].tap();app.buttons["Matzo Ball Soup"].tap();XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout:8))
        app.buttons["recipe-add-ingredient"].tap();let qty=app.textFields["Ingredient quantity"];XCTAssertTrue(qty.waitForExistence(timeout:5));qty.typeText("1\n");app.textFields["Ingredient unit, for example cup or g"].typeText("cup\n")
        let ingredient=app.textFields["recipe-ingredient-name"].firstMatch;ingredient.typeText("stock\n");XCTAssertEqual(app.textFields.matching(identifier:"Ingredient quantity").count,2);app.textFields.matching(identifier:"Ingredient quantity").element(boundBy:1).typeText("2\n");app.textFields.matching(identifier:"Ingredient unit, for example cup or g").element(boundBy:1).typeText("cloves\n");app.textFields.matching(identifier:"recipe-ingredient-name").element(boundBy:1).typeText("garlic");app.buttons["recipe-keyboard-done"].tap()
        let addStep=app.buttons["recipe-add-step"];reach(addStep,app:app);addStep.tap();let step=app.textFields["recipe-step-text"];reach(step,app:app);step.tap();step.typeText("Simmer gently.\nTaste before serving.");shot(app,"Inline ingredient and multiline method");app.buttons["recipe-keyboard-done"].tap()
        app.buttons["recipe-save"].tap();XCTAssertTrue(app.staticTexts["recipe-save-error"].waitForExistence(timeout:8));XCTAssertEqual(ingredient.value as? String,"stock")
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
        let names=app.textFields.matching(identifier:"recipe-ingredient-name")
        let addIngredient=app.buttons.matching(identifier:"recipe-add-ingredient").firstMatch;reach(addIngredient,app:app);addIngredient.tap()
        let newName=names.element(boundBy:1);reach(newName,app:app);newName.tap();newName.typeText("salt");app.buttons["recipe-keyboard-done"].tap()
        let salt=app.buttons["Ingredient actions, salt"];reach(salt,app:app);salt.tap();app.buttons["Move Up"].tap();XCTAssertEqual(names.firstMatch.value as? String,"salt")
        reach(salt,app:app);salt.tap();app.buttons["Move to…"].tap();app.buttons["Polenta"].tap();XCTAssertEqual(names.element(boundBy:2).value as? String,"salt")
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

}
