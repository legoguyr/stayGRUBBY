import XCTest

/// The Pass redesign (November 17, 2026): captions on the card, comments in a sheet with Hands, and Dish
/// Details with the creator's other shared cooks (Recent / Highest Rated, locked scores never ranked).
final class PassRedesignUITests: StayGrubbyUITestCase {
    private let postID = "20000000-0000-0000-0000-000000000001"
    @MainActor private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--social-review-feed",
                               "--social-review-comment", "--pass-redesign-review", "--recipes-review", "--recipes-review-feed",
                               "--test-reduce-motion", "--test-light"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.tabBars.buttons["The Pass"].tap()
        return app
    }
    @MainActor private func shot(_ name: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    @MainActor private func reach(_ element: XCUIElement, _ app: XCUIApplication) {
        _ = element.waitForExistence(timeout: 4)
        for _ in 0..<8 where !(element.exists && element.isHittable) { app.swipeUp(); _ = element.waitForExistence(timeout: 1) }
        XCTAssertTrue(element.exists && element.isHittable, app.debugDescription)
    }

    @MainActor func testCaptionExpandsAndCommentsSheetWorksWithoutLeavingTheFeed() throws {
        let app = launch()
        let caption = app.staticTexts["post-description-\(postID)"]
        XCTAssertTrue(caption.waitForExistence(timeout: 10))
        XCTAssertTrue(caption.label.hasPrefix("Friendly Cook Marinated overnight"), caption.label)
        let more = app.buttons["post-caption-more-\(postID)"]
        reach(more, app); shot("Pass card caption collapsed", app)
        let collapsed = caption.frame.height
        more.tap()
        XCTAssertFalse(more.waitForExistence(timeout: 1), "more disappears once expanded")
        XCTAssertGreaterThan(caption.frame.height, collapsed, "The full caption shows in place")
        XCTAssertTrue(app.buttons["post-recipe"].exists, "The linked Recipe is on the card")

        let viewComments = app.buttons["social-view-comments-\(postID)"]
        reach(viewComments, app); XCTAssertEqual(viewComments.label, "View 1 comment")
        viewComments.tap()
        XCTAssertTrue(app.navigationBars["Comments"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Harissa Chicken with Roasted Peppers"].exists, "The sheet names the Dish")
        let hands = app.buttons["comments-hands"]; XCTAssertTrue(hands.waitForExistence(timeout: 5))
        hands.tap()
        XCTAssertTrue(NSPredicate(format: "value == '1 Hands'").evaluate(with: hands) || hands.waitForValue("1 Hands"), "Hands work in the sheet")
        XCTAssertTrue(app.buttons["social-report-comment"].exists, "Reporting stays available on others' comments")
        let input = app.textFields["comment-body"]; XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap(); input.typeText("Mint is a great call")
        app.buttons["comment-send"].tap()
        let mine = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Mint is a great call'")).firstMatch
        XCTAssertTrue(mine.waitForExistence(timeout: 8)); shot("Comments sheet", app)
        let delete = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'comment-delete-'")).firstMatch
        XCTAssertTrue(delete.exists, "Your own comment can be 86'd")
        app.navigationBars["Comments"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["social-view-comments-\(postID)"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.navigationBars["Dish Details"].exists, "Comments never pushed a duplicate post screen")
    }

    @MainActor func testDishDetailsShowsContextAndSortsOtherCooksWithoutRankingLockedScores() throws {
        let app = launch()
        let open = app.buttons["post-open-\(postID)"]; XCTAssertTrue(open.waitForExistence(timeout: 10)); open.tap()
        XCTAssertTrue(app.navigationBars["Dish Details"].waitForExistence(timeout: 8))
        let details = app.scrollViews["dish-details"]; XCTAssertTrue(details.waitForExistence(timeout: 8))
        let full = details.staticTexts["post-description-\(postID)"]; XCTAssertTrue(full.waitForExistence(timeout: 8))
        XCTAssertTrue(full.label.contains("handful of mint"), "The full description, not a duplicate card")
        let source = app.descendants(matching: .any)["dish-fact-Source"]; XCTAssertTrue(source.waitForExistence(timeout: 5))
        XCTAssertTrue(source.label.contains("Weeknight Fire"), source.label)
        XCTAssertTrue(app.buttons["post-recipe"].exists && app.buttons["post-recipe-as-posted"].exists, "Live and as-posted Recipe")
        shot("Dish Details top", app)

        let charred = app.buttons["dish-cook-20000000-0000-0000-0000-0000000000A1"]
        let weeknight = app.buttons["dish-cook-20000000-0000-0000-0000-0000000000A2"]
        reach(charred, app); reach(weeknight, app)
        XCTAssertFalse(app.buttons["dish-cook-20000000-0000-0000-0000-0000000000A3"].exists, "Another Dish is never grouped")
        XCTAssertLessThan(weeknight.frame.minY, charred.frame.minY, "Recent first")
        XCTAssertTrue(weeknight.label.contains("Score locked"), weeknight.label)
        shot("Dish Details other cooks recent", app)
        app.buttons["dish-cooks-sort"].press(forDuration: 0.2)
        let highest = app.buttons["Highest Rated"]; XCTAssertTrue(highest.waitForExistence(timeout: 5)); highest.tap()
        XCTAssertTrue(NSPredicate(format: "label CONTAINS 'Highest Rated'").evaluate(with: app.buttons["dish-cooks-sort"]))
        XCTAssertLessThan(charred.frame.minY, weeknight.frame.minY, "Highest Rated puts the unlocked 9.1 first; the locked cook is never ranked")
        shot("Dish Details other cooks highest rated", app)
        charred.tap()
        XCTAssertTrue(app.staticTexts["Charred and smoky"].waitForExistence(timeout: 8), "Each cook opens its own Dish Details")
    }
}

private extension XCUIElement {
    func waitForValue(_ value: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
