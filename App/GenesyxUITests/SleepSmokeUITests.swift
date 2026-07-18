import XCTest

/// Journey 4 (addition) — sleep smoke: open the sleep sheet, log an entry, and confirm it persists
/// after navigating away and back. Smoke depth only. Seed leaves today's sleep unlogged.
final class SleepSmokeUITests: XCTestCase {

    override func setUp() { super.setUp(); continueAfterFailure = false }

    private func launch(tab: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed", "YES", "-uiTestTab", "\(tab)"]
        app.launch()
        return app
    }

    func testSleepEntryPersistsAcrossNavigation() {
        let app = launch(tab: 1)   // Track

        let sleepRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Sleep,")).firstMatch
        XCTAssertTrue(sleepRow.waitForExistence(timeout: 15), "Track should show a Sleep tracker row")
        sleepRow.tap()

        // The sleep sheet defaults to 7h 0m for an unlogged day; save it as-is.
        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Sleep sheet should offer Save")
        save.tap()
        app.buttons["Done"].tap()

        let sleep7h = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Sleep, 7h")).firstMatch
        XCTAssertTrue(sleep7h.waitForExistence(timeout: 10), "Track sleep row should read 7h after saving")

        // Leave Track and return — the logged value must persist.
        app.buttons["Home"].tap()
        app.buttons.matching(identifier: "Track").firstMatch.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Sleep, 7h")).firstMatch.waitForExistence(timeout: 10),
                      "Logged sleep must persist after navigating away and back")
    }
}
