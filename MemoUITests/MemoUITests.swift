//
//  MemoUITests.swift
//  MemoUITests
//

import XCTest

/// A launch smoke test.
///
/// Deliberately shallow: its job is to catch the app failing to start at all —
/// a broken store, a crash in the practice settings, a missing environment
/// object — which unit tests over value types cannot see.
final class MemoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesToTheDeckList() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Decks"].waitForExistence(timeout: 10),
            "the deck list should be on screen shortly after launch"
        )
    }

    @MainActor
    func testDeckListOffersAWayToAddADeck() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.buttons["Add"].waitForExistence(timeout: 10),
            "an empty library still needs a visible way out of it"
        )
    }

    /// Menus only exist once opened, so this is the one place the import
    /// entry points can actually be checked.
    @MainActor
    func testAddMenuOffersBothImportFormats() throws {
        let app = XCUIApplication()
        app.launch()

        let add = app.buttons["Add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()

        XCTAssertTrue(app.buttons["New Deck"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["JSON"].exists, "JSON import should be offered")
        XCTAssertTrue(app.buttons["CSV"].exists, "CSV import should be offered")
    }

    /// Creating a deck end to end.
    ///
    /// Reordering deliberately has no control of its own — `onMove` gives the
    /// long-press drag directly — so there is nothing there for a test to tap.
    /// This covers the path that does have one.
    @MainActor
    func testCreatingADeckAddsItToTheList() throws {
        let app = XCUIApplication()
        app.launch()

        let addRow = app.buttons["Add"]
        XCTAssertTrue(addRow.waitForExistence(timeout: 10))
        addRow.tap()
        app.buttons["New Deck"].tap()

        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("UI Test Deck")

        // The sheet's save button shares its title with the list row behind it;
        // only the sheet's is hittable.
        let save = app.buttons.matching(identifier: "Add")
            .allElementsBoundByIndex
            .first { $0.isHittable }
        XCTAssertNotNil(save, "the sheet should offer a way to save")
        save?.tap()

        XCTAssertTrue(
            app.staticTexts["UI Test Deck"].waitForExistence(timeout: 5),
            "the new deck should appear in the list"
        )
    }

    @MainActor
    func testStaysRunningAfterLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        _ = app.staticTexts["Decks"].waitForExistence(timeout: 10)

        XCTAssertEqual(app.state, .runningForeground, "the app should not crash on launch")
    }
}
