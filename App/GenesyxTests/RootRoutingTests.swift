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

    // MARK: - Password recovery

    /// The load-bearing one. Redeeming a reset link mints a REAL session, so without the recovery
    /// check sitting ahead of the session switch this returns `.mainTabs` — she lands inside the
    /// app, her old password still works, and she is never asked to choose a new one. The link
    /// would be a way past the gate rather than a way to fix a lockout.
    func testRecoveryOutranksTheSessionItJustCreated() {
        XCTAssertEqual(
            RootRouting.destination(session: .signedIn, onboardingComplete: true,
                                    serviceAvailable: true, passwordRecovery: true),
            .passwordRecovery)
    }

    /// It must also hold before the session resolves and after a failed redemption, because the
    /// screen has to be reachable to report an expired link — a state with no session at all.
    func testRecoveryHoldsRegardlessOfSessionState() {
        for session: SessionAuthState in [.resolving, .signedOut, .signedIn] {
            XCTAssertEqual(
                RootRouting.destination(session: session, onboardingComplete: true,
                                        serviceAvailable: true, passwordRecovery: true),
                .passwordRecovery,
                "\(session) must still show the reset screen while recovery is active")
        }
    }

    /// Fail-closed still wins. A reset link cannot conjure a screen that talks to a backend which
    /// is not there — it would collect a password and throw on submit.
    func testRecoveryDoesNotOverrideAMissingBackend() {
        XCTAssertEqual(
            RootRouting.destination(session: .signedIn, onboardingComplete: true,
                                    serviceAvailable: false, passwordRecovery: true),
            .unavailable)
    }

    /// The flag defaults false, so every existing route is unchanged by its addition.
    func testWithoutRecoveryNothingMoves() {
        XCTAssertEqual(
            RootRouting.destination(session: .signedIn, onboardingComplete: true,
                                    serviceAvailable: true, passwordRecovery: false),
            .mainTabs)
        XCTAssertEqual(
            RootRouting.destination(session: .signedOut, onboardingComplete: true,
                                    serviceAvailable: true, passwordRecovery: false),
            .mandatoryAuth)
    }

    // MARK: Article 9 consent

    /// Every tab behind this gate holds special-category data, so a signed-in woman with no consent
    /// on record for the wording in force is asked before any of it is on screen.
    func testConsentOutranksTheTabs() {
        XCTAssertEqual(
            RootRouting.destination(session: .signedIn, onboardingComplete: true,
                                    serviceAvailable: true, consentRequired: true),
            .consentRequired)
    }

    /// The ordering that matters: a woman locked out of her account cannot meaningfully answer a
    /// consent question, and choosing a new password processes no health data.
    func testARecoveryLinkIsAnsweredBeforeTheConsentQuestion() {
        XCTAssertEqual(
            RootRouting.destination(session: .signedIn, onboardingComplete: true,
                                    serviceAvailable: true, passwordRecovery: true,
                                    consentRequired: true),
            .passwordRecovery)
    }

    /// Fail-closed still wins, for the same reason it does over recovery: there is nowhere to
    /// record the answer.
    func testConsentDoesNotOverrideAMissingBackend() {
        XCTAssertEqual(
            RootRouting.destination(session: .signedIn, onboardingComplete: true,
                                    serviceAvailable: false, consentRequired: true),
            .unavailable)
    }

    /// There is nobody to ask while the session is unresolved, and onboarding asks on its own
    /// screen. Neither route may be replaced by the consent gate.
    func testTheConsentGateOnlyAppliesToASignedInUser() {
        XCTAssertEqual(
            RootRouting.destination(session: .resolving, onboardingComplete: true,
                                    serviceAvailable: true, consentRequired: true),
            .resolving)
        XCTAssertEqual(
            RootRouting.destination(session: .signedOut, onboardingComplete: false,
                                    serviceAvailable: true, consentRequired: true),
            .onboarding)
        XCTAssertEqual(
            RootRouting.destination(session: .signedOut, onboardingComplete: true,
                                    serviceAvailable: true, consentRequired: true),
            .mandatoryAuth)
    }

    /// The flag defaults false, so every existing route is unchanged by its addition.
    func testWithoutTheConsentFlagNothingMoves() {
        XCTAssertEqual(
            RootRouting.destination(session: .signedIn, onboardingComplete: true,
                                    serviceAvailable: true, consentRequired: false),
            .mainTabs)
    }
}
