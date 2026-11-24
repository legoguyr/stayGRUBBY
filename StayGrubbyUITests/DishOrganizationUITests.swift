import XCTest

/// Dish/Recipe integrity and Smart Collections (November 18, 2026): Rank a Dish offers an explicit
/// "another cook" choice for a known Dish, a cook logged under the wrong Dish becomes its own Dish
/// without losing its ranking, and both Dishes can share a collection.
final class DishOrganizationUITests: StayGrubbyUITestCase {
    /// Opens a Grub Rank row's Dish page; the first tap after a sheet closes is sometimes swallowed.
    @MainActor private func openDish(_ row: XCUIElement, _ app: XCUIApplication) {
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        for _ in 0..<3 { row.tap(); if app.segmentedControls["dish-tabs"].waitForExistence(timeout: 4) { return } }
        XCTFail("Dish page did not open")
    }
    /// The Cook Name field sits below the Dish fields (and collections); bring it on screen first.
    @MainActor private func nameCook(_ title: String, _ app: XCUIApplication) {
        let field = app.textFields["version-title"]
        for _ in 0..<5 where !app.cookingFieldIsVisible(field) { app.scrollCookingFormToward(field) }
        field.tap(); field.typeText(title)
        if app.buttons["cook-keyboard-done"].exists { app.buttons["cook-keyboard-done"].tap() }
    }
    @MainActor func testSeparateACookIntoItsOwnDishAndGroupThemInACollection() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--test-light", "--test-reduce-motion", "--feature-flag", "dish_collections"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))

        // First Dish: Risotto, cook "Butternut Squash".
        app.revealCreation(); app.buttons["new-dish"].tap()
        let name = app.textFields["dish-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Risotto")
        nameCook("Butternut Squash", app)
        app.buttons["Continue"].tap(); app.buttons["Liked it"].tap()
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 15)); app.buttons["ranking-result-close"].tap()

        // Rank a Dish with the same name: the app asks, it never merges on its own.
        app.revealCreation(); app.buttons["new-dish"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("risotto")
        // Close the keyboard: the floating Continue bar otherwise sits over the prompt.
        if app.buttons["cook-keyboard-done"].exists { app.buttons["cook-keyboard-done"].tap() }
        let match = app.buttons["cook-existing-match"]
        XCTAssertTrue(match.waitForExistence(timeout: 5), "A matching Dish is offered explicitly")
        match.tap()
        let inherited = app.staticTexts["inherited-dish-name"]
        XCTAssertTrue(inherited.waitForExistence(timeout: 10)); XCTAssertEqual(inherited.label, "Risotto")
        nameCook("Mushroom", app)
        app.buttons["Continue"].tap(); app.buttons["Liked it"].tap()
        let prefer = app.buttons["Prefer Risotto — Mushroom"]
        XCTAssertTrue(prefer.waitForExistence(timeout: 10)); prefer.tap()
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 15)); app.buttons["ranking-result-close"].tap()

        // The Mushroom cook was really a different Dish: separate it from the Dish page.
        let risottoRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Risotto'")).firstMatch
        openDish(risottoRow, app)
        let separate = app.buttons["dish-separate-cooks"]
        for _ in 0..<8 where !separate.isHittable { app.swipeUp() }
        separate.tap()
        let toggle = app.switches["separate-toggle-Mushroom"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 8)); toggle.switches.firstMatch.tap()
        let newName = app.textFields["separate-name-Mushroom"]
        XCTAssertTrue(newName.waitForExistence(timeout: 5))
        XCTAssertEqual(newName.value as? String, "Mushroom Risotto", "Cook Name + the Dish's last word is the starting suggestion")
        XCTAssertFalse(app.switches["separate-toggle-Butternut Squash"].isEnabled, "The Dish always keeps one cook")
        let folder = app.switches["separate-folder-toggle"]
        for _ in 0..<4 where !folder.isHittable { app.swipeUp() }
        folder.switches.firstMatch.tap()
        app.buttons["separate-save"].tap()

        // Two Dishes now, each keeping its ranked cook; both in the Risotto folder.
        if !app.rankingHeader.exists { app.navigationBars.buttons.element(boundBy: 0).tap() }
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 10))
        let separated = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Mushroom Risotto'")).firstMatch
        openDish(separated, app)
        XCTAssertTrue(app.buttons["dish-explore-Risotto"].waitForExistence(timeout: 8), "Explore Risotto folder callout")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Separated Dish with its collection"; shot.lifetime = .keepAlways; add(shot)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let original = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Butternut Squash'")).firstMatch // the Dish that stays
        openDish(original, app)
        XCTAssertTrue(app.buttons["dish-explore-Risotto"].waitForExistence(timeout: 8), "Both Dishes are in the folder")
        // Dish Variations tab: one Risotto variation holding both Dishes, never merged.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.segmentedControls["grub-rank-sections"].waitForExistence(timeout: 8))
        app.segmentedControls["grub-rank-sections"].buttons["Dish Variations"].tap()
        let card = app.descendants(matching: .any).matching(identifier: "folder-Risotto").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8), app.debugDescription); XCTAssertTrue(card.label.contains("2 Dishes"), card.label)
        let folders = XCTAttachment(screenshot: app.screenshot()); folders.name = "Grub Rank Folders"; folders.lifetime = .keepAlways; add(folders)
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "collection-dish-Mushroom Risotto").firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "collection-dish-Risotto").firstMatch.exists)
        let inside = XCTAttachment(screenshot: app.screenshot()); inside.name = "Risotto variation"; inside.lifetime = .keepAlways; add(inside)

        // Remove from Variation keeps the Dish; Create Variation adds it to a second one.
        let mushroomRow = app.descendants(matching: .any).matching(identifier: "collection-dish-Mushroom Risotto").firstMatch
        mushroomRow.press(forDuration: 1.0)
        let remove = app.buttons["collection-dish-remove"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5)); remove.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "collection-dish-Risotto").firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(mushroomRow.waitForExistence(timeout: 2), "Removed from the variation")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let create = app.buttons["variation-create"]
        XCTAssertTrue(create.waitForExistence(timeout: 8)); create.tap()
        let variationName = app.textFields["variation-name"]
        XCTAssertTrue(variationName.waitForExistence(timeout: 5)); variationName.tap(); variationName.typeText("Weeknight")
        app.buttons["variation-dish-Mushroom Risotto"].tap(); app.buttons["variation-dish-Risotto"].tap()
        app.buttons["variation-save"].tap()
        let weeknight = app.descendants(matching: .any).matching(identifier: "folder-Weeknight").firstMatch
        XCTAssertTrue(weeknight.waitForExistence(timeout: 8)); XCTAssertTrue(weeknight.label.contains("2 Dishes"), weeknight.label)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "folder-Risotto").firstMatch.label.contains("1 Dish"))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-'")).count == 0, "Variations tab shows cards, not rows")
        app.segmentedControls["grub-rank-sections"].buttons["All Dishes"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Mushroom Risotto'")).firstMatch.waitForExistence(timeout: 8), "The removed Dish still exists")
        let grid = XCTAttachment(screenshot: app.screenshot()); grid.name = "All Dishes after variations"; grid.lifetime = .keepAlways; add(grid)

        // Persistence: relaunch the same isolated store.
        app.terminate(); app.launchWithReviewOptions()
        XCTAssertTrue(app.segmentedControls["grub-rank-sections"].waitForExistence(timeout: 15))
        app.segmentedControls["grub-rank-sections"].buttons["Dish Variations"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "folder-Weeknight").firstMatch.waitForExistence(timeout: 8), "Variations persist after relaunch")
        let cards = XCTAttachment(screenshot: app.screenshot()); cards.name = "Dish Variations after relaunch"; cards.lifetime = .keepAlways; add(cards)
    }

    /// Food Bible → Recipe → its exact Dish, by Dish ID. A similarly named Dish never borrows the Recipe.
    @MainActor func testRecipeOpensItsOwnDishAmongSimilarlyNamedDishes() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--test-light", "--test-reduce-motion"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        func rank(_ dish: String, prefer: String?) {
            app.revealCreation(); app.buttons["new-dish"].tap()
            let name = app.textFields["dish-name"]; XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText(dish)
            if app.buttons["cook-keyboard-done"].exists { app.buttons["cook-keyboard-done"].tap() }
            app.buttons["Continue"].tap(); app.buttons["Liked it"].tap()
            if let prefer { let button = app.buttons["Prefer \(prefer)"]; XCTAssertTrue(button.waitForExistence(timeout: 10)); button.tap() }
            XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 15)); app.buttons["ranking-result-close"].tap()
            let notNow = app.buttons["Not Now"]
            if notNow.waitForExistence(timeout: 1), notNow.isHittable { notNow.tap() }
        }
        rank("Saffron Risotto", prefer: nil)
        rank("Mushroom Risotto", prefer: "Mushroom Risotto")

        // Give only Mushroom Risotto a Recipe, from its own Dish page.
        let mushroom = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Mushroom Risotto'")).firstMatch
        openDish(mushroom, app)
        let add = app.buttons["dish-add-recipe"]
        for _ in 0..<6 where !add.isHittable { app.swipeUp() }
        XCTAssertTrue(add.waitForExistence(timeout: 10)); add.tap()
        XCTAssertTrue(app.buttons["dish-recipe-manual"].waitForExistence(timeout: 8)); app.buttons["dish-recipe-manual"].tap()
        XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout: 8))
        if app.buttons["recipe-keyboard-done"].exists { app.buttons["recipe-keyboard-done"].tap() }
        app.buttons["recipe-save"].tap()
        XCTAssertTrue(app.segmentedControls["dish-tabs"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Food Bible: the Recipe opens Mushroom Risotto, never Saffron Risotto.
        app.tabBars.buttons["Food Bible"].tap()
        let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-' AND label CONTAINS 'Mushroom Risotto'")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        let open = app.buttons["recipe-open-dish"]
        XCTAssertTrue(open.waitForExistence(timeout: 10)); XCTAssertTrue(open.label.contains("Mushroom Risotto"))
        open.tap()
        XCTAssertEqual(app.staticTexts["dish-title"].label, "Mushroom Risotto")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-' AND label CONTAINS 'Saffron'")).firstMatch.exists)

        // Saffron Risotto has no Recipe.
        app.tabBars.buttons["Grub Rank"].tap()
        if !app.rankingHeader.exists { app.navigationBars.buttons.element(boundBy: 0).tap() }
        let saffron = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Saffron Risotto'")).firstMatch
        openDish(saffron, app)
        app.segmentedControls["dish-tabs"].buttons["Recipe"].tap()
        XCTAssertTrue(app.buttons["dish-link-recipe"].waitForExistence(timeout: 10), "No inherited Recipe")
    }

    /// Recipe safety (November 20, 2026): Unlink keeps the Recipe in Food Bible; Delete moves it to Recently
    /// Deleted, and Restore brings it back on its Dish.
    @MainActor func testUnlinkKeepsTheRecipeAndDeletedRecipesCanBeRestored() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-store", UUID().uuidString, "--social-review", "--social-review-ready", "--test-light", "--test-reduce-motion", "--feature-flag", "recipe_recovery", "--recipe-persistence-review"]
        app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.revealCreation(); app.buttons["new-dish"].tap()
        let name = app.textFields["dish-name"]; XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Butternut Squash Risotto")
        if app.buttons["cook-keyboard-done"].exists { app.buttons["cook-keyboard-done"].tap() }
        app.buttons["Continue"].tap(); app.buttons["Liked it"].tap()
        XCTAssertTrue(app.buttons["ranking-result-close"].waitForExistence(timeout: 15)); app.buttons["ranking-result-close"].tap()
        let notNow = app.buttons["Not Now"]; if notNow.waitForExistence(timeout: 1), notNow.isHittable { notNow.tap() }

        // Give the Dish a Recipe from its own page.
        openDish(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cook-row-' AND label CONTAINS 'Butternut'")).firstMatch, app)
        let addRecipe = app.buttons["dish-add-recipe"]
        for _ in 0..<6 where !addRecipe.isHittable { app.swipeUp() }
        addRecipe.tap()
        XCTAssertTrue(app.buttons["dish-recipe-manual"].waitForExistence(timeout: 8)); app.buttons["dish-recipe-manual"].tap()
        XCTAssertTrue(app.textFields["recipe-edit-title"].waitForExistence(timeout: 8))
        if app.buttons["recipe-keyboard-done"].exists { app.buttons["recipe-keyboard-done"].tap() }
        app.buttons["recipe-save"].tap()
        XCTAssertTrue(app.segmentedControls["dish-tabs"].waitForExistence(timeout: 10))
        app.segmentedControls["dish-tabs"].buttons["Recipe"].tap()

        // Unlink is its own, non-destructive action; the Recipe stays in Food Bible.
        let menu = app.buttons["recipe-actions"]; XCTAssertTrue(menu.waitForExistence(timeout: 10)); menu.tap()
        XCTAssertTrue(app.buttons["recipe-unlink"].waitForExistence(timeout: 5), "Unlink is offered next to Delete")
        XCTAssertTrue(app.buttons["recipe-delete"].exists)
        let menuShot = XCTAttachment(screenshot: app.screenshot()); menuShot.name = "Recipe menu with Unlink"; menuShot.lifetime = .keepAlways; add(menuShot)
        app.buttons["recipe-unlink"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'stays in Food Bible'")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["recipe-unlink-confirm"].firstMatch.tap()
        let ok = app.alerts.buttons["OK"]; if ok.waitForExistence(timeout: 5) { ok.tap() }
        XCTAssertTrue(app.buttons["dish-link-recipe"].waitForExistence(timeout: 10), "The Dish no longer has a Recipe")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Food Bible"].tap()
        let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bible-entry-' AND label CONTAINS 'Butternut'")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "The unlinked Recipe is still in Food Bible")

        // Relink: an unlinked Recipe offers Choose a Dish (the shared picker), not Unlink.
        entry.tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 10)); menu.tap()
        XCTAssertFalse(app.buttons["recipe-unlink"].exists, "No Unlink once the Recipe has no Dish")
        XCTAssertTrue(app.buttons["recipe-choose-dish"].waitForExistence(timeout: 5)); app.buttons["recipe-choose-dish"].tap()
        let dishChoice = app.buttons["choose-dish-Butternut Squash Risotto"]
        XCTAssertTrue(dishChoice.waitForExistence(timeout: 10), "The Dish without a Recipe is offered")
        dishChoice.tap()
        XCTAssertTrue(dishChoice.waitForNonExistence(timeout: 10))
        XCTAssertTrue(menu.waitForExistence(timeout: 10)); menu.tap()
        XCTAssertTrue(app.buttons["recipe-unlink"].waitForExistence(timeout: 5), "Relinked: Unlink is offered again")

        // Delete names the Recipe and moves it to Recently Deleted.
        app.buttons["recipe-delete"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Recently Deleted'")).firstMatch.waitForExistence(timeout: 5))
        let deleteShot = XCTAttachment(screenshot: app.screenshot()); deleteShot.name = "Delete confirmation"; deleteShot.lifetime = .keepAlways; add(deleteShot)
        app.buttons["recipe-delete-confirm"].firstMatch.tap()
        if app.navigationBars.buttons.element(boundBy: 0).waitForExistence(timeout: 3), !app.buttons["bible-recently-deleted"].exists { app.navigationBars.buttons.element(boundBy: 0).tap() }
        XCTAssertTrue(entry.waitForNonExistence(timeout: 10), "Deleted Recipes leave Food Bible")
        let trash = app.buttons["bible-recently-deleted"]
        for _ in 0..<4 where !trash.isHittable { app.swipeUp() }
        trash.tap()
        let restore = app.buttons["recently-deleted-restore-Butternut Squash Risotto"]
        XCTAssertTrue(restore.waitForExistence(timeout: 10))
        let trashShot = XCTAttachment(screenshot: app.screenshot()); trashShot.name = "Recently Deleted"; trashShot.lifetime = .keepAlways; add(trashShot)
        restore.tap()
        XCTAssertTrue(app.alerts.buttons["OK"].waitForExistence(timeout: 5)); app.alerts.buttons["OK"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "recently-deleted-empty").firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "Restored Recipes return to Food Bible")
        // Restore reattaches the free Dish (deleting the Recipe never deleted the Dish).
        entry.tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 10)); menu.tap()
        XCTAssertTrue(app.buttons["recipe-unlink"].waitForExistence(timeout: 5), "The restored Recipe is back on its Dish")
        app.buttons["recipe-unlink"].tap(); app.buttons["recipe-unlink-confirm"].firstMatch.tap()
        // The fixture's server state is on disk: the restored Recipe survives relaunch.
        app.terminate(); app.launchWithReviewOptions()
        XCTAssertTrue(app.rankingHeader.waitForExistence(timeout: 15))
        app.tabBars.buttons["Food Bible"].tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "The restored Recipe survives relaunch")
    }
}
