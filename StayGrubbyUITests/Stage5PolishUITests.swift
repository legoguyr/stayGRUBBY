import XCTest

final class Stage5PolishUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--ui-test-store",UUID().uuidString,"--social-review","--social-review-ready","--recipes-review","--stage5-review","--score-unlock-fixture","10","--test-reduce-motion"]+extra
        app.launchWithReviewOptions();XCTAssertTrue(app.rankingHeader.waitForExistence(timeout:15));app.tabBars.buttons["My Kitchen"].tap();XCTAssertTrue(app.buttons["settings-open"].waitForExistence(timeout:8));return app
    }
    @MainActor private func reach(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<14 {
            if element.exists && element.isHittable && element.frame.minY > 104 && element.frame.maxY < app.frame.maxY-90 { return }; if element.exists && element.frame.minY < 104 { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.exists && element.isHittable,app.debugDescription)
    }
    @MainActor private func shot(_ name: String,_ app: XCUIApplication) { let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a) }
    @MainActor func testOwnKitchenRecipesOpenReaderAndFoodBibleRoot() {
        let app=launch(["--test-light"])
        let cards=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'kitchen-recipe-'"));reach(cards.firstMatch,app)
        XCTAssertEqual(cards.count,2);XCTAssertFalse(app.staticTexts["PRIVATE RECIPE MUST STAY HIDDEN"].exists)
        cards.firstMatch.tap();XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8));XCTAssertFalse(app.buttons["recipe-units"].exists)
        app.navigationBars.buttons.element(boundBy:0).tap()
        let all=app.buttons["kitchen-recipes-all"];reach(all,app);shot("V1 own Kitchen Recipe preview light",app);all.tap()
        XCTAssertTrue(app.buttons["bible-add"].waitForExistence(timeout:8));XCTAssertTrue(app.tabBars.buttons["Food Bible"].isSelected)
        let entries=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'bible-entry-'"));XCTAssertEqual(entries.count,3)
        XCTAssertFalse(app.staticTexts["PRIVATE RECIPE MUST STAY HIDDEN"].exists)
        app.tabBars.buttons["My Kitchen"].tap();app.buttons["settings-open"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout:5));let policy=app.buttons["privacy-policy-open"];reach(policy,app);policy.tap()
        XCTAssertTrue(app.navigationBars["Privacy Policy"].waitForExistence(timeout:8));XCTAssertTrue(app.buttons["Done"].exists)
        app.buttons["Done"].tap();XCTAssertTrue(app.navigationBars["Settings"].exists)
    }
    @MainActor func testOtherKitchenShowsOnlyAuthorizedRecipesAtLargeType() {
        let app=launch(["--test-dark","--test-large-type"]);app.buttons["friends-open"].tap()
        let friend=app.buttons["friend-person-friend_cook"];XCTAssertTrue(friend.waitForExistence(timeout:8));friend.tap()
        let card=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'kitchen-recipe-' AND label CONTAINS 'Sous Chef Lemon Cake'")).firstMatch;reach(card,app)
        XCTAssertFalse(app.staticTexts["PRIVATE RECIPE MUST STAY HIDDEN"].exists);shot("V1 authorized Kitchen Recipes dark large type",app)
        card.tap();XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout:8));app.revealRecipeActions();XCTAssertFalse(app.buttons["recipe-edit"].exists);XCTAssertFalse(app.buttons["recipe-delete"].exists)
    }
    @MainActor func testRecipePreviewOfflineAndEmptyRecoveryKeepsNavigation() {
        let app=launch(["--test-light","--stage5-recipes-offline"])
        let retry=app.buttons["kitchen-recipes-retry"];reach(retry,app);retry.tap();XCTAssertTrue(retry.waitForExistence(timeout:5))
        app.buttons["kitchen-recipes-all"].tap();XCTAssertTrue(app.buttons["bible-add"].waitForExistence(timeout:8))
        XCTAssertFalse(app.buttons["recipe-units"].exists);shot("V1 Recipe preview error recovery",app)
    }
}
