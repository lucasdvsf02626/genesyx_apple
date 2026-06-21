import XCTest
@testable import Genesyx
import GenesyxCore

/// Verifies the auth + partner repositories route through a backend when present, and stay
/// local-only (mock) when not.
@MainActor
final class AuthPartnerBackendTests: XCTestCase {

    private final class FakeAuth: AuthBackend {
        var userId: String?
        private(set) var signInCount = 0
        private(set) var signUpCount = 0
        var currentUserId: String? { userId }
        func signUp(email: String, password: String) async throws { signUpCount += 1; userId = "u1" }
        func signIn(email: String, password: String) async throws { signInCount += 1; userId = "u1" }
        func signOut() async throws { userId = nil }
    }

    private final class FakePartner: PartnerBackend {
        var invitesList: [PartnerInvite] = []
        var partnerVal: Partner?
        private(set) var sent = 0
        func listInvites() async throws -> [PartnerInvite] { invitesList }
        func fetchPartner() async throws -> Partner? { partnerVal }
        func sendInvite(email: String) async throws { sent += 1; invitesList = [PartnerInvite(id: "i1", email: email, code: "CODE1234XXXX")] }
        func revoke(id: String) async throws {}
        func accept(code: String) async throws { partnerVal = Partner(name: "Remote Partner") }
        func unlink() async throws { partnerVal = nil }
    }

    func testAuthenticateRoutesThroughBackend() async throws {
        let auth = FakeAuth()
        let session = SessionRepository(auth: auth)
        try await session.authenticate(email: "a@b.com", password: "password1", name: "A", signUp: false)
        XCTAssertTrue(session.isSignedIn)
        XCTAssertEqual(session.displayName, "A")
        XCTAssertEqual(auth.signInCount, 1)
    }

    func testSessionRestoresFromExistingBackendUser() {
        let auth = FakeAuth(); auth.userId = "u1"
        XCTAssertTrue(SessionRepository(auth: auth).isSignedIn)
        XCTAssertFalse(SessionRepository(auth: nil).isSignedIn)
    }

    func testPartnerRefreshPullsFromBackend() async {
        let backend = FakePartner()
        backend.invitesList = [PartnerInvite(id: "i9", email: "p@x.com", code: "ABCDEFGH1234")]
        backend.partnerVal = Partner(name: "Remote Partner")
        let repo = PartnerRepository(backend: backend)
        await repo.refresh()
        XCTAssertEqual(repo.invites.first?.email, "p@x.com")
        XCTAssertEqual(repo.partner?.name, "Remote Partner")
    }

    func testNilBackendPartnerIsLocalMock() {
        let repo = PartnerRepository(backend: nil)
        repo.sendInvite(email: "local@x.com")
        XCTAssertEqual(repo.invites.count, 1)
        XCTAssertEqual(repo.invites.first?.email, "local@x.com")
    }
}
