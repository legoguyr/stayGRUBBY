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
    @MainActor func testRecipeSheetOfflineRetryAndDismissKeepsKitchen() {
        let app=launch(["--test-light","--stage5-recipes-offline"]);openRecipes(app)
        let retry=app.buttons["kitchen-recipes-retry"];XCTAssertTrue(retry.waitForExistence(timeout:8));retry.tap();XCTAssertTrue(retry.waitForExistence(timeout:5))
        app.navigationBars.buttons["Done"].tap();XCTAssertTrue(app.buttons["settings-open"].waitForExistence(timeout:8))
    }
    @MainActor func testRecipeSheetEmptyState() {
        let app=launch(["--bible-v2-empty"]);openRecipes(app)
        XCTAssertTrue(app.staticTexts["kitchen-recipes-empty"].waitForExistence(timeout:8));XCTAssertFalse(app.buttons["kitchen-recipes-all"].exists)
    }
    @MainActor func testNewRecipeDefaultAndDistinctGrubListRecipeDestination() {
        let app=launch(["--test-light"]);app.tabBars.buttons["Food Bible"].tap();app.buttons["bible-add"].tap();XCTAssertTrue(app.buttons["bible-manual"].waitForExistence(timeout:8));app.buttons["bible-manual"].tap()
        let toggle=app.switches["recipe-sharing"];reach(toggle,app);XCTAssertEqual(toggle.value as? String,"1");app.buttons["recipe-editor-cancel"].tap()
        XCTAssertTrue(app.buttons["bible-manual"].waitForExistence(timeout:5));app.navigationBars.buttons["Done"].tap()
        app.tabBars.buttons["Grub List"].tap()
        let recipe=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'feed-recipe-open-'")).firstMatch;reach(recipe,app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS 'Added a new Recipe'")).firstMatch.exists)
        shot("Closeout distinct new Recipe Grub List activity",app);recipe.tap();XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8));XCTAssertEqual(app.staticTexts["recipe-title"].label,"Sous Chef Lemon Cake")
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
