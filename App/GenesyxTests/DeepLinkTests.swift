import XCTest
@testable import Genesyx

/// Verifies partner-invite deep-link parsing for both the custom scheme and Universal Links.
///
/// **Scope note.** `DeepLink` still parses these URLs, and that is all these tests claim. Acting on
/// a parsed code is a separate step in `RootView.receiveInvite`, and it is switched off for the
/// 1.2.0 public release (`FeatureFlags.partnerInvites`), so on this build a valid invite URL parses
/// and is then discarded. `AuthGateUITests.testInviteLinkDoesNothingEvenWhenSignedIn` asserts that.
final class DeepLinkTests: XCTestCase {

    func testCustomScheme() {
        XCTAssertEqual(DeepLink.inviteCode(from: URL(string: "genesyx://invite/ABC123XY")!), "ABC123XY")
    }

    func testUniversalLink() {
        XCTAssertEqual(
            DeepLink.inviteCode(from: URL(string: "https://genesyx.co.uk/invite/CODE1234")!),
            "CODE1234"
        )
    }

    /// Host case is not normalised by Foundation, but Universal Link matching IS case-insensitive,
    /// so iOS can hand us this and it must still redeem.
    func testOurDomainIsMatchedCaseInsensitively() {
        XCTAssertEqual(
            DeepLink.inviteCode(from: URL(string: "https://GENESYX.CO.UK/invite/CODE1234")!),
            "CODE1234"
        )
    }

    /// This used to return "ATTACKER": the host was unchecked, so any https URL with an `/invite/`
    /// path parsed. It was there to keep the retired `…lovable.app` prototype's links working. That
    /// domain is dead, so the only honoured host is ours.
    func testAForeignHttpsHostIsNotAnInvite() {
        XCTAssertNil(DeepLink.inviteCode(from: URL(string: "https://evil.example.com/invite/ATTACKER")!))
        XCTAssertNil(DeepLink.inviteCode(from: URL(string: "https://genesis-cycle-guide.lovable.app/invite/CODE1234")!),
                     "the retired prototype domain must no longer redeem")
    }

    func testNonInviteReturnsNil() {
        XCTAssertNil(DeepLink.inviteCode(from: URL(string: "genesyx://home")!))
        XCTAssertNil(DeepLink.inviteCode(from: URL(string: "https://example.com/about")!))
    }

    /// `genesyx://` is openable by any app or web page on the device. A URL on our scheme whose host
    /// is not `invite` used to fail the host check and then get parsed by the Universal-Link branch
    /// anyway, so an arbitrary page could raise the invite sheet with a code it chose. The server
    /// still refused the code, so the ceiling was a spoofed sheet — but only a link we issued should
    /// produce one, and we only ever issue `genesyx://invite/{code}`.
    func testOurSchemeWithAForeignHostIsNotAnInvite() {
        XCTAssertNil(DeepLink.inviteCode(from: URL(string: "genesyx://evil/invite/ATTACKER")!))
        XCTAssertNil(DeepLink.inviteCode(from: URL(string: "genesyx://open/x/invite/ATTACKER")!))
    }

    /// The shape we actually issue must still parse — the guard above rejects by host, not by luck.
    func testOurOwnSchemeLinkStillParses() throws {
        let url = try XCTUnwrap(DeepLink.schemeInviteURL(code: "REALCODE"))
        XCTAssertEqual(url.host, "invite")
        XCTAssertEqual(DeepLink.inviteCode(from: url), "REALCODE")
    }

    /// The Universal Link on our own domain — the one that survives a fresh install.
    func testOurUniversalLinkRoundTrips() throws {
        let url = try XCTUnwrap(DeepLink.webInviteURL(code: "CODE5678"))
        XCTAssertEqual(url.absoluteString, "https://genesyx.co.uk/invite/CODE5678")
        XCTAssertEqual(DeepLink.inviteCode(from: url), "CODE5678", "our own link must parse back")
    }

    // MARK: - Password recovery

    /// The redirect handed to Supabase. Pinned as a literal because this string has to match the
    /// Auth "Redirect URLs" allow-list in the dashboard exactly — an unlisted value is discarded
    /// server-side and the email silently falls back to the Site URL, which is the original bug.
    /// If this test fails, the dashboard needs updating in the same change.
    func testTheRecoveryRedirectIsTheExactStringAllowListedInSupabase() {
        XCTAssertEqual(DeepLink.passwordRecoveryURL.absoluteString, "genesyx://reset-password")
    }

    func testTheRecoveryCallbackIsRecognised() {
        XCTAssertTrue(DeepLink.isPasswordRecovery(URL(string: "genesyx://reset-password")!))
        XCTAssertTrue(DeepLink.isPasswordRecovery(DeepLink.passwordRecoveryURL))
    }

    /// PKCE appends the code as a query parameter, so the real callback never arrives bare.
    func testTheRecoveryCallbackIsRecognisedWithItsCode() {
        XCTAssertTrue(DeepLink.isPasswordRecovery(
            URL(string: "genesyx://reset-password?code=abc123")!))
    }

    /// An expired or reused link comes back carrying an error instead of a code. It must still be
    /// recognised: this is precisely the case that has to reach the screen and say so, rather than
    /// being dropped and leaving her staring at a sign-in form that never acknowledged the tap.
    func testAnErrorCallbackIsStillARecoveryCallback() {
        XCTAssertTrue(DeepLink.isPasswordRecovery(
            URL(string: "genesyx://reset-password?error=access_denied&error_code=otp_expired")!))
    }

    /// Same host guard as invites, for the same reason: any app on the device can open a
    /// `genesyx://` URL, so only the shape we issue is honoured.
    func testAForeignHostIsNotARecoveryCallback() {
        XCTAssertFalse(DeepLink.isPasswordRecovery(URL(string: "genesyx://evil/reset-password")!))
        XCTAssertFalse(DeepLink.isPasswordRecovery(URL(string: "https://genesyx.co.uk/reset-password")!))
        XCTAssertFalse(DeepLink.isPasswordRecovery(URL(string: "genesyx://home")!))
    }

    /// The two deep links must not read as each other. `RootView` checks recovery first, so an
    /// invite that also parsed as recovery would hijack the invite flow, and a recovery URL that
    /// parsed as an invite is exactly how it was being swallowed before this change.
    func testRecoveryAndInviteLinksDoNotCrossParse() {
        XCTAssertNil(DeepLink.inviteCode(from: DeepLink.passwordRecoveryURL),
                     "a recovery URL must never be read as an invite code")
        XCTAssertFalse(DeepLink.isPasswordRecovery(URL(string: "genesyx://invite/ABC123XY")!),
                       "an invite must never be read as a recovery callback")
    }

    /// Old custom-scheme links must keep working forever — invites already in someone's inbox
    /// don't stop being valid because we switched the domain on.
    func testCustomSchemeStillParsesAfterUniversalLinksGoLive() throws {
        let url = try XCTUnwrap(DeepLink.schemeInviteURL(code: "OLDCODE1"))
        XCTAssertEqual(DeepLink.inviteCode(from: url), "OLDCODE1")
    }

    /// The link we HAND OUT must not become https until the AASA file is actually served — an
    /// https link with nothing behind it opens Safari to a 404, which is worse than the scheme.
    /// This test is the tripwire: flipping `universalLinksLive` without shipping the file fails it.
    func testHandedOutLinkMatchesWhatTheDomainCanActuallyServe() throws {
        let shared = try XCTUnwrap(DeepLink.inviteURL(code: "ABC123XY"))
        if DeepLink.universalLinksLive {
            XCTAssertEqual(shared.scheme, "https",
                           "universal links are live — hand out the web link")
            XCTAssertFalse(DeepLink.inviteShareText(code: "ABC123XY", from: "Ana").contains("Install Genesyx,"),
                           "the web link survives a fresh install; drop the install-first instructions")
        } else {
            XCTAssertEqual(shared.scheme, "genesyx",
                           "AASA not live yet — an https link would open Safari to a 404")
            XCTAssertTrue(DeepLink.inviteShareText(code: "ABC123XY", from: "Ana").contains("Install Genesyx,"),
                          "the scheme does nothing without the app, so the message must say so")
        }
    }
}
