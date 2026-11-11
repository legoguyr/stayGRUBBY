import XCTest

final class SharedSocialUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--shared-review", "--social-review-feed"] + extra
        app.launchWithReviewOptions(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15)); return app
    }
    @MainActor private func notifications(_ app: XCUIApplication) {
        for _ in 0..<3 {
            app.tabBars.buttons["The Pass"].tap()
            if app.navigationBars["The Pass"].waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(app.navigationBars["The Pass"].waitForExistence(timeout: 5), app.debugDescription)
        let link = app.buttons["notifications-open"]
        XCTAssertTrue(link.waitForExistence(timeout: 8), app.debugDescription)
        for _ in 0..<3 {
            link.tap()
            if app.navigationBars["Tickets"].waitForExistence(timeout: 3) { return }
        }
        XCTAssertTrue(app.navigationBars["Tickets"].waitForExistence(timeout: 8), app.debugDescription)
    }
    @MainActor private func invite(_ app: XCUIApplication) {
        notifications(app)
        let row = app.buttons["notification-50000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(row.waitForExistence(timeout: 8)); row.tap()
        if !app.buttons["shared-begin"].waitForExistence(timeout: 3), row.exists && row.isHittable { row.tap() }
        XCTAssertTrue(app.buttons["shared-begin"].waitForExistence(timeout: 8), app.debugDescription)
    }
    @MainActor private func finish(_ app: XCUIApplication, title: String) {
        app.buttons["Continue"].tap(); XCTAssertTrue(app.buttons["Liked it"].waitForExistence(timeout: 5)); app.buttons["Liked it"].tap()
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 12), app.debugDescription)
        XCTAssertEqual(app.staticTexts["result-dish-title"].label, title)
        XCTAssertFalse(app.staticTexts["result-score"].exists)
    }
    @MainActor func testInvitationJoinRanksOwnCookAndCannotJoinTwice() throws {
        let app = launch(["--test-dark"]); invite(app); app.buttons["shared-begin"].tap()
        let name = app.textFields["dish-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 8)); XCTAssertEqual(name.value as? String, "Lemon Chicken Together")
        finish(app, title: "Lemon Chicken Together")
        app.buttons["ranking-result-close"].tap()
        XCTAssertTrue(app.buttons["shared-begin"].waitForExistence(timeout: 8)); app.buttons["shared-begin"].tap()
        XCTAssertTrue(app.buttons["View my saved cook"].waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Joined"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.textFields["dish-name"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Shared cook saved independently, duplicate join prevented"; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor func testDeclineAddsNoPrivateCooking() throws {
        let app = launch(["--test-light"]); invite(app); app.buttons["shared-decline"].tap()
        XCTAssertTrue(app.staticTexts["Invitation declined. Nothing was added to your cooking history."].waitForExistence(timeout: 8))
        app.tabBars.buttons["Grub Rank"].tap(); XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Lemon Chicken Together"].exists)
        app.revealCreation(); app.buttons["new-version"].tap()
        XCTAssertFalse(app.buttons["choose-dish-Lemon Chicken Together"].exists)
    }
    @MainActor func testRunItBackEntryIsHiddenWithoutRemovingSharedCooking() throws {
        let app = launch(["--test-light"]); app.tabBars.buttons["The Pass"].tap()
        XCTAssertTrue(app.buttons["post-open-20000000-0000-0000-0000-000000000001"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["recreate-20000000-0000-0000-0000-000000000001"].exists)
        XCTAssertFalse(app.buttons["Run It Back"].exists)
        notifications(app)
        XCTAssertTrue(app.buttons["notification-50000000-0000-0000-0000-000000000001"].waitForExistence(timeout: 8))
    }
    @MainActor func testNotificationReadAllAtLightAccessibilitySize() throws {
        let app = launch(["--test-light", "--test-large-type"]); notifications(app)
        let unread = app.staticTexts["notifications-unread"]
        XCTAssertTrue(unread.waitForExistence(timeout: 8)); XCTAssertEqual(unread.label, "6 New Tickets")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Notifications light accessibility size"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Mark All Read"].tap()
        let read = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == '0 New Tickets'"), object: unread)
        XCTAssertEqual(XCTWaiter.wait(for: [read], timeout: 8), .completed)
        XCTAssertFalse(app.buttons["Mark All Read"].isEnabled)
    }
    @MainActor func testCookedWithOnlyCurrentFriendsQueuesAfterRanking() throws {
        let app = launch(["--test-dark"]); app.revealCreation(); app.buttons["new-dish"].tap()
        let name = app.textFields["dish-name"]; XCTAssertTrue(name.waitForExistence(timeout: 8)); name.tap(); name.typeText("Dinner Together\n")
        let friend = app.buttons["cooked-with-10000000-0000-0000-0000-000000000001"]
        let form = app.scrollViews["cooking-form"]
        // Scroll until the avatar is fully above the pinned Continue bar (hittable alone is not enough).
        let continueBar = app.buttons["Continue"]
        for _ in 0..<8 {
            if friend.exists && friend.isHittable && (!continueBar.exists || friend.frame.maxY < continueBar.frame.minY) { break }
            form.swipeUp()
        }
        XCTAssertTrue(friend.waitForExistence(timeout: 5)); XCTAssertLessThan(friend.frame.maxY, continueBar.frame.minY, "The last form row can scroll clear of Continue")
        XCTAssertEqual(friend.value as? String, "Not selected"); friend.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Selected'"), object: friend)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed, app.debugDescription)
        XCTAssertFalse(app.buttons["cooked-with-10000000-0000-0000-0000-000000000002"].exists)
        finish(app, title: "Dinner Together"); app.buttons["ranking-result-close"].tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", Dinner Together, score ")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), app.debugDescription); row.tap()
        let participants = app.buttons["cook-collaborators"]
        for _ in 0..<6 { if participants.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(participants.waitForExistence(timeout: 8))
        XCTAssertTrue(participants.label.contains("Cooked with Friendly Cook"), participants.label); participants.tap()
        XCTAssertTrue(app.staticTexts["Invited"].waitForExistence(timeout: 8))
        app.buttons["Remove invitation for Friendly Cook"].tap()
        XCTAssertTrue(app.staticTexts["Removed"].waitForExistence(timeout: 8))
    }
    @MainActor func testFriendRequestNotificationRoutesToRecipientActions() throws {
        let app = launch(["--test-light"]); notifications(app)
        let row = app.buttons["notification-50000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(row.waitForExistence(timeout: 8)); row.tap()
        let accept = app.buttons["friend-action-accept"]
        if !accept.waitForExistence(timeout: 3), row.isHittable { row.tap() }
        XCTAssertTrue(accept.waitForExistence(timeout: 8)); accept.tap()
        XCTAssertTrue(app.staticTexts["Sous Chef"].waitForExistence(timeout: 8))
    }
    @MainActor func testCommentNotificationRoutesAndBlockHidesInaccessibleActivity() throws {
        let app = launch(["--test-dark", "--social-review-comment"]); notifications(app)
        let row = app.buttons["notification-50000000-0000-0000-0000-000000000005"]
        for _ in 0..<4 { if row.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 8)); row.tap()
        XCTAssertTrue(app.navigationBars["Comments"].waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(app.staticTexts["A friendly cooking comment"].waitForExistence(timeout: 5))
        app.navigationBars["Comments"].buttons["Done"].tap()
        let profile = app.buttons["View Friendly Cook’s profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 8)); profile.tap()
        app.buttons["friend-profile-actions"].tap()
        XCTAssertTrue(app.buttons["Block"].waitForExistence(timeout: 5)); app.buttons["Block"].tap(); app.buttons["Block Person"].tap()
        XCTAssertTrue(app.staticTexts["Post unavailable"].waitForExistence(timeout: 8), app.debugDescription)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Tickets"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["notification-50000000-0000-0000-0000-000000000001"].exists)
        XCTAssertEqual(app.staticTexts["notifications-unread"].label, "1 New Ticket")
    }
}
