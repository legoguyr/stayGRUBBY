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
    @MainActor func revealCreation() {
        if buttons["new-dish"].exists { return }
        let toggle = buttons["creation-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        for _ in 0..<3 {
            toggle.tap()
            if buttons["new-dish"].waitForExistence(timeout: 3) { return }
        }
        XCTFail("Creation choices did not appear")
    }
    /// Older version-specific regressions exercise the complete ranking view.
    /// Stage B moved Top Version / All Versions into the Sort & View menu.
    @MainActor func showAllVersions() { setRankingDisplay(allVersions: true) }
    @MainActor func setRankingDisplay(allVersions: Bool) {
        let sort = buttons["ranking-sort"]
        XCTAssertTrue(sort.waitForExistence(timeout: 15))
        let showing = { (sort.value as? String ?? "").contains("All Versions") == allVersions }
        if showing() { return }
        let item = buttons[allVersions ? "rankings-display-all" : "rankings-display-top"]
        for _ in 0..<3 {
            sort.tap()
            if item.waitForExistence(timeout: 3) { item.tap(); break }
            activate()
        }
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: allVersions ? "value CONTAINS 'All Versions'" : "NOT (value CONTAINS 'All Versions')"), object: sort)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed, "Ranking view must actually change")
    }
    @MainActor var showsAllVersions: Bool { (buttons["ranking-sort"].value as? String ?? "").contains("All Versions") }
    /// Stage B Grub Rank: one Filters sheet whose group rows push their options.
    @MainActor func openRankingFilterGroup(_ group: String) {
        let link = buttons["ranking-filter-\(group)"]
        if !link.exists {
            let open = buttons["ranking-filters"]
            XCTAssertTrue(open.waitForExistence(timeout: 10))
            for _ in 0..<3 { open.tap(); if link.waitForExistence(timeout: 3) { break }; activate() }
        }
        XCTAssertTrue(link.waitForExistence(timeout: 10)); link.tap()
    }
    @MainActor func closeRankingFilters() {
        let done = buttons["filters-done"].firstMatch
        for _ in 0..<3 { if !done.exists { break }; done.tap(); if done.waitForNonExistence(timeout: 3) { break } }
        XCTAssertTrue(buttons["filters-done"].waitForNonExistence(timeout: 10), "The Filters sheet must actually close")
    }
    /// Food Bible uses the same Filters sheet pattern.
    @MainActor func openBibleFilterGroup(_ group: String) {
        let link = buttons["bible-filter-\(group)"]
        if !link.exists {
            let open = buttons["bible-filters-open"]
            XCTAssertTrue(open.waitForExistence(timeout: 10))
            for _ in 0..<3 { open.tap(); if link.waitForExistence(timeout: 3) { break }; activate() }
        }
        XCTAssertTrue(link.waitForExistence(timeout: 10)); link.tap()
    }
    /// Reads a group's summary row ("Course, 1 active selections") without leaving it open.
    @MainActor func rankingFilterLabel(_ group: String) -> String {
        let open = buttons["ranking-filters"]
        XCTAssertTrue(open.waitForExistence(timeout: 10)); open.tap()
        let link = buttons["ranking-filter-\(group)"]
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        let label = link.label
        closeRankingFilters()
        return label
    }
    @MainActor func revealSearch() {
        if rankingSearchField.exists { return }
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
