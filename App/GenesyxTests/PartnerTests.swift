import XCTest
@testable import Genesyx
import GenesyxCore

/// Partner linking is the one feature that is NOT local-first: a link is an agreement between two
/// accounts, so only the server can say it happened. These tests pin the two ways the old code lied
/// about that — an invented invite code, and an optimistic link — plus the share link itself.
///
/// **Scope note.** Partner linking is excluded from the 1.2.0 public iOS release: no UI reaches it
/// and no deep link opens it (`FeatureFlags.partnerInvites` is `false`). These tests call
/// `PartnerRepository` directly, so they still hold — they describe the repository, not something a
/// user of this build can do. They are kept because the same Supabase backend serves the Android
/// app, which does ship partner linking, and because the feature returns after 1.2.0.
/// `AuthGateUITests` is what asserts the iOS release scope.
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

    /// Creating a row invited nobody: no email was ever sent, and the address she typed was only
    /// ever used as a server-side check at accept time. The invite must now actually be mailed to
    /// the code the database issued.
    func testCreatingAnInviteEmailsIt() async throws {
        let backend = FakePartnerBackend()
        backend.serverCode = "SERVER-CODE-0002"
        let repo = PartnerRepository(backend: backend)

        _ = try await repo.sendInvite(email: "partner@example.com")

        XCTAssertEqual(backend.emailedCodes, ["SERVER-CODE-0002"], "the invite must be emailed")
        XCTAssertTrue(repo.lastInviteEmailed, "and we may say so")
    }

    /// The mailer may not be configured. That must NOT destroy a perfectly good invite — she can
    /// still share the link by hand — but we must not claim we emailed it either.
    func testAnUnsentEmailStillLeavesAUsableInvite() async throws {
        let backend = FakePartnerBackend()
        backend.emailSends = false            // e.g. RESEND_API_KEY not set
        let repo = PartnerRepository(backend: backend)

        let invite = try await repo.sendInvite(email: "partner@example.com")

        XCTAssertEqual(repo.invites.first?.code, invite.code, "the invite still exists")
        XCTAssertFalse(repo.lastInviteEmailed, "never claim an email we didn't send")
    }

    /// Same, but the mail call blows up outright: still not fatal to the invite.
    func testAFailingMailerDoesNotFailTheInvite() async throws {
        let backend = FakePartnerBackend()
        backend.emailThrows = true
        let repo = PartnerRepository(backend: backend)

        let invite = try await repo.sendInvite(email: "partner@example.com")

        XCTAssertEqual(repo.invites.first?.code, invite.code, "a mail failure must not lose the invite")
        XCTAssertFalse(repo.lastInviteEmailed)
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

    // MARK: - Declining (the recipient's refusal, which had no path at all)

    /// "Not now" only dismissed the sheet, so the invite stayed pending — a standing offer to
    /// whoever else the link had been forwarded to. Declining has to actually end it, and the proof
    /// is that the same code no longer redeems.
    func testDecliningEndsTheInviteForGood() async throws {
        let backend = FakePartnerBackend()
        backend.serverCode = "SERVER-CODE-0003"
        let repo = PartnerRepository(backend: backend)
        _ = try await repo.sendInvite(email: "partner@example.com")

        try await repo.decline(code: "SERVER-CODE-0003")

        XCTAssertEqual(repo.invites.first?.status, .declined, "declined is its own status, not revoked")
        XCTAssertNil(repo.partner, "refusing is the opposite of linking")

        do {
            try await repo.accept(code: "SERVER-CODE-0003")
            XCTFail("a declined code must stop redeeming")
        } catch {}
        XCTAssertNil(repo.partner)
    }

    /// The mirror of `testARefusedAcceptDoesNotShowAPartner`, and the more dangerous direction: if a
    /// failed decline reported success she would believe a link was killed that is still live.
    func testAFailedDeclineThrowsAndLeavesTheInviteRedeemable() async throws {
        let backend = FakePartnerBackend()
        backend.serverCode = "SERVER-CODE-0004"
        backend.declineSucceeds = false
        let repo = PartnerRepository(backend: backend)
        _ = try await repo.sendInvite(email: "partner@example.com")

        do {
            try await repo.decline(code: "SERVER-CODE-0004")
            XCTFail("a failed decline must throw")
        } catch {}

        XCTAssertEqual(repo.invites.first?.status, .pending, "nothing happened — show nothing")
        try await repo.accept(code: "SERVER-CODE-0004")
        XCTAssertNotNil(repo.partner, "the invite really is still live; the throw was not cosmetic")
    }

    /// A backend that cannot make the call must fail loudly. The protocol default is a throw for
    /// exactly this reason; a no-op would be a silent lie.
    func testABackendWithoutDeclineFailsLoudly() async {
        let repo = PartnerRepository(backend: LegacyPartnerBackend())

        do {
            try await repo.decline(code: "any-code")
            XCTFail("the default must throw, never quietly succeed")
        } catch {}
    }

    /// `declined` has to survive the trip back from Postgres, or the inviter's list would show a
    /// refusal as something else.
    func testDeclinedSurvivesTheRoundTripFromTheDatabase() throws {
        let row = try decodeInviteRow(status: "declined")

        XCTAssertEqual(row.domain.status, .declined)
    }

    /// The migration that adds `declined` lands before both clients ship. A build that has never
    /// heard of a status must degrade to pending rather than throw — one unknown value would
    /// otherwise fail the decode of the whole invite list.
    func testAnUnknownStatusDegradesToPendingInsteadOfFailingTheList() throws {
        let row = try decodeInviteRow(status: "some_future_status")

        XCTAssertEqual(row.domain.status, .pending)
    }

    private func decodeInviteRow(status: String) throws -> PartnerInviteRow {
        let json = """
        {"id":"inv-1","inviter_id":"user-1","invitee_email":"partner@example.com",\
        "code":"abc123def456","status":"\(status)"}
        """
        return try JSONDecoder().decode(PartnerInviteRow.self, from: Data(json.utf8))
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
    var declineSucceeds = true
    var serverCode = "server-issued-code"
    /// Mail outcomes: sent, silently not-configured, or an outright failure.
    var emailSends = true
    var emailThrows = false
    private(set) var emailedCodes: [String] = []

    private var stored: [PartnerInvite] = []
    private var linked: Partner?
    private var declinedCodes: Set<String> = []

    func emailInvite(code: String) async throws -> Bool {
        if emailThrows { throw RemoteError.notConfigured }
        emailedCodes.append(code)
        return emailSends
    }

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

    /// A declined code is refused here, exactly as the Edge Function refuses a non-pending invite.
    /// Without that clause the fake would happily redeem a declined invite and the test that says
    /// declining ends it would pass while proving nothing.
    func accept(code: String) async throws {
        guard online, acceptSucceeds, !declinedCodes.contains(code) else { throw RemoteError.notAuthenticated }
        linked = Partner(name: "Sam")
    }

    /// Writes a status and nothing else — no `linked`, because a decline is the opposite of a link.
    func decline(code: String) async throws {
        guard online, declineSucceeds else { throw RemoteError.notAuthenticated }
        declinedCodes.insert(code)
        if let i = stored.firstIndex(where: { $0.code == code }) { stored[i].status = .declined }
    }

    func unlink() async throws {
        guard online else { throw RemoteError.notConfigured }
        linked = nil
    }
}

/// A conformer from before `decline` existed: it does not implement the method, so it takes the
/// protocol's default. Present so that default stays a THROW — a later "convenience" no-op would
/// let the UI report a refusal that never reached the database, leaving the invite redeemable by
/// whoever else holds the link.
@MainActor
private final class LegacyPartnerBackend: PartnerBackend {
    func listInvites() async throws -> [PartnerInvite] { [] }
    func fetchPartner() async throws -> Partner? { nil }
    func sendInvite(email: String) async throws -> PartnerInvite {
        PartnerInvite(id: UUID().uuidString, email: email, code: "legacy-code", status: .pending)
    }
    func revoke(id: String) async throws {}
    func accept(code: String) async throws {}
    func unlink() async throws {}
}
