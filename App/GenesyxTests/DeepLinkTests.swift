import XCTest
@testable import Genesyx

/// Verifies partner-invite deep-link parsing for both the custom scheme and Universal Links.
final class DeepLinkTests: XCTestCase {

    func testCustomScheme() {
        XCTAssertEqual(DeepLink.inviteCode(from: URL(string: "genesyx://invite/ABC123XY")!), "ABC123XY")
    }

    func testUniversalLink() {
        XCTAssertEqual(
            DeepLink.inviteCode(from: URL(string: "https://genesis-cycle-guide.lovable.app/invite/CODE1234")!),
            "CODE1234"
        )
    }

    func testNonInviteReturnsNil() {
        XCTAssertNil(DeepLink.inviteCode(from: URL(string: "genesyx://home")!))
        XCTAssertNil(DeepLink.inviteCode(from: URL(string: "https://example.com/about")!))
    }

    /// The Universal Link on our own domain — the one that survives a fresh install.
    func testOurUniversalLinkRoundTrips() throws {
        let url = try XCTUnwrap(DeepLink.webInviteURL(code: "CODE5678"))
        XCTAssertEqual(url.absoluteString, "https://genesyx.co.uk/invite/CODE5678")
        XCTAssertEqual(DeepLink.inviteCode(from: url), "CODE5678", "our own link must parse back")
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
