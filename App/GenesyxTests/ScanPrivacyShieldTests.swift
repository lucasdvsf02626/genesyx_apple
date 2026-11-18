import XCTest
@testable import Genesyx

/// The window that hides the app while it is not active and a test result is on screen. Driven
/// here by UIKit's own notices, posted by hand: what is under test is when the cover exists.
@MainActor
final class ScanPrivacyShieldTests: XCTestCase {

    private let shield = ScanPrivacyShield.shared
    private let screen = UUID()

    override func setUp() async throws {
        post(UIApplication.didBecomeActiveNotification)
    }

    override func tearDown() async throws {
        shield.set(screen, onScreen: false)
        post(UIApplication.didBecomeActiveNotification)
    }

    private func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: UIApplication.shared)
    }

    /// The cover is the only window the app puts above its alerts.
    private var covers: [UIWindow] {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).filter { $0.windowLevel > .alert && !$0.isHidden }
    }

    func testWithNoResultOnScreenNothingIsCovered() {
        post(UIApplication.willResignActiveNotification)
        XCTAssertFalse(shield.appIsActive)
        XCTAssertTrue(covers.isEmpty, "the rest of the app must look in the app switcher as it always has")
    }

    func testAResultOnScreenIsCoveredFromTheMomentTheAppIsAboutToLeaveUntilItIsActiveAgain() {
        shield.set(screen, onScreen: true)
        XCTAssertTrue(covers.isEmpty, "nothing is covered while she is using the app")

        post(UIApplication.willResignActiveNotification)
        XCTAssertFalse(shield.appIsActive)
        XCTAssertEqual(covers.count, 1, "covered before the notice returns, with no wait for the scene phase")

        post(UIApplication.didBecomeActiveNotification)
        XCTAssertTrue(shield.appIsActive)
        XCTAssertTrue(covers.isEmpty, "the cover goes the moment she is back")
    }

    func testTheCoverLiesOverAlertsFillsTheScreenAndTakesNothingFromTheScreenBeneath() throws {
        let key = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.keyWindow
        shield.set(screen, onScreen: true)
        post(UIApplication.willResignActiveNotification)

        let cover = try XCTUnwrap(covers.first)
        XCTAssertGreaterThan(cover.windowLevel, .alert)
        XCTAssertEqual(cover.frame, cover.windowScene?.screen.bounds)
        XCTAssertFalse(cover.isUserInteractionEnabled)
        XCTAssertFalse(cover.isKeyWindow, "the screen beneath keeps the keyboard and its first responder")
        XCTAssertTrue(key?.isKeyWindow ?? true)
    }

    func testAResultThatArrivesWhileTheAppIsAwayIsCoveredAtOnce() {
        post(UIApplication.willResignActiveNotification)
        XCTAssertTrue(covers.isEmpty)
        shield.set(screen, onScreen: true)
        XCTAssertEqual(covers.count, 1)
    }

    func testAScreenThatHasGoneNoLongerCovers() {
        shield.set(screen, onScreen: true)
        shield.set(screen, onScreen: false)
        post(UIApplication.willResignActiveNotification)
        XCTAssertTrue(covers.isEmpty)
    }

    func testTwoScreensCoverUntilBothHaveGone() {
        let sheet = UUID()
        shield.set(screen, onScreen: true)
        shield.set(sheet, onScreen: true)
        shield.set(sheet, onScreen: false)
        post(UIApplication.willResignActiveNotification)
        XCTAssertEqual(covers.count, 1, "the screen under the sheet is still showing")
    }
}
