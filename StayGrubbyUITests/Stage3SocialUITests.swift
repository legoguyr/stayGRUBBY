import XCTest
import UIKit

final class Stage3SocialUITests: StayGrubbyUITestCase {
    @MainActor func testRecipeShareAndSearchableSousChefSend() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--recipes-review", "--stage3-review-sharing", "--stage3-send-failure", "--v1-multi-send-review", "--test-dark", "--review-profile-url", "https://staygrubby.com/r/60000000-0000-0000-0000-000000000001"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 15), app.debugDescription)
        let toolbar = XCTAttachment(screenshot: app.screenshot()); toolbar.name = "Recipe active Share and overflow accent red, dark"; toolbar.lifetime = .keepAlways; add(toolbar)
        app.openRecipeAction("recipe-send-friend")
        XCTAssertTrue(app.navigationBars["Send to Sous Chefs"].waitForExistence(timeout: 5))
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("friend_cook")
        let row = app.buttons["send-recipient-10000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        search.tap(); search.buttons["Clear text"].tap(); search.typeText("incoming_cook")
        let second = app.buttons["send-recipient-10000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(second.waitForExistence(timeout: 5)); second.tap()
        XCTAssertTrue(app.staticTexts["2 selected"].exists)
        let confirm = app.buttons["social-send-confirm"]
        XCTAssertTrue(confirm.isEnabled); confirm.tap()
        XCTAssertTrue(app.staticTexts["social-send-error"].waitForExistence(timeout: 5))
        XCTAssertTrue(confirm.isEnabled); confirm.tap()
        XCTAssertTrue(app.descendants(matching: .any)["social-send-success"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["social-send-done"].tap()
        XCTAssertTrue(app.navigationBars["Recipe"].waitForExistence(timeout: 5))
        app.terminate(); app.launchArguments = app.launchArguments.map { $0 == "--test-dark" ? "--test-light" : $0 }
        app.launchWithReviewOptions(); XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 15))
        let light = XCTAttachment(screenshot: app.screenshot()); light.name = "Recipe active Share and overflow accent red, light"; light.lifetime = .keepAlways; add(light)
        XCTAssertTrue(app.buttons["recipe-share-link"].exists && app.buttons["recipe-actions"].exists)
    }
    @MainActor func testNativeDishCopyProducesUsefulSheetPayload() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--sharing-fixture", "detail", "--test-light"]
        app.launchWithReviewOptions()
        let share = app.buttons["detail-share-dish"]
        XCTAssertTrue(share.waitForExistence(timeout: 15))
        for _ in 0..<4 { if share.isHittable { break }; app.swipeUp() }; share.tap()
        let copy = app.cells.matching(identifier: "actionGroupCell").matching(NSPredicate(format: "label == 'Copy'")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 15), app.debugDescription)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Stage 3 native image and caption share"; shot.lifetime = .keepAlways; add(shot)
        let previousCopy = UIPasteboard.general.changeCount
        copy.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let copied = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { UIPasteboard.general.changeCount > previousCopy && (UIPasteboard.general.hasImages || UIPasteboard.general.hasStrings) }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for:[copied],timeout:8),.completed,"Native Copy must produce a fresh image/text payload")
        let close = app.buttons["header.closeButton"]
        if close.exists { close.coordinate(withNormalizedOffset: CGVector(dx:0.5,dy:0.5)).tap() }
        XCTAssertTrue(copy.waitForNonExistence(timeout:8))
        XCTAssertTrue(share.waitForExistence(timeout: 5))
    }
    @MainActor func testDirectedOrderUpDestinationsUseAuthorizedReaders() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--recipes-review", "--social-review-feed", "--stage3-review-sharing", "--test-light"]
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.tabBars.buttons["Grub List"].tap()
        let bell = app.buttons["notifications-open"]; XCTAssertTrue(bell.waitForExistence(timeout: 8)); bell.tap()
        let recipe = app.buttons["notification-50000000-0000-0000-0000-000000000007"]
        XCTAssertTrue(recipe.waitForExistence(timeout: 8)); recipe.tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 8)); XCTAssertEqual(app.staticTexts["recipe-title"].label, "Lemon Soup Recipe")
        app.navigationBars.buttons["Order Up!"].tap()
        XCTAssertEqual(app.staticTexts["notifications-unread"].label, "1 unread")
        let post = app.buttons["notification-50000000-0000-0000-0000-000000000008"]
        XCTAssertTrue(post.waitForExistence(timeout: 8)); post.tap()
        XCTAssertTrue(app.navigationBars["Post"].waitForExistence(timeout: 8))
        let send = app.buttons["post-send-friend"]
        let actions = app.buttons["post-actions-20000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(actions.waitForExistence(timeout: 8)); actions.tap()
        XCTAssertTrue(send.waitForExistence(timeout: 5)); send.tap()
        let recipient = app.buttons["send-recipient-10000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(recipient.waitForExistence(timeout: 5)); recipient.tap()
        app.buttons["social-send-confirm"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["social-send-success"].waitForExistence(timeout: 5))
    }

    @MainActor func testNoPhotoFallbackHasNativeCopyPayload() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--sharing-fixture", "fallback", "--test-dark"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.staticTexts["sharing-review-dimensions"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["sharing-review-dimensions"].label, "1080 × 1080")
        let share = app.buttons["detail-share-dish"]
        for _ in 0..<5 { if share.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(share.waitForExistence(timeout: 5)); share.tap()
        let copy = app.cells.matching(identifier: "actionGroupCell").matching(NSPredicate(format: "label == 'Copy'")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 10)); copy.press(forDuration: 0.2)
        if !copy.waitForNonExistence(timeout: 2), copy.isHittable { copy.press(forDuration: 0.2) }
        XCTAssertTrue(copy.waitForNonExistence(timeout: 8))
    }

    @MainActor func testCommentsComposerLeavesListVisibleInBothAppearances() throws {
        continueAfterFailure = false
        for appearance in ["--test-light", "--test-dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--social-review-feed", "--social-review-comment", appearance]
            app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
            app.tabBars.buttons["Grub List"].tap()
            let comments = app.buttons["social-comments-20000000-0000-0000-0000-000000000001"]
            for _ in 0..<4 { if comments.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(comments.waitForExistence(timeout: 8)); comments.tap()
            let input = app.textFields["comment-body"]
            XCTAssertTrue(input.waitForExistence(timeout: 5)); input.tap(); input.typeText("Saved as a draft")
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["A friendly cooking comment"].exists)
            XCTAssertLessThanOrEqual(input.frame.maxY, app.keyboards.firstMatch.frame.minY)
            XCTAssertTrue(app.buttons["comment-send"].isHittable)
            let a = XCTAttachment(screenshot: app.screenshot()); a.name = "Stage 3 Comments keyboard \(appearance)"; a.lifetime = .keepAlways; add(a)
            app.terminate()
        }
    }

}
