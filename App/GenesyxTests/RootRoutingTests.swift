import XCTest
@testable import Genesyx

/// Pure decision table for the P0 authentication gate. Editing `RootView` to put the tabs
/// back behind `onboardingComplete` alone must fail these.
final class RootRoutingTests: XCTestCase {

    func testResolvingNeverOpensPrivateTabs() {
        XCTAssertEqual(
            RootRouting.destination(session: .resolving, onboardingComplete: true, serviceAvailable: true),
            .resolving)
        XCTAssertEqual(
            RootRouting.destination(session: .resolving, onboardingComplete: false, serviceAvailable: true),
            .resolving)
    }

    func testSignedInOpensTheTabsRegardlessOfOnboarding() {
        XCTAssertEqual(
            RootRouting.destination(session: .signedIn, onboardingComplete: true, serviceAvailable: true),
            .mainTabs)
        XCTAssertEqual(
            RootRouting.destination(session: .signedIn, onboardingComplete: false, serviceAvailable: true),
            .mainTabs)
    }

    func testSignedOutWithIncompleteOnboardingIsTheQuiz() {
        XCTAssertEqual(
            RootRouting.destination(session: .signedOut, onboardingComplete: false, serviceAvailable: true),
            .onboarding)
    }

    func testSignedOutWithCompletedOnboardingIsMandatoryLogin() {
        XCTAssertEqual(
            RootRouting.destination(session: .signedOut, onboardingComplete: true, serviceAvailable: true),
            .mandatoryAuth)
    }

    func testUnavailableServiceNeverOpensPrivateTabs() {
        for session: SessionAuthState in [.resolving, .signedOut, .signedIn] {
            XCTAssertEqual(
                RootRouting.destination(session: session, onboardingComplete: true, serviceAvailable: false),
                .unavailable,
                "\(session) must fail closed when the backend is missing")
        }
    }
}
