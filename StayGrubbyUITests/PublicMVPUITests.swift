import XCTest

/// Public MVP (November 16, 2026): new-account setup, existing-account compatibility and blocking.
final class PublicMVPUITests: StayGrubbyUITestCase {
    @MainActor private func launch(_ arguments: [String], store: String = UUID().uuidString) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", store, "--social-review", "--test-reduce-motion"] + arguments
        app.launchWithReviewOptions()
        return app
    }
    @MainActor private func type(_ field: XCUIElement, _ text: String, replacing: Bool = false) {
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        for _ in 0..<3 {
            field.tap()
            let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
            if XCTWaiter.wait(for: [focused], timeout: 3) == .completed {
                if replacing, let current = field.value as? String, !current.isEmpty {
                    field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
                }
                field.typeText(text); return
            }
        }
        XCTFail("Text field did not acquire keyboard focus")
    }
    @MainActor private func shot(_ name: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    @MainActor func testNewAccountSetupIsRequiredUniquePrivateByDefaultAndResumes() throws {
        let store = UUID().uuidString
        var app = launch(["--onboarding-review", "--test-light"], store: store)
        let title = app.staticTexts["onboarding-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15)); XCTAssertEqual(title.label, "Set up your Kitchen")
        XCTAssertFalse(app.buttons["onboarding-not-now"].exists, "A new account must finish setup")
        XCTAssertFalse(app.descendants(matching: .any)["onboarding-terms-agreement"].exists, "Terms stay hidden until legal_terms is enabled")
        let next = app.buttons["onboarding-continue"]
        XCTAssertFalse(next.isEnabled)
        type(app.textFields["onboarding-name"], "New Cook")
        type(app.textFields["onboarding-username"], "taken_name")
        shot("Onboarding · profile", app)
        next.tap()
        let error = app.staticTexts["onboarding-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 8)); XCTAssertEqual(error.label, "That username is taken. Try another.")
        XCTAssertEqual(title.label, "Set up your Kitchen", "Stays on the profile step")
        type(app.textFields["onboarding-username"], "new_cook", replacing: true)
        XCTAssertFalse(error.exists, "Editing the username clears the taken message")
        next.tap()
        XCTAssertTrue(app.staticTexts["Who can find you?"].waitForExistence(timeout: 8))
        let privateChoice = app.buttons["onboarding-private"], publicChoice = app.buttons["onboarding-public"]
        XCTAssertTrue(privateChoice.isSelected, "Private is preselected"); XCTAssertFalse(publicChoice.isSelected)
        shot("Onboarding · privacy", app)

        // Closing the app mid-setup resumes it (the in-memory review backend forgets the saved username,
        // so setup returns to the profile step with the entered values kept).
        app.terminate()
        app = launch(["--onboarding-review", "--test-light"], store: store)
        XCTAssertTrue(app.staticTexts["onboarding-title"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.textFields["onboarding-username"].value as? String, "new_cook")
        XCTAssertEqual(app.textFields["onboarding-name"].value as? String, "New Cook")
        app.buttons["onboarding-continue"].tap()
        XCTAssertTrue(app.buttons["onboarding-public"].waitForExistence(timeout: 8))
        app.buttons["onboarding-public"].tap(); XCTAssertTrue(app.buttons["onboarding-public"].isSelected)
        app.buttons["onboarding-continue"].tap()
        XCTAssertTrue(app.staticTexts["Add a profile photo"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["onboarding-continue"].label, "Finish")
        app.buttons["onboarding-continue"].tap()

        // Build 7: the kitchen tour follows setup in the same flow. Next/Back move between pages.
        let firstPage = app.descendants(matching: .any)["tutorial-page-0"]
        XCTAssertTrue(firstPage.waitForExistence(timeout: 10), "New accounts continue into the kitchen tour")
        XCTAssertFalse(app.buttons["tutorial-back"].exists, "No Back on the first page")
        shot("Tour · Dish and cooks", app)
        app.buttons["tutorial-next"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["tutorial-page-1"].waitForExistence(timeout: 5))
        app.buttons["tutorial-back"].tap()
        XCTAssertTrue(firstPage.waitForExistence(timeout: 5))
        app.buttons["tutorial-next"].tap()

        for index in 2..<4 {
            app.buttons["tutorial-next"].tap()
            XCTAssertTrue(app.descendants(matching: .any)["tutorial-page-\(index)"].waitForExistence(timeout: 5))
        }
        XCTAssertFalse(app.buttons["tutorial-skip"].exists, "The last page ends with Get Started")
        shot("Tour · The Pass", app)
        app.buttons["tutorial-get-started"].tap()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["ranking-empty-rank-dish"].waitForExistence(timeout: 5), "A clear first action in Grub Rank")
        shot("First run · Grub Rank", app)
        XCTAssertFalse(app.staticTexts["onboarding-title"].exists)
        // The choice reached the profile: Public is on.
        app.openAccountProfileSettings()
        XCTAssertTrue(app.switches["social-discoverable"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.switches["social-discoverable"].value as? String, "1")
        XCTAssertEqual(app.textFields["social-username"].value as? String, "new_cook")
    }

    /// Build 7: closing the app mid-tour resumes the tour (never setup); Skip and Settings replay never
    /// bring it back on a later launch.
    @MainActor func testInterruptedTourResumesOnceAndReplaysFromSettings() throws {
        let store = UUID().uuidString
        var app = launch(["--onboarding-review", "--test-light"], store: store)
        XCTAssertTrue(app.staticTexts["onboarding-title"].waitForExistence(timeout: 15))
        type(app.textFields["onboarding-name"], "Tour Cook")
        type(app.textFields["onboarding-username"], "tour_cook")
        app.buttons["onboarding-continue"].tap()
        XCTAssertTrue(app.buttons["onboarding-private"].waitForExistence(timeout: 8)); app.buttons["onboarding-continue"].tap()
        XCTAssertTrue(app.staticTexts["Add a profile photo"].waitForExistence(timeout: 8)); app.buttons["onboarding-continue"].tap()
        let firstPage = app.descendants(matching: .any)["tutorial-page-0"]
        XCTAssertTrue(firstPage.waitForExistence(timeout: 10))
        app.buttons["tutorial-next"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["tutorial-page-1"].waitForExistence(timeout: 5))
        app.buttons["tutorial-pick-1"].tap()
        XCTAssertTrue(app.buttons["tutorial-pick-1"].isSelected, "Picking a card is interactive and records nothing")

        app.terminate()
        app = launch(["--onboarding-review", "--test-light"], store: store)
        XCTAssertTrue(firstPage.waitForExistence(timeout: 15), "An interrupted tour resumes")
        XCTAssertFalse(app.staticTexts["onboarding-title"].exists, "Setup is not repeated")
        app.buttons["tutorial-skip"].tap()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 10))

        // Replay from Settings records nothing.
        for _ in 0..<3 {
            app.tabBars.buttons["My Kitchen"].tap()
            if app.buttons["settings-open"].waitForExistence(timeout: 3) { break }
        }
        app.buttons["settings-open"].tap()
        let replay = app.buttons["settings-tutorial"]
        XCTAssertTrue(replay.waitForExistence(timeout: 8))
        for _ in 0..<4 where !replay.isHittable { app.swipeUp() }
        replay.tap()
        XCTAssertTrue(firstPage.waitForExistence(timeout: 5)); XCTAssertEqual(app.buttons["tutorial-skip"].label, "Close")
        app.buttons["tutorial-skip"].tap()
        XCTAssertTrue(firstPage.waitForNonExistence(timeout: 5))

        app.terminate()
        app = launch(["--onboarding-review", "--test-light"], store: store)
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        XCTAssertFalse(firstPage.waitForExistence(timeout: 4), "The tour shows once")
    }

    /// App Review 1.2 integration point, built ahead: with `legal_terms` on, setup shows the agreement
    /// line and Settings links the Terms and Community Guidelines.
    @MainActor func testLegalTermsAppearOnlyWithTheirFlag() throws {
        var app = launch(["--onboarding-review", "--test-light", "--feature-flag", "legal_terms"], store: UUID().uuidString)
        let agreement = app.descendants(matching: .any)["onboarding-terms-agreement"]
        XCTAssertTrue(agreement.waitForExistence(timeout: 15))
        XCTAssertTrue(agreement.label.contains("Terms of Use") && agreement.label.contains("Community Guidelines"))
        shot("Onboarding · terms agreement (flag on)", app)
        app.terminate()
        app = launch(["--social-review-ready", "--test-light", "--feature-flag", "legal_terms"], store: UUID().uuidString)
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        for _ in 0..<3 {
            app.tabBars.buttons["My Kitchen"].tap()
            if app.buttons["settings-open"].waitForExistence(timeout: 3) { break }
        }
        app.buttons["settings-open"].tap()
        for _ in 0..<5 where !(app.buttons["settings-terms"].exists || app.links["settings-terms"].exists) { app.swipeUp() }
        XCTAssertTrue(app.buttons["settings-terms"].exists || app.links["settings-terms"].exists)
        XCTAssertTrue(app.buttons["settings-guidelines"].exists || app.links["settings-guidelines"].exists)
    }

    @MainActor func testExistingAccountsAreOfferedSetupOnceAndConfiguredAccountsNever() throws {
        // An existing library without a username: offered once, Not Now is respected on relaunch.
        let store = UUID().uuidString
        var app = launch(["--onboarding-review", "--discovery-fixture", "--test-dark"], store: store)
        let notNow = app.buttons["onboarding-not-now"]
        XCTAssertTrue(notNow.waitForExistence(timeout: 15)); shot("Onboarding · existing account offer", app)
        notNow.tap()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 10))
        let cook = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'")).firstMatch
        XCTAssertTrue(cook.waitForExistence(timeout: 10), "The existing library is intact")
        app.terminate()
        app = launch(["--onboarding-review", "--discovery-fixture", "--test-dark"], store: store)
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["onboarding-title"].waitForExistence(timeout: 4), "Not offered again")
        XCTAssertFalse(app.descendants(matching: .any)["tutorial-page-0"].exists, "Existing accounts bypass the tour")
        app.terminate()
        // A configured account never sees setup.
        app = launch(["--onboarding-review", "--social-review-ready", "--test-dark"])
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["onboarding-title"].waitForExistence(timeout: 4))
    }

    @MainActor func testBlockingFromAPostConfirmsAndHidesTheirPosts() throws {
        let app = launch(["--social-review-ready", "--social-review-feed", "--test-light"])
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.tabBars.buttons["The Pass"].tap()
        let actions = app.buttons["post-actions-20000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(actions.waitForExistence(timeout: 10)); actions.tap()
        XCTAssertTrue(app.buttons["social-report-post"].waitForExistence(timeout: 5), "Report post is offered")
        app.buttons["Block account"].firstMatch.tap()
        let confirm = app.sheets.buttons["Block account"].exists ? app.sheets.buttons["Block account"] : app.buttons.matching(NSPredicate(format: "label == 'Block account'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        XCTAssertTrue(app.alerts["Account blocked"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.alerts["Account blocked"].staticTexts.matching(NSPredicate(format: "label CONTAINS 'Blocked Accounts'")).firstMatch.exists)
        shot("Block confirmation", app)
        app.alerts["Account blocked"].buttons["OK"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: actions)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 10), .completed, "Their posts are hidden after blocking")
    }
}
