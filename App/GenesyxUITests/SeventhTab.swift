import XCTest

/// The seventh tab is Profile, or More (a list that holds Profile) in a build with more
/// destinations than the bar has room for. Tests that want Profile, or want to know the bar is
/// whole, go through here so they hold in either layout.
extension XCUIApplication {

    /// Matched by identifier: under More, the pushed Profile's back button is also labelled "More".
    private func tab(_ title: String) -> XCUIElement {
        buttons.matching(identifier: title).firstMatch
    }

    /// The bar's last item: "Profile", or "More" when Profile has moved inside it. Ask once the
    /// bar is up.
    var seventhTabTitle: String {
        tab("Profile").exists ? "Profile" : "More"
    }

    /// Puts the Profile screen in front from any tab: by its own tab, or through More.
    func openProfile(file: StaticString = #filePath, line: UInt = #line) {
        let profile = tab("Profile"), more = tab("More")
        let deadline = Date().addingTimeInterval(10)
        while !profile.exists && !more.exists && Date() < deadline { usleep(200_000) }
        if profile.exists { profile.tap(); return }
        XCTAssertTrue(more.exists, "the bar must end in Profile or More", file: file, line: line)
        more.tap()
        // More may already have Profile pushed (`-uiTestTab 6`, or an earlier visit).
        let row = buttons["more.profile"]
        if !navigationBars["Profile"].exists, row.waitForExistence(timeout: 10) { row.tap() }
        XCTAssertTrue(navigationBars["Profile"].waitForExistence(timeout: 10),
                      "More must open Profile", file: file, line: line)
    }
}
