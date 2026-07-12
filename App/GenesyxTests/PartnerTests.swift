import XCTest
@testable import Genesyx
import GenesyxCore

/// Partner linking is the one feature that is NOT local-first: a link is an agreement between two
/// accounts, so only the server can say it happened. These tests pin the two ways the old code lied
/// about that — an invented invite code, and an optimistic link — plus the share link itself.
@MainActor
final class PartnerTests: XCTestCase {

    private func makeStore() -> LocalStore {
        LocalStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
    }

    /// The bug that made every invite useless: the device invented a code, the database issued a
    /// DIFFERENT one, and she shared the device's. The link redeemed nothing.
    func testTheInviteCarriesTheCodeTheDatabaseIssued() async throws {
        let backend = FakePartnerBackend()
        backend.serverCode = "SERVER-CODE-0001"
        let repo = PartnerRepository(backend: backend)

        let invite = try await repo.sendInvite(email: "partner@example.com")

        XCTAssertEqual(invite.code, "SERVER-CODE-0001", "the shared code must be the server's")
        XCTAssertEqual(repo.invites.first?.code, "SERVER-CODE-0001")
    }

    /// A failed invite must not appear to have been sent.
    func testAFailedInviteIsNotShownAsPending() async {
        let backend = FakePartnerBackend()
        backend.online = false
        let repo = PartnerRepository(backend: backend)

        do {
            _ = try await repo.sendInvite(email: "partner@example.com")
            XCTFail("a failed invite must throw")
        } catch {}

        XCTAssertTrue(repo.invites.isEmpty, "nothing was created — show nothing")
    }

    /// The server refuses an invite addressed to someone else (verified live: HTTP 403). The old
    /// code set `partner` regardless, so she'd have seen a partner who was never linked.
    func testARefusedAcceptDoesNotShowAPartner() async {
        let backend = FakePartnerBackend()
        backend.acceptSucceeds = false
        let repo = PartnerRepository(backend: backend)

        do {
            try await repo.accept(code: "not-mine")
            XCTFail("a refused invite must throw")
        } catch {}

        XCTAssertNil(repo.partner, "no link, no partner")
    }

    func testAcceptedInviteShowsThePartner() async throws {
        let repo = PartnerRepository(backend: FakePartnerBackend())

        try await repo.accept(code: "good-code")

        XCTAssertEqual(repo.partner?.name, "Sam")
    }

    func testUnlinkClearsThePartner() async throws {
        let repo = PartnerRepository(backend: FakePartnerBackend())
        try await repo.accept(code: "good-code")

        try await repo.unlink()

        XCTAssertNil(repo.partner)
    }

    /// Sign-out must not leave the next account holding her partner.
    func testSignOutClearsThePartnerLink() async throws {
        let container = AppContainer(store: makeStore(), backend: nil)
        let repo = PartnerRepository(backend: FakePartnerBackend())
        try await repo.accept(code: "good-code")
        XCTAssertNotNil(repo.partner)

        repo.clearLocalState()

        XCTAssertNil(repo.partner)
        XCTAssertTrue(repo.invites.isEmpty)
        _ = container
    }

    // MARK: - The share link (the step that was missing entirely)

    func testTheShareLinkRoundTripsBackToTheCode() throws {
        let url = try XCTUnwrap(DeepLink.inviteURL(code: "abc123def456"))

        XCTAssertEqual(url.absoluteString, "genesyx://invite/abc123def456")
        XCTAssertEqual(DeepLink.inviteCode(from: url), "abc123def456")
    }

    /// The message has to carry the link AND say what to do with it — a custom-scheme URL does
    /// nothing on a phone that hasn't got the app yet.
    func testTheShareMessageTellsHimWhatToDo() {
        let text = DeepLink.inviteShareText(code: "abc123def456", from: "Ada")

        XCTAssertTrue(text.contains("genesyx://invite/abc123def456"))
        XCTAssertTrue(text.contains("Ada has invited you"))
        XCTAssertTrue(text.lowercased().contains("install"))
        XCTAssertTrue(text.lowercased().contains("sign in with this email"),
                      "the invite is bound to the address it was sent to — say so, or it just fails")
    }
}

/// Stands in for Supabase. `serverCode` is what the database would issue — deliberately different
/// from anything the client could guess.
@MainActor
private final class FakePartnerBackend: PartnerBackend {
    var online = true
    var acceptSucceeds = true
    var serverCode = "server-issued-code"

    private var stored: [PartnerInvite] = []
    private var linked: Partner?

    func listInvites() async throws -> [PartnerInvite] {
        guard online else { throw RemoteError.notConfigured }
        return stored
    }

    func fetchPartner() async throws -> Partner? {
        guard online else { throw RemoteError.notConfigured }
        return linked
    }

    func sendInvite(email: String) async throws -> PartnerInvite {
        guard online else { throw RemoteError.notConfigured }
        let invite = PartnerInvite(id: UUID().uuidString, email: email, code: serverCode, status: .pending)
        stored.append(invite)
        return invite
    }

    func revoke(id: String) async throws {
        guard online else { throw RemoteError.notConfigured }
        stored.removeAll { $0.id == id }
    }

    func accept(code: String) async throws {
        guard online, acceptSucceeds else { throw RemoteError.notAuthenticated }
        linked = Partner(name: "Sam")
    }

    func unlink() async throws {
        guard online else { throw RemoteError.notConfigured }
        linked = nil
    }
}
