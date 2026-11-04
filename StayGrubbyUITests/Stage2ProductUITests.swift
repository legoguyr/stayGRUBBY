import XCTest

final class Stage2ProductUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ extra: [String] = [], store: String = UUID().uuidString) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", store, "--social-review", "--social-review-ready", "--recipes-review", "--social-review-feed", "--test-reduce-motion"] + extra
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15)); return app
    }
    @MainActor private func select(_ title: String, _ app: XCUIApplication) {
        let tab = app.tabBars.buttons[title]
        for _ in 0..<2 {
            tab.tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: tab)
            if XCTWaiter.wait(for: [selected], timeout: 3) == .completed { return }
        }
        XCTFail("Tab did not select: \(title)")
    }
    @MainActor private func reach(_ element: XCUIElement, _ app: XCUIApplication) {
        if ["dish-cuisine", "dish-source-type"].contains(element.identifier) { app.openCookingDetails(); return }
        app.closeCookingDetails()
        for _ in 0..<10 {
            if app.cookingFieldIsVisible(element) { return }
            app.scrollCookingFormToward(element)
        }
        XCTFail("Unreachable control: \(element.identifier)")
    }
    @MainActor private func fill(_ identifier: String, _ value: String, _ app: XCUIApplication) {
        let field = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        reach(field, app); field.tap(); field.typeText(value)
        let done = app.buttons["cook-keyboard-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    }
    @MainActor private func shot(_ name: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    @MainActor func testCookEntryDishTextMetadataTaggingAndPersistence() {
        let store = UUID().uuidString, app = launch(["--test-light"], store: store)
        app.revealCreation(); app.buttons["new-dish"].tap()
        XCTAssertTrue(app.textFields["dish-name"].waitForExistence(timeout: 8))
        shot("Stage 2 New Dish light", app)
        fill("dish-name", "Stage 2 Soup", app)
        fill("cook-dish-description", "Bright lemon soup", app)
        fill("cook-dish-private-notes", "Only my Dish technique", app)
        let cuisine = app.buttons["dish-cuisine"]; reach(cuisine, app); cuisine.tap()
        XCTAssertTrue(app.buttons["cuisine-option-italian"].waitForExistence(timeout: 5)); app.buttons["cuisine-option-italian"].tap()
        let source = app.buttons["dish-source-type"]; reach(source, app); source.tap()
        XCTAssertTrue(app.buttons["source-choice-myOwn"].waitForExistence(timeout: 5)); app.buttons["source-choice-myOwn"].tap()
        let tag = app.buttons["cooked-with-open"]; reach(tag, app); tag.tap()
        XCTAssertTrue(app.navigationBars["Tag a Sous Chef"].waitForExistence(timeout: 8))
        let search = app.searchFields.firstMatch; search.tap(); search.typeText("Friendly")
        let friend = app.buttons["sous-chef-selection-10000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(friend.waitForExistence(timeout: 8)); friend.tap()
        XCTAssertEqual(friend.value as? String, "Selected")
        XCTAssertFalse(app.buttons["sous-chef-selection-10000000-0000-0000-0000-000000000002"].exists)
        shot("Stage 2 Sous Chef selection light", app)
        app.buttons["cooked-with-done"].tap()
        XCTAssertTrue(tag.waitForExistence(timeout: 8)); shot("Stage 2 compact metadata and tagging", app)
        app.buttons["Continue"].tap(); XCTAssertTrue(app.buttons["Liked it"].waitForExistence(timeout: 8)); app.buttons["Liked it"].tap()
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 12)); app.buttons["ranking-result-close"].tap()
        app.terminate(); app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8)); row.tap(); app.buttons["cook-more-actions"].tap(); app.buttons["dish-text-edit"].tap()
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "dish-text-public").firstMatch.value as? String, "Bright lemon soup")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "dish-text-private").firstMatch.value as? String, "Only my Dish technique")
        app.buttons["Cancel"].tap(); app.buttons["detail-edit-cook"].tap()
        let editedDescription = app.descendants(matching: .any).matching(identifier: "cook-dish-description").firstMatch
        reach(editedDescription, app)
        XCTAssertEqual(editedDescription.value as? String, "Bright lemon soup")
        app.buttons["Cancel"].tap()
    }
    @MainActor func testCompactKitchenSignaturesFeedAndAuthorizedProfile() {
        for appearance in ["--test-light", "--test-dark"] {
            let app = launch([appearance, "--score-unlock-fixture", "10", "--product-review-grid"])
            select("My Kitchen", app)
            XCTAssertTrue(app.staticTexts["@review_cook"].waitForExistence(timeout: 8))
            let first = app.descendants(matching: .any).matching(identifier: "profile-top-food-1").firstMatch
            let third = app.descendants(matching: .any).matching(identifier: "profile-top-food-3").firstMatch
            shot("Stage 2 Kitchen initial \(appearance)", app)
            XCTAssertTrue(first.waitForExistence(timeout: 8) && third.exists, app.debugDescription)
            XCTAssertEqual(first.frame.minY, third.frame.minY, accuracy: 2)
            XCTAssertGreaterThan(first.frame.width, 90); XCTAssertLessThan(first.frame.width, 150)
            shot("Stage 2 compact Kitchen \(appearance)", app)
            app.buttons["friends-open"].tap()
            XCTAssertTrue(app.buttons["friend-person-friend_cook"].waitForExistence(timeout: 8)); app.buttons["friend-person-friend_cook"].tap()
            XCTAssertTrue(app.staticTexts["@friend_cook"].waitForExistence(timeout: 8))
            XCTAssertFalse(app.staticTexts["Signature Dishes"].exists)
            XCTAssertFalse(app.staticTexts["Private Notes"].exists)
            shot("Stage 2 authorized Kitchen \(appearance)", app)
            app.buttons["Done"].tap()
            select("Grub List", app)
            let score = app.descendants(matching: .any).matching(identifier: "social-score").firstMatch
            XCTAssertTrue(score.waitForExistence(timeout: 8))
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '/ 10'")).firstMatch.exists)
            shot("Stage 2 food-first Grub List \(appearance)", app)
            app.terminate()
        }
    }
    @MainActor func testMultiPhotoCoverEditorKeepsSavedCollectionOnCancel() {
        let app = launch(["--test-light", "--score-unlock-fixture", "10", "--multi-photo-review"])
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8)); row.tap()
        XCTAssertTrue(app.buttons["detail-edit-cook"].waitForExistence(timeout: 8)); app.buttons["detail-edit-cook"].tap()
        let collection = app.descendants(matching: .any).matching(identifier: "cook-photo-collection").firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 8)); XCTAssertTrue(collection.label.contains("2 photos"))
        shot("Stage 2 multi-photo cover editing", app)
        app.buttons["Remove"].tap(); app.buttons["Cancel"].tap()
        app.buttons["detail-edit-cook"].tap()
        XCTAssertTrue(collection.waitForExistence(timeout: 8)); XCTAssertTrue(collection.label.contains("2 photos"))
        XCTAssertTrue(app.buttons["Replace Photo"].exists)
        app.buttons["Cancel"].tap()
    }
    @MainActor func testSingleSignatureRemainsCompactAndLocked() {
        let app = launch(["--test-light", "--score-unlock-fixture", "1"])
        select("My Kitchen", app)
        let first = app.descendants(matching: .any).matching(identifier: "profile-top-food-1").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 8))
        XCTAssertLessThan(first.frame.width, 150); XCTAssertGreaterThan(first.frame.width, 90)
        XCTAssertTrue(first.label.contains("score locked"))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "profile-top-food-2").firstMatch.exists)
        XCTAssertFalse(app.buttons["profile-share-top-three"].isEnabled)
        shot("Stage 2 single compact locked Signature", app)
    }
    @MainActor func testLargeTypePortraitBrandingAndCookEntry() {
        let app = launch(["--test-dark", "--test-large-type", "--score-unlock-fixture", "9"])
        XCTAssertTrue(app.buttons["creation-toggle"].isHittable && app.buttons["ranking-search"].isHittable)
        shot("Stage 2 Grub Rank dark accessibility", app)
        select("My Kitchen", app)
        XCTAssertTrue(app.buttons["settings-open"].waitForExistence(timeout: 8)); XCTAssertTrue(app.buttons["notifications-open"].isHittable)
        shot("Stage 2 Kitchen dark accessibility", app)
        select("Grub Rank", app); app.revealCreation(); app.buttons["new-dish"].tap()
        let field = app.descendants(matching: .any).matching(identifier: "cook-dish-private-notes").firstMatch
        reach(field, app); XCTAssertTrue(field.isHittable)
        shot("Stage 2 Dish text dark accessibility", app)
        let tag = app.buttons["cooked-with-open"]; reach(tag, app); tag.tap()
        XCTAssertTrue(app.buttons["cooked-with-done"].waitForExistence(timeout: 8)); XCTAssertTrue(app.buttons["cooked-with-done"].isHittable)
        shot("Stage 2 Sous Chef sheet dark accessibility", app)
        app.buttons["cooked-with-done"].tap(); app.buttons["Cancel"].tap()
    }
}
