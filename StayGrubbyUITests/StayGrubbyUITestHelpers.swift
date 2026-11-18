import XCTest

/// Test presentation arguments live only as long as their test app process.
class StayGrubbyUITestCase: XCTestCase {
    override func tearDown() async throws {
        await MainActor.run { XCUIApplication().terminate() }
        try await super.tearDown()
    }
}

extension XCUIApplication {
    @MainActor var rankingHeader: XCUIElement {
        descendants(matching: .any).matching(identifier: "staygrubby-header-rankings").firstMatch
    }
    @MainActor var rankingSearchField: XCUIElement { textFields["ranking-search-field"] }
    @MainActor func launchWithReviewOptions() {
        guard let storeIndex = launchArguments.firstIndex(of: "--ui-test-store"),
              launchArguments.indices.contains(storeIndex + 1), UUID(uuidString: launchArguments[storeIndex + 1]) != nil else {
            XCTFail("Review presentation requires an isolated test-store UUID")
            return
        }
        // Rebuild this argument every launch, including when reusing an app proxy.
        // Appending only for large type left stale UIKit overrides in launchArguments.
        var cleaned: [String] = []
        var index = 0
        while index < launchArguments.count {
            if launchArguments[index] == "-UIPreferredContentSizeCategoryName" { index += 2 }
            else { cleaned.append(launchArguments[index]); index += 1 }
        }
        let category = cleaned.contains("--test-large-type") ?
            "UICTContentSizeCategoryAccessibilityLarge" : "UICTContentSizeCategoryL"
        launchArguments = cleaned + ["-UIPreferredContentSizeCategoryName", category]
        launch()
    }
    /// Grub Rank's + is now Rank a Dish itself; this waits for it (older tests opened a menu first).
    @MainActor func revealCreation() {
        if buttons["new-dish"].waitForExistence(timeout: 15) { return }
        let toggle = buttons["creation-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        for _ in 0..<3 {
            toggle.tap()
            if buttons["new-dish"].waitForExistence(timeout: 3) { return }
        }
        XCTFail("Creation choices did not appear")
    }
    /// Rank a Dish → "Made one of your Dishes again? Choose it" → the Dish picker (replaces the old
    /// separate Cook Again choice, November 18, 2026).
    @MainActor func openExistingDishPicker() {
        revealCreation(); buttons["new-dish"].tap()
        let choose = buttons["cook-existing-dish"]
        XCTAssertTrue(choose.waitForExistence(timeout: 10)); choose.tap()
        XCTAssertTrue(textFields["parent-dish-search"].waitForExistence(timeout: 10))
    }
    /// Older version-specific regressions exercise the complete ranking view.
    /// D1: the All Cooks switch (stored raw values still "Top Version" / "All Versions").
    /// Grub Rank always lists every ranked cook (Nov 18, 2026: the Top / All Cooks toggle was removed).
    /// Kept so older tests read the same; there is nothing to switch.
    @MainActor func showAllVersions() { XCTAssertFalse(switches["rankings-show-all-versions"].exists, "No view toggle") }
    @MainActor var showsAllVersions: Bool { true }
    /// Grub Rank: each filter group has its own chip that opens that group directly.
    @MainActor func openRankingFilterGroup(_ group: String) {
        let chip = buttons["ranking-filter-\(group)"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        let done = buttons["filters-done"].firstMatch
        for _ in 0..<3 { chip.tap(); if done.waitForExistence(timeout: 3) { break }; activate() }
    }
    @MainActor func closeRankingFilters() {
        let done = buttons["filters-done"].firstMatch
        for _ in 0..<3 { if !done.exists { break }; done.tap(); if done.waitForNonExistence(timeout: 3) { break } }
        XCTAssertTrue(buttons["filters-done"].waitForNonExistence(timeout: 10), "The Filters sheet must actually close")
    }
    /// Food Bible uses the same Filters sheet pattern.
    @MainActor func openBibleFilterGroup(_ group: String) {
        // Food Bible uses Grub Rank's direct filter chips: each chip opens its group sheet.
        let chip = buttons["bible-filter-\(group)"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        for _ in 0..<3 { chip.tap(); if buttons["filters-done"].waitForExistence(timeout: 3) { return }; activate() }
        XCTAssertTrue(buttons["filters-done"].waitForExistence(timeout: 5))
    }
    /// Reads a group's chip label ("Course, 1 active").
    @MainActor func rankingFilterLabel(_ group: String) -> String {
        let chip = buttons["ranking-filter-\(group)"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        return chip.label
    }
    @MainActor func revealSearch() {
        if rankingSearchField.waitForExistence(timeout: 10) { return }
        buttons["ranking-search"].tap()
        XCTAssertTrue(rankingSearchField.waitForExistence(timeout: 10))
    }
}

extension XCUIApplication {
    @MainActor func openAccountProfileSettings() {
        for _ in 0..<3 {
            tabBars.buttons["My Kitchen"].tap()
            if buttons["settings-open"].waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(buttons["settings-open"].waitForExistence(timeout: 8), debugDescription)
        buttons["settings-open"].tap()
        XCTAssertTrue(buttons["settings-account"].waitForExistence(timeout: 8), debugDescription)
        buttons["settings-account"].tap()
        XCTAssertTrue(textFields["social-display-name"].waitForExistence(timeout: 8), debugDescription)
    }
}

extension XCUIApplication {
    /// XCTest can mark a partly clipped form control hittable while its center is
    /// behind the fixed Continue/Save action. Scroll until the entire control is visible.
    @MainActor func cookingFieldIsVisible(_ element: XCUIElement) -> Bool {
        guard element.exists && element.isHittable else { return false }
        let top = navigationBars.firstMatch.frame.maxY
        let action = buttons["Continue"].exists ? buttons["Continue"] : buttons["save-cook-metadata"]
        var bottom = action.exists ? action.frame.minY : frame.maxY
        if keyboards.firstMatch.exists { bottom = min(bottom, keyboards.firstMatch.frame.minY) }
        return element.frame.minY >= top && element.frame.maxY <= bottom
    }
    @MainActor func scrollCookingFormToward(_ element: XCUIElement) {
        let form = scrollViews["cooking-form"]
        if element.exists && element.frame.minY < navigationBars.firstMatch.frame.maxY { form.swipeDown() }
        else { form.swipeUp() }
    }
}


extension XCUIApplication {
    @MainActor func openCookingDetails() {
        if buttons["cook-details-done"].exists { return }
        let entry = buttons["cook-details"]
        for _ in 0..<8 {
            if cookingFieldIsVisible(entry) { break }
            scrollCookingFormToward(entry)
        }
        XCTAssertTrue(entry.isHittable); entry.press(forDuration: 0.2)
        XCTAssertTrue(buttons["cook-details-done"].waitForExistence(timeout: 5))
    }
    @MainActor func closeCookingDetails() {
        let done = buttons["cook-details-done"]
        if done.exists { done.press(forDuration: 0.2); XCTAssertTrue(done.waitForNonExistence(timeout: 5)) }
    }
}

// Canonical Recipe actions are native toolbar menu entries, not standalone page buttons.
extension XCUIApplication {
    @MainActor func revealRecipeActions(file: StaticString = #filePath, line: UInt = #line) {
        let menu = buttons["recipe-actions"]
        XCTAssertTrue(menu.waitForExistence(timeout: 8), "Recipe actions unavailable", file: file, line: line)
        // UIKit exposes this Menu through legacy Button attributes; use its actual bounds.
        menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    @MainActor func openRecipeAction(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let action = buttons[id]
        if !action.isHittable { revealRecipeActions(file: file, line: line) }
        XCTAssertTrue(action.waitForExistence(timeout: 5), "Recipe action unavailable: \(id)", file: file, line: line)
        action.press(forDuration: 0.2)
    }
}

// Detail management actions use the same native overflow pattern as Recipes.
extension XCUIApplication {
    @MainActor func cookAction(_ id: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let action = buttons[id]
        if !action.isHittable {
            let menu = buttons["cook-more-actions"]
            XCTAssertTrue(menu.waitForExistence(timeout: 8), "Dish actions unavailable", file: file, line: line)
            menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(action.waitForExistence(timeout: 5), "Dish action unavailable: \(id)", file: file, line: line)
        return action
    }
}
extension XCUIApplication {
    /// Stage F: a new Dish + Recipe from Food Bible offers "Rank Now / Not Now"; tests that only
    /// save Recipes choose Not Now. Returns whether the prompt appeared.
    @MainActor @discardableResult func skipRankPrompt(timeout: TimeInterval = 8) -> Bool {
        let notNow = buttons["rank-prompt-not-now"]
        guard notNow.waitForExistence(timeout: timeout) else { return false }
        notNow.tap(); return true
    }
}

// Connected UI Phase 1: a Recipe opens either in the standalone reader or on the Dish page's Recipe tab,
// whose shared header carries the Dish name (the Recipe title shows separately only when it differs).
extension XCUIApplication {
    @MainActor @discardableResult func waitForRecipeReader(timeout: TimeInterval = 8) -> Bool {
        buttons["recipe-make"].waitForExistence(timeout: timeout)
    }
    /// The Recipe's title as shown: its own title line, else the Dish page header it equals.
    @MainActor var recipeReaderTitle: String {
        let own = staticTexts["recipe-title"]
        return own.exists ? own.label : staticTexts["dish-title"].label
    }
}

extension XCUIElement {
    /// Waits until the element stops moving (a list still coasting after a swipe turns the next tap into
    /// "stop scrolling" instead of activating the control). Returns whether it settled within `timeout`.
    @discardableResult
    func waitUntilSettled(timeout: TimeInterval = 3) -> Bool {
        var last = frame
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.25)
            let next = frame
            if next == last { return true }
            last = next
        }
        return false
    }
    /// Taps a Form Toggle's switch itself. The accessibility tree sometimes exposes only the row (no inner
    /// switch), and tapping the row's centre lands on the label, which never flips a Toggle; a person taps
    /// the switch at the trailing edge.
    func tapSwitchControl() {
        coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }
}
