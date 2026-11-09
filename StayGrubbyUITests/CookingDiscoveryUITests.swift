import XCTest

final class CookingDiscoveryUITests: StayGrubbyUITestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(largeType: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--discovery-fixture",
                               largeType ? "--test-light" : "--test-dark"]
        if largeType { app.launchArguments.append("--test-large-type") }
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.showAllVersions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        return app
    }

    @MainActor private func wait(_ predicate: String, on element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)],
                      timeout: timeout) == .completed
    }

    @MainActor private func reach(_ element: XCUIElement, in app: XCUIApplication, scrollDown: Bool = false) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            if scrollDown { app.swipeDown() } else { app.swipeUp() }
        }
        XCTFail("Could not reach \(element)")
    }

    @MainActor private func transition(_ button: XCUIElement, to next: XCUIElement, in app: XCUIApplication) {
        reach(button, in: app)
        for _ in 0..<3 {
            button.tap()
            if next.waitForExistence(timeout: 5) { return }
        }
        XCTFail("Transition did not reach \(next)")
    }

    @MainActor private func search(_ query: String, in app: XCUIApplication) {
        app.revealSearch()
        let field = app.rankingSearchField
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        XCTAssertTrue(wait("hasKeyboardFocus == true", on: field))
        let current = field.value as? String ?? ""
        if current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(query + "\n")
        XCTAssertTrue(wait("value == '\(query)'", on: field))
    }

    @MainActor private func row(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS %@", name)).firstMatch
    }

    @MainActor private func select(_ option: XCUIElement, in app: XCUIApplication) {
        reach(option, in: app)
        // A group sheet still settling its detent after a scroll can drop one tap;
        // retry only while unselected (a second tap would deselect it).
        for _ in 0..<3 {
            if option.value as? String == "Selected" { return }
            option.tap()
            if wait("value == 'Selected'", on: option, timeout: 3) { return }
        }
        XCTAssertTrue(wait("value == 'Selected'", on: option))
    }

    @MainActor private func filters(_ group: String, in app: XCUIApplication) {
        // Each Grub Rank filter group has its own chip that opens it directly.
        app.openRankingFilterGroup(group)
        XCTAssertTrue(app.buttons["filters-done"].firstMatch.waitForExistence(timeout: 10))
    }

    @MainActor private func doneFilters(in app: XCUIApplication) {
        let done = app.buttons["filters-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        // The failure recording showed Dietary still presented after a missed
        // synthesized Done tap. A background ranking control is not dismissal.
        for attempt in 0..<3 {
            if attempt > 0 {
                capture("Retry missed filter dismissal", app: app)
                app.activate()
            }
            done.tap()
            if done.waitForNonExistence(timeout: 3) { break }
        }
        XCTAssertTrue(done.waitForNonExistence(timeout: 10), "The filter sheet must actually close")
        XCTAssertTrue(app.buttons["ranking-filter-course"].waitForExistence(timeout: 10))
    }

    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor
    func testSearchCombinedFiltersClearAndDetailNavigation() throws {
        let app = launch()
        capture("Full ranking Dark", app: app)
        search("chicken", in: app)
        XCTAssertTrue(row("Golden sear", in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(row("Smoky Sunday", in: app).exists)
        XCTAssertFalse(row("Sea Bass", in: app).exists)
        capture("Search results Dark", app: app)
        // Grub Rank filters are Course and Cuisine only; Dietary and Avoid live in Food Bible.
        XCTAssertFalse(app.buttons["ranking-filter-dietary"].exists); XCTAssertFalse(app.buttons["ranking-filter-avoid"].exists)
        // Search alone shows the same X used for active filters.
        XCTAssertTrue(app.buttons["clear-filters"].exists)

        // Chip geometry and row positions must not move when a filter becomes active.
        let chipFrames = ["course", "cuisine"].map { app.buttons["ranking-filter-\($0)"].frame }
        let sortFrame = app.buttons["ranking-sort"].frame, toggleFrame = app.allVersionsSwitch.frame
        filters("course", in: app)
        // Multi-select: choosing keeps the sheet open until Done.
        select(app.buttons["filter-course-main"], in: app)
        XCTAssertTrue(app.buttons["filters-done"].exists, "Selecting must not dismiss the filter sheet")
        select(app.buttons["filter-course-dessert"], in: app)
        XCTAssertEqual(app.buttons["filter-course-main"].value as? String, "Selected")
        app.buttons["filter-course-dessert"].tap()
        XCTAssertTrue(wait("value == 'Not selected'", on: app.buttons["filter-course-dessert"]))
        doneFilters(in: app)
        XCTAssertEqual(["course", "cuisine"].map { app.buttons["ranking-filter-\($0)"].frame }, chipFrames)
        XCTAssertEqual(app.buttons["ranking-sort"].frame, sortFrame)
        XCTAssertEqual(app.allVersionsSwitch.frame, toggleFrame)
        XCTAssertEqual(app.buttons["ranking-filter-course"].label, "Course, 1 active")
        let golden = row("Golden sear", in: app)
        XCTAssertTrue(golden.waitForExistence(timeout: 10)); XCTAssertTrue(golden.label.hasPrefix("Rank 2,"))
        capture("Combined result Dark", app: app)

        transition(golden, to: app.navigationBars["Dish Details"], in: app)
        XCTAssertTrue(app.staticTexts["Golden sear"].exists)
        transition(app.navigationBars.buttons.firstMatch, to: app.rankingSearchField, in: app)
        XCTAssertEqual(app.rankingSearchField.value as? String, "chicken")
        XCTAssertTrue(app.buttons["clear-filters"].exists)

        search("ramen", in: app)
        XCTAssertTrue(app.staticTexts["No filter matches"].waitForExistence(timeout: 10))
        capture("No matches Dark", app: app)
        // One X clears search and filters together, then disappears.
        transition(app.buttons["clear-filters"], to: row("Apple Cake", in: app), in: app)
        XCTAssertTrue(row("Smoky Sunday", in: app).exists)
        XCTAssertFalse(app.buttons["clear-filters"].exists)
        XCTAssertFalse(app.rankingFilterLabel("course").contains("active"))
    }

    @MainActor
    func testLargeTypeLightFiltersAndIndividualClearing() throws {
        let app = launch(largeType: true)
        capture("Full ranking Light Large Type", app: app)
        filters("course", in: app)
        select(app.buttons["filter-course-dessert"], in: app)
        select(app.buttons["filter-course-pastaNoodles"], in: app)
        capture("Filters Light Large Type", app: app); doneFilters(in: app)
        XCTAssertTrue(row("Apple Cake", in: app).waitForExistence(timeout: 10))
        reach(row("Lemon Pasta", in: app), in: app)
        XCTAssertFalse(row("Smoky Sunday", in: app).exists)
        capture("Filtered ranking Light Large Type", app: app)
        filters("course", in: app)
        let dessert = app.buttons["filter-course-dessert"]
        XCTAssertEqual(dessert.value as? String, "Selected")
        dessert.tap(); XCTAssertTrue(wait("value == 'Not selected'", on: dessert))
        doneFilters(in: app)
        XCTAssertTrue(row("Lemon Pasta", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(row("Apple Cake", in: app).exists)
        reach(app.buttons["clear-filters"], in: app, scrollDown: true)
        transition(app.buttons["clear-filters"], to: row("Smoky Sunday", in: app), in: app)
        XCTAssertFalse(app.buttons["clear-filters"].exists)
    }

    @MainActor
    func testEditingFromSearchUpdatesResultsWhilePreservingSearchAndScore() throws {
        let app = launch()
        search("Golden", in: app)
        let golden = row("Golden sear", in: app)
        XCTAssertTrue(golden.waitForExistence(timeout: 10))
        let oldID = golden.identifier
        let oldScore = String(golden.label.split(separator: ",").last ?? "")
        transition(golden, to: app.navigationBars["Dish Details"], in: app)
        app.cookAction("detail-edit-cook").tap()
        let title = app.textFields["version-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        reach(title, in: app); title.tap()
        XCTAssertTrue(wait("hasKeyboardFocus == true", on: title))
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Golden sear".count) + "Crispy\n")
        transition(app.buttons["save-cook-metadata"], to: app.staticTexts["Crispy"], in: app)
        reach(app.staticTexts["Cookbook · Zahav"], in: app)
        XCTAssertTrue(app.staticTexts["Cookbook · Zahav"].exists)
        transition(app.navigationBars.buttons.firstMatch, to: app.rankingSearchField, in: app)
        XCTAssertEqual(app.rankingSearchField.value as? String, "Golden")
        XCTAssertTrue(app.staticTexts["No search results"].waitForExistence(timeout: 10))
        transition(app.buttons["clear-search"], to: app.buttons[oldID], in: app)
        let updated = app.buttons[oldID]
        XCTAssertTrue(updated.label.contains("Crispy"))
        XCTAssertEqual(String(updated.label.split(separator: ",").last ?? ""), oldScore)
        XCTAssertFalse(app.buttons["clear-filters"].exists)
    }

    @MainActor
    func testIndividualFilterGroupsAndCreationNavigation() throws {
        let app = launch()
        filters("course", in: app)
        select(app.buttons["filter-course-dessert"], in: app); doneFilters(in: app)
        XCTAssertTrue(row("Apple Cake", in: app).label.hasPrefix("Rank 5,"))
        XCTAssertFalse(row("Golden sear", in: app).exists)
        capture("Course only", app: app)

        app.revealCreation()
        capture("Creation expanded", app: app)
        transition(app.buttons["new-dish"], to: app.textFields["dish-name"], in: app)
        capture("New Dish with existing filtered ranking", app: app)
        transition(app.buttons["Cancel"], to: row("Apple Cake", in: app), in: app)
        XCTAssertTrue(app.rankingFilterLabel("course").contains("1 active"))
        app.revealCreation()
        transition(app.buttons["new-version"], to: app.buttons["choose-dish-Harissa Chicken"], in: app)
        transition(app.buttons["choose-dish-Harissa Chicken"], to: app.staticTexts["inherited-dish-name"], in: app)
        XCTAssertEqual(app.staticTexts["inherited-dish-name"].label, "Harissa Chicken")
        capture("New Version from filtered ranking", app: app)
        transition(app.buttons["Cancel"], to: row("Apple Cake", in: app), in: app)

        transition(app.buttons["clear-filters"], to: row("Smoky Sunday", in: app), in: app)
        // Grub Rank offers Course and Cuisine only.
        XCTAssertFalse(app.buttons["ranking-filter-dietary"].exists); XCTAssertFalse(app.buttons["ranking-filter-avoid"].exists)
        filters("course", in: app)
        select(app.buttons["filter-course-main"], in: app); doneFilters(in: app)
        XCTAssertTrue(row("Golden sear", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(row("Apple Cake", in: app).exists)
        capture("Main course only", app: app)
        search("chicken", in: app)
        XCTAssertTrue(row("Golden sear", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(row("Lemon Pasta", in: app).exists)
        search("ramen", in: app)
        XCTAssertTrue(app.staticTexts["No filter matches"].waitForExistence(timeout: 10))
        capture("No combined matches", app: app)
        transition(app.buttons["empty-clear-filters"], to: app.staticTexts["No search results"], in: app)
        XCTAssertEqual(app.rankingSearchField.value as? String, "ramen")
        transition(app.buttons["clear-search"], to: row("Apple Cake", in: app), in: app)
        XCTAssertFalse(app.buttons["clear-filters"].exists)
    }
}
