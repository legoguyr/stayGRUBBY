import XCTest

final class Stage2OwnerCorrectionUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ extra: [String], store: String = UUID().uuidString, ready: Bool = true) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", store, "--social-review", "--test-reduce-motion"] + (ready ? ["--social-review-ready"] : []) + extra
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15)); return app
    }
    @MainActor private func tab(_ title: String, _ app: XCUIApplication) {
        let target = app.tabBars.buttons[title]
        for _ in 0..<2 {
            target.press(forDuration: 0.2)
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: target)
            if XCTWaiter.wait(for: [selected], timeout: 3) == .completed { return }
        }
        XCTFail("Tab selection failed: \(title)")
    }
    @MainActor private func reach(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        let element = app.descendants(matching: .any).matching(identifier: id).firstMatch
        for _ in 0..<7 { if app.cookingFieldIsVisible(element) { return element }; app.scrollCookingFormToward(element) }
        XCTFail("Field unreachable: \(id)"); return element
    }
    @MainActor private func fill(_ id: String, _ value: String, _ app: XCUIApplication) {
        let field = reach(id, app); field.press(forDuration: 0.2); field.typeText(value)
        let done = app.buttons["cook-keyboard-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.press(forDuration: 0.2)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    }
    @MainActor private func shot(_ title: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = title; a.lifetime = .keepAlways; add(a)
    }
    @MainActor func testOrderedCompactEntryDetailsKeyboardTaggingAndPersistence() {
        let store = UUID().uuidString, app = launch(["--test-light"], store: store)
        app.revealCreation(); app.buttons["new-dish"].press(forDuration: 0.2)
        XCTAssertTrue(app.textFields["dish-name"].waitForExistence(timeout: 8))
        let ids = ["dish-name", "version-title", "cook-dish-description", "cook-date", "cook-dish-private-notes", "cook-details"]
        let frames = ids.map { app.descendants(matching: .any).matching(identifier: $0).firstMatch.frame.minY }
        XCTAssertEqual(frames, frames.sorted())
        XCTAssertFalse(app.staticTexts["Custom tags"].exists); shot("Owner corrections compact entry light", app)
        fill("dish-name", "Lemon Soup", app); fill("version-title", "Sunday", app)
        fill("cook-dish-description", "Bright soup", app); fill("cook-dish-private-notes", "Only my technique", app)
        XCTAssertFalse(app.textFields["cook-notes"].exists, "New Dish must not duplicate Private Notes")
        app.openCookingDetails()
        XCTAssertFalse(app.textFields["cook-notes"].exists, "Fresh cook has no legacy per-cook notes")
        let course = app.descendants(matching: .any).matching(identifier: "cook-course").firstMatch
        course.press(forDuration: 0.2)
        XCTAssertTrue(app.buttons["Soup"].waitForExistence(timeout: 5)); app.buttons["Soup"].press(forDuration: 0.2)
        if app.navigationBars["Course"].exists { app.navigationBars.buttons["Details"].press(forDuration: 0.2) }
        XCTAssertTrue(app.buttons["cook-details-done"].waitForExistence(timeout: 5))
        XCTAssertEqual(course.value as? String, "Soup")
        app.buttons["dish-cuisine"].press(forDuration: 0.2)
        let search = app.searchFields.firstMatch; XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Italian")
        XCTAssertTrue(app.buttons["cuisine-option-italian"].waitForExistence(timeout: 5)); app.buttons["cuisine-option-italian"].press(forDuration: 0.2)
        app.buttons["dish-source-type"].press(forDuration: 0.2)
        XCTAssertTrue(app.buttons["source-choice-myOwn"].waitForExistence(timeout: 5)); app.buttons["source-choice-myOwn"].press(forDuration: 0.2)
        app.buttons["cook-dietary"].press(forDuration: 0.2)
        XCTAssertTrue(app.buttons["filter-dietary-vegetarian"].waitForExistence(timeout: 5)); XCTAssertFalse(app.buttons["filter-dietary-halal"].exists)
        app.buttons["filter-dietary-vegetarian"].press(forDuration: 0.2); app.buttons["filters-done"].press(forDuration: 0.2)
        app.buttons["cook-contains"].press(forDuration: 0.2)
        XCTAssertTrue(app.buttons["contains-milk"].waitForExistence(timeout: 5)); app.buttons["contains-milk"].press(forDuration: 0.2); app.buttons["contains-done"].press(forDuration: 0.2)
        shot("Owner corrections consolidated Details", app); app.closeCookingDetails()
        let tag = reach("cooked-with-open", app); tag.press(forDuration: 0.2)
        let friend = app.buttons["sous-chef-selection-10000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(friend.waitForExistence(timeout: 5)); friend.press(forDuration: 0.2); app.buttons["cooked-with-done"].press(forDuration: 0.2)
        let sharing = app.switches["cook-share-with-friends"]; _ = reach("cook-share-with-friends", app)
        XCTAssertEqual(sharing.value as? String, "0"); shot("Owner corrections compact toggle and tagging", app)
        app.buttons["Continue"].press(forDuration: 0.2); XCTAssertTrue(app.buttons["Liked it"].waitForExistence(timeout: 5)); app.buttons["Liked it"].press(forDuration: 0.2)
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 12)); app.buttons["ranking-result-close"].press(forDuration: 0.2)
        app.terminate(); app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'")).firstMatch
        row.press(forDuration: 0.2); XCTAssertTrue(app.buttons["detail-edit-cook"].waitForExistence(timeout: 5)); app.buttons["detail-edit-cook"].press(forDuration: 0.2)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "cook-dish-description").firstMatch.value as? String, "Bright soup")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "cook-dish-private-notes").firstMatch.value as? String, "Only my technique")
        app.openCookingDetails(); XCTAssertEqual(app.buttons["cook-course"].value as? String, "Soup"); XCTAssertTrue(app.buttons["dish-cuisine"].label.contains("Italian")); XCTAssertTrue(app.buttons["dish-source-type"].label.contains("My Own"))
        XCTAssertTrue(app.buttons["cook-dietary"].label.contains("Vegetarian")); XCTAssertTrue(app.buttons["cook-contains"].label.contains("Milk"))
        app.closeCookingDetails(); app.buttons["Cancel"].press(forDuration: 0.2)
    }
    @MainActor func testCompactSurfacesAlignmentBrowsingAndBottomReachInBothAppearances() {
        for appearance in ["--test-light", "--test-dark"] {
            let app = launch([appearance,"--score-unlock-fixture","10","--compact-layout-review","--recipes-review","--social-review-feed","--product-review-grid"])
            app.buttons["ranking-sort"].press(forDuration: 0.2)
            XCTAssertTrue(app.buttons["Alphabetical"].waitForExistence(timeout: 5)); app.buttons["Alphabetical"].tap()
            XCTAssertTrue(app.buttons["ranking-sort"].label.contains("Alphabetical"))
            app.buttons["ranking-filter-course"].tap(); XCTAssertTrue(app.buttons["filter-course-main"].waitForExistence(timeout: 5)); app.buttons["filter-course-main"].tap(); app.buttons["filters-done"].tap()
            app.buttons["clear-filters"].tap(); shot("Owner corrections browse controls \(appearance)", app)
            tab("My Kitchen", app)
            XCTAssertTrue(app.buttons["share-my-kitchen"].waitForExistence(timeout: 8)); XCTAssertLessThan(app.buttons["share-my-kitchen"].frame.width, 100)
            XCTAssertLessThan(app.buttons["friends-open"].frame.width, 250); XCTAssertFalse(app.staticTexts["Last cooked"].exists)
            let cards = (1...3).map { app.descendants(matching: .any).matching(identifier: "profile-top-food-\($0)").firstMatch }
            XCTAssertTrue(cards[0].waitForExistence(timeout: 8))
            shot("Owner corrections Kitchen before geometry checks \(appearance)", app)
            XCTAssertTrue(cards.allSatisfy(\.exists), app.debugDescription); XCTAssertEqual(cards[0].frame.height, cards[2].frame.height, accuracy: 2)
            XCTAssertLessThan(app.buttons["profile-share-top-three"].frame.width, 100)
            shot("Owner corrections aligned Signature cards \(appearance)", app)
            let exit = app.buttons["development-exit"]
            for _ in 0..<8 { if exit.isHittable && exit.frame.maxY <= app.tabBars.firstMatch.frame.minY { break }; app.scrollViews["kitchen-scroll"].swipeUp() }
            XCTAssertTrue(exit.isHittable); XCTAssertLessThanOrEqual(exit.frame.maxY, app.tabBars.firstMatch.frame.minY)
            shot("Owner corrections Kitchen bottom clearance \(appearance)", app)
            tab("Grub List", app)
            let metadata = app.staticTexts.matching(identifier: "post-course-cuisine").matching(NSPredicate(format: "label == %@", "Main • Italian")).firstMatch
            XCTAssertTrue(metadata.waitForExistence(timeout: 8)); XCTAssertEqual(metadata.label,"Main • Italian")
            XCTAssertTrue(app.staticTexts["Just now"].exists)
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "social-score").firstMatch.exists)
            shot("Owner corrections stable feed metadata \(appearance)", app)
            let comments = app.buttons["social-comments-20000000-0000-0000-0000-000000000001"]
            for _ in 0..<4 { if comments.isHittable && comments.frame.maxY <= app.tabBars.firstMatch.frame.minY { break }; app.swipeUp() }
            XCTAssertTrue(comments.isHittable); comments.press(forDuration: 0.2); XCTAssertTrue(app.navigationBars["Comments"].waitForExistence(timeout: 5)); app.buttons["Done"].tap()
            tab("Food Bible", app)
            XCTAssertTrue(app.buttons["bible-filters"].waitForExistence(timeout: 8)); XCTAssertTrue(app.buttons["bible-sort"].isHittable)
            let count = app.staticTexts["bible-count"]
            for _ in 0..<5 { if count.isHittable && count.frame.maxY <= app.tabBars.firstMatch.frame.minY { break }; app.scrollViews["bible-scroll"].swipeUp() }
            XCTAssertTrue(count.isHittable); XCTAssertLessThanOrEqual(count.frame.maxY, app.tabBars.firstMatch.frame.minY)
            shot("Owner corrections cookbook control family \(appearance)", app); app.terminate()
        }
    }
    @MainActor func testEmptyKitchenAndLargeTypeKeyboardRemainUsable() {
        let app = launch(["--test-dark","--test-large-type","--social-review-no-friends","--bible-v2-empty"], ready: false)
        XCTAssertTrue(app.staticTexts["No dishes yet"].exists); tab("My Kitchen", app)
        XCTAssertTrue(app.staticTexts["Your Kitchen"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["profile-top-food-1"].exists); XCTAssertFalse(app.buttons["profile-share-top-three"].isEnabled)
        shot("Owner corrections empty Kitchen accessibility", app)
        tab("Grub List", app); XCTAssertTrue(app.buttons["Set up Profile"].waitForExistence(timeout: 8))
        tab("Food Bible", app); XCTAssertTrue(app.buttons["bible-empty-add"].waitForExistence(timeout: 8)); shot("Owner corrections empty Food Bible accessibility", app)
        tab("Grub Rank", app); app.revealCreation(); app.buttons["new-dish"].tap()
        fill("dish-name","Large-text soup",app)
        let notes = reach("cook-dish-private-notes", app); notes.tap(); notes.typeText("Private")
        XCTAssertTrue(app.buttons["Continue"].isHittable); XCTAssertTrue(app.buttons["cook-keyboard-done"].isHittable)
        shot("Owner corrections native keyboard accessibility", app); app.buttons["cook-keyboard-done"].tap()
        app.openCookingDetails(); XCTAssertTrue(app.buttons["cook-dietary"].waitForExistence(timeout: 5)); shot("Owner corrections Details accessibility", app)
        app.closeCookingDetails(); app.buttons["Cancel"].tap()
    }
    @MainActor func testSignatureAlignmentAtAccessibilitySize() {
        let app = launch(["--test-dark", "--test-large-type", "--score-unlock-fixture", "10", "--compact-layout-review"])
        tab("My Kitchen", app)
        let cards = (1...3).map { app.descendants(matching: .any).matching(identifier: "profile-top-food-\($0)").firstMatch }
        XCTAssertTrue(cards[0].waitForExistence(timeout: 8))
        for _ in 0..<6 {
            let top = app.navigationBars.firstMatch.frame.maxY
            if cards[0].isHittable && cards[0].frame.minY >= top && cards[0].frame.maxY <= app.tabBars.firstMatch.frame.minY { break }
            if cards[0].frame.minY < top { app.scrollViews["kitchen-scroll"].swipeDown() }
            else { app.scrollViews["kitchen-scroll"].swipeUp() }
        }
        XCTAssertTrue(cards[0].isHittable)
        XCTAssertGreaterThanOrEqual(cards[0].frame.width, 220)
        XCTAssertEqual(cards[0].frame.height, cards[2].frame.height, accuracy: 2)
        shot("Owner corrections Signature alignment accessibility", app)
        let row = app.scrollViews["signature-dishes-row"]
        row.swipeLeft()
        XCTAssertTrue(cards[2].isHittable)
        shot("Owner corrections third Signature accessibility", app)
    }
}
