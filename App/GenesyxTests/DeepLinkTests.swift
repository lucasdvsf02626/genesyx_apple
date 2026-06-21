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
}
