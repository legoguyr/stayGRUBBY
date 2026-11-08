import XCTest

final class Stage5PolishUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--ui-test-store",UUID().uuidString,"--social-review","--social-review-ready","--recipes-review","--stage5-review","--v1-closeout-review","--social-review-feed","--score-unlock-fixture","10","--test-reduce-motion"]+extra
        app.launchWithReviewOptions();XCTAssertTrue(app.rankingHeader.waitForExistence(timeout:15));app.tabBars.buttons["My Kitchen"].tap();XCTAssertTrue(app.buttons["settings-open"].waitForExistence(timeout:8));return app
    }
    @MainActor private func reach(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<14 {
            if element.exists && element.isHittable && element.frame.minY > 104 && element.frame.maxY < app.frame.maxY-90 { return }
            if element.exists && element.frame.minY < 104 { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.exists && element.isHittable,app.debugDescription)
    }
    @MainActor private func openRecipes(_ app: XCUIApplication) {
        let button=app.buttons["kitchen-recipes-open"];reach(button,app);button.tap();XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout:8))
    }
    @MainActor private func shot(_ name: String,_ app: XCUIApplication) { let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a) }
    @MainActor func testOwnKitchenCompactRecipesSheetOpensCorrectReaderAndKeepsPrivateAudience() {
        let app=launch(["--test-light"])
        XCTAssertTrue(app.descendants(matching:.any)["profile-dish-count"].exists)
        XCTAssertFalse(app.buttons["kitchen-recipes-all"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'kitchen-recipe-'")).count,0)
        openRecipes(app)
        let privateRecipe=app.buttons["kitchen-recipe-60000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(privateRecipe.waitForExistence(timeout:8));XCTAssertEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'kitchen-recipe-'")).count,3)
        XCTAssertFalse(app.staticTexts["PRIVATE RECIPE MUST STAY HIDDEN"].exists);shot("Closeout owned Recipes sheet light",app)
        privateRecipe.tap();XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8));XCTAssertEqual(app.staticTexts["recipe-title"].label,"Lemon Soup Recipe")
        XCTAssertFalse(app.buttons["recipe-units"].exists);XCTAssertTrue(app.images["recipe-sharing-off"].exists)
        app.openRecipeAction("recipe-edit")
        let toggle=app.switches["recipe-sharing"];reach(toggle,app);XCTAssertEqual(toggle.value as? String,"0")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH 'Off keeps this Recipe private'")).firstMatch.exists)
        app.buttons["recipe-editor-cancel"].tap()
    }
    @MainActor func testKitchenRecipeSearchAndCompactReaderInBothAppearances() {
        for appearance in ["--test-light", "--test-dark"] {
            let app = launch([appearance]); openRecipes(app)
            let search = app.searchFields.firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: 8)); search.tap(); search.typeText("lemon")
            let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'kitchen-recipe-'"))
            XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 5))
            XCTAssertEqual(cards.count, 1)
            search.typeText(" no-match")
            XCTAssertTrue(app.descendants(matching: .any)["kitchen-recipes-no-results"].waitForExistence(timeout: 5))
            search.buttons["Clear text"].tap(); search.typeText("lemon")
            if app.keyboards.buttons["Search"].exists { app.keyboards.buttons["Search"].tap() }
            cards.firstMatch.tap()
            XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 8))
            // This fixture is private: inactive Share remains secondary by design.
            XCTAssertTrue(app.images["recipe-sharing-off"].exists)
            app.revealRecipeActions(); app.buttons["recipe-edit"].tap()
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Suggested servings and times'")).firstMatch.exists)
            app.buttons["recipe-editor-cancel"].tap()
            app.terminate()
        }
    }
    @MainActor func testOtherKitchenAuthorizedRecipesShareAndSendAtLargeType() {
        let app=launch(["--test-dark","--test-large-type"]);app.buttons["friends-open"].tap()
        let friend=app.buttons["friend-person-friend_cook"];XCTAssertTrue(friend.waitForExistence(timeout:8));friend.tap();openRecipes(app)
        let card=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'kitchen-recipe-' AND label CONTAINS 'Sous Chef Lemon Cake'")).firstMatch;reach(card,app)
        XCTAssertFalse(app.staticTexts["PRIVATE RECIPE MUST STAY HIDDEN"].exists);shot("Closeout authorized Recipes sheet dark accessibility",app)
        card.tap();XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8));XCTAssertTrue(app.buttons["recipe-share-link"].exists)
        app.revealRecipeActions();XCTAssertFalse(app.buttons["recipe-edit"].exists);XCTAssertFalse(app.buttons["recipe-delete"].exists)
        let send=app.buttons["recipe-send-friend"];XCTAssertTrue(send.waitForExistence(timeout:5),app.debugDescription);send.press(forDuration:0.2);let recipient=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'send-recipient-'")).firstMatch
        XCTAssertTrue(recipient.waitForExistence(timeout:8));reach(recipient,app);recipient.tap();app.buttons["social-send-confirm"].tap()
        XCTAssertTrue(app.descendants(matching:.any)["social-send-success"].waitForExistence(timeout:8))
    }
    @MainActor func testDishRecipeSideIsOneViewRecipeOrAddRecipeRow() {
        let app = launch(["--test-light"]); app.tabBars.buttons["Grub Rank"].tap()
        let cook = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'" )).firstMatch
        XCTAssertTrue(cook.waitForExistence(timeout: 8)); cook.tap()
        XCTAssertTrue(app.buttons["cook-more-actions"].waitForExistence(timeout: 8))
        let view = app.buttons["dish-view-recipe"], add = app.buttons["dish-add-recipe"]
        for _ in 0..<8 where !(view.exists || add.exists) { app.swipeUp() }
        XCTAssertTrue(view.exists || add.exists, app.debugDescription)
        XCTAssertFalse(app.buttons["dish-link-recipe"].exists); XCTAssertFalse(app.buttons["dish-recipes-add"].exists)
        if add.exists {
            reach(add, app); XCTAssertGreaterThanOrEqual(add.frame.height, 44); add.tap()
            XCTAssertTrue(app.buttons["dish-recipe-manual"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["dish-recipe-import"].exists)
            app.buttons["dish-recipe-manual"].tap(); XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout: 8))
            shot("Add Recipe to this Dish", app); app.buttons["recipe-editor-cancel"].tap()
            XCTAssertTrue(add.waitForExistence(timeout: 8))
        } else {
            reach(view, app); XCTAssertGreaterThanOrEqual(view.frame.height, 44); shot("View Recipe row", app)
        }
    }
    @MainActor func testRecipeSheetOfflineRetryAndDismissKeepsKitchen() {
        let app=launch(["--test-light","--stage5-recipes-offline"]);openRecipes(app)
        let retry=app.buttons["kitchen-recipes-retry"];XCTAssertTrue(retry.waitForExistence(timeout:8));retry.tap();XCTAssertTrue(retry.waitForExistence(timeout:5))
        app.navigationBars.buttons["Done"].tap();XCTAssertTrue(app.buttons["settings-open"].waitForExistence(timeout:8))
    }
    @MainActor func testRecipeSheetEmptyState() {
        let app=launch(["--bible-v2-empty"]);openRecipes(app)
        XCTAssertTrue(app.staticTexts["kitchen-recipes-empty"].waitForExistence(timeout:8));XCTAssertFalse(app.buttons["kitchen-recipes-all"].exists)
    }
    @MainActor func testNewRecipeDefaultAndGrubListShowsNoRecipeOnlyActivity() {
        let app=launch(["--test-light"]);app.tabBars.buttons["Food Bible"].tap();app.buttons["bible-add"].tap();XCTAssertTrue(app.buttons["bible-manual"].waitForExistence(timeout:8));app.buttons["bible-manual"].tap()
        let toggle=app.switches["recipe-sharing"];reach(toggle,app);XCTAssertEqual(toggle.value as? String,"1");app.buttons["recipe-editor-cancel"].tap()
        XCTAssertTrue(app.buttons["bible-manual"].waitForExistence(timeout:5));app.navigationBars.buttons["Done"].tap()
        // Grub List is Dish/cook activity only: a Sous Chef's new Recipe is not an activity item.
        app.tabBars.buttons["Grub List"].tap()
        XCTAssertTrue(app.descendants(matching:.any)["grub-list"].waitForExistence(timeout:8))
        XCTAssertTrue(app.descendants(matching:.any).matching(NSPredicate(format:"identifier BEGINSWITH 'post-open-'")).firstMatch.waitForExistence(timeout:8), "Cook posts still appear")
        XCTAssertFalse(app.descendants(matching:.any).matching(NSPredicate(format:"identifier BEGINSWITH 'feed-recipe-'")).firstMatch.exists)
        shot("Grub List without Recipe-only activity",app)
    }
    @MainActor func testEditCookTagsLoadSaveAndCancel() {
        let app = launch(["--test-light"])
        app.tabBars.buttons["Grub Rank"].tap()
        let row = app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'cook-row-'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8)); row.tap()
        func openEditor() {
            app.cookAction("detail-edit-cook").press(forDuration: 0.2)
            XCTAssertTrue(app.navigationBars["Edit Cook"].waitForExistence(timeout: 8))
        }
        func openPicker() {
            let picker = app.buttons["cooked-with-open"]
            reach(picker, app); picker.tap()
            XCTAssertTrue(app.navigationBars["Tag a Sous Chef"].waitForExistence(timeout: 8))
        }
        let friend = app.buttons["sous-chef-selection-10000000-0000-0000-0000-000000000001"]
        openEditor(); openPicker()
        XCTAssertTrue(friend.waitForExistence(timeout: 8)); friend.tap()
        XCTAssertEqual(friend.value as? String, "Selected")
        app.buttons["cooked-with-done"].tap()
        app.buttons["save-cook-metadata"].tap()
        XCTAssertTrue(app.navigationBars["Dish Details"].waitForExistence(timeout: 8))
        openEditor(); openPicker()
        XCTAssertTrue(friend.waitForExistence(timeout: 8)); XCTAssertEqual(friend.value as? String, "Selected")
        friend.tap(); app.buttons["cooked-with-done"].tap(); app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Dish Details"].waitForExistence(timeout: 8))
        openEditor(); openPicker()
        XCTAssertTrue(friend.waitForExistence(timeout: 8)); XCTAssertEqual(friend.value as? String, "Selected")
        friend.tap(); app.buttons["cooked-with-done"].tap(); app.buttons["save-cook-metadata"].tap()
        XCTAssertTrue(app.navigationBars["Dish Details"].waitForExistence(timeout: 8))
    }

    @MainActor func testDishToolbarEditAndRerankUseNativeActionsMenu() {
        let app=launch(["--test-dark"]);app.tabBars.buttons["Grub Rank"].tap()
        let row=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'cook-row-'")).firstMatch;XCTAssertTrue(row.waitForExistence(timeout:8));row.tap()
        XCTAssertTrue(app.navigationBars["Dish Details"].waitForExistence(timeout:8));let share=app.buttons["detail-share-dish"],menu=app.buttons["cook-more-actions"]
        XCTAssertTrue(share.exists && menu.exists);XCTAssertEqual(share.frame.midY,menu.frame.midY,accuracy:3);XCTAssertFalse(app.buttons["detail-edit-cook"].exists)
        shot("Closeout native Dish toolbar dark",app);app.cookAction("detail-edit-cook").press(forDuration:0.2);XCTAssertTrue(app.navigationBars["Edit Cook"].waitForExistence(timeout:8),app.debugDescription);app.buttons["Cancel"].tap()
        app.cookAction("detail-rerank").press(forDuration:0.2);XCTAssertTrue(app.buttons["Liked it"].waitForExistence(timeout:8));app.buttons["Cancel"].tap();XCTAssertTrue(menu.waitForExistence(timeout:8))
    }
}
