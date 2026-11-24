import XCTest

/// One description per cook (November 21, 2026; supersedes the Dish-wide Public Description of Nov 18).
/// Two cooks of one Dish keep their own descriptions; the composer saves this cook's text; The Pass shows it,
/// and Edit Description on the post opens that cook's Edit Cook screen. The sibling never changes.
final class PublicDescriptionUITests: StayGrubbyUITestCase {
    @MainActor private func description(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "cook-dish-description").firstMatch
    }
    @MainActor private func replace(_ field: XCUIElement, with text: String, _ app: XCUIApplication) {
        for _ in 0..<6 where !(field.exists && field.isHittable) { app.swipeUp() }
        XCTAssertTrue(field.waitForExistence(timeout: 8)); field.tap()
        let current = (field.value as? String) ?? ""
        if !current.isEmpty, !current.hasPrefix("A few words") {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(text)
        if app.buttons["cook-keyboard-done"].exists { app.buttons["cook-keyboard-done"].tap() }
    }
    @MainActor func testEachCookKeepsItsOwnDescriptionAndThePassEditsTheExactCook() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--test-light", "--test-reduce-motion"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))

        // Cook 1 of Caption Soup, with its own description.
        app.revealCreation(); app.buttons["new-dish"].tap()
        let name = app.textFields["dish-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Caption Soup")
        if app.buttons["cook-keyboard-done"].exists { app.buttons["cook-keyboard-done"].tap() }
        replace(description(app), with: "First pot, very lemony", app)
        app.buttons["Continue"].tap(); app.buttons["Liked it"].tap()
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 15)); app.buttons["ranking-result-close"].tap()
        let notNow = app.buttons["Not Now"]; if notNow.waitForExistence(timeout: 1), notNow.isHittable { notNow.tap() }

        // Cook 2 of the same Dish starts empty (never inherits) and gets its own text in the composer.
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Caption Soup'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8)); row.tap()
        let cookAgain = app.buttons["detail-new-version"]
        for _ in 0..<6 where !cookAgain.isHittable { app.swipeUp() }
        cookAgain.tap()
        XCTAssertTrue(description(app).waitForExistence(timeout: 8))
        XCTAssertNotEqual(description(app).value as? String, "First pot, very lemony", "A new cook never inherits a sibling's description")
        app.buttons["Continue"].tap(); app.buttons["Liked it"].tap()
        let prefer = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Prefer'")).firstMatch
        if prefer.waitForExistence(timeout: 5) { prefer.tap() }
        let share = app.cookAction("share-with-friends"); XCTAssertTrue(share.waitForExistence(timeout: 15)); share.tap()
        let field = app.textViews["post-description-input"].exists ? app.textViews["post-description-input"] : app.textFields["post-description-input"]
        for _ in 0..<5 where !(field.exists && field.isHittable) { app.swipeUp() }
        XCTAssertTrue(field.waitForExistence(timeout: 8)); field.tap(); field.typeText("Second pot, smoky")
        let publish = app.buttons["social-share-publish"]
        for _ in 0..<5 where !publish.isHittable { app.swipeUp() }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: publish)], timeout: 8), .completed)
        publish.tap()
        XCTAssertTrue(app.descendants(matching: .any)["social-share-success"].waitForExistence(timeout: 20), "Saved on the cook, synced, then posted")
        app.buttons["social-share-done"].tap()
        if app.buttons["ranking-result-close"].waitForExistence(timeout: 3) { app.buttons["ranking-result-close"].tap() }

        // The Pass shows the posted cook's text; Edit Description opens that cook's Edit Cook screen.
        app.tabBars.buttons["The Pass"].tap()
        let caption = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'post-description-'")).firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 10)); XCTAssertTrue(caption.label.hasSuffix("Second pot, smoky"), caption.label)
        let menu = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'post-actions-'")).firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 8)); menu.tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'post-edit-'")).firstMatch.tap()
        let edit = description(app)
        XCTAssertTrue(edit.waitForExistence(timeout: 8), "Edit Description opens Edit Cook")
        XCTAssertEqual(edit.value as? String, "Second pot, smoky")
        replace(edit, with: "Second pot, smoky and bright", app)
        let save = app.buttons["save-cook-metadata"]
        for _ in 0..<6 where !save.isHittable { app.swipeUp() }
        save.tap()
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label ENDSWITH 'Second pot, smoky and bright'"), object: caption)
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 15), .completed, "The caption is the cook's description")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Pass caption follows its cook"; shot.lifetime = .keepAlways; add(shot)

        // The sibling cook kept its own description.
        app.tabBars.buttons["Grub Rank"].tap()
        if !app.rankingHeader.exists { app.navigationBars.buttons.element(boundBy: 0).tap() }
        XCTAssertTrue(row.waitForExistence(timeout: 8)); row.tap()
        let firstCook = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Version 1' OR label CONTAINS 'First'")).firstMatch
        if firstCook.waitForExistence(timeout: 5) { for _ in 0..<6 where !firstCook.isHittable { app.swipeUp() }; firstCook.tap() }
        let text = app.staticTexts["dish-public-description"]
        XCTAssertTrue(text.waitForExistence(timeout: 8))
        XCTAssertTrue(["First pot, very lemony", "Second pot, smoky and bright"].contains(text.label))
    }
}
