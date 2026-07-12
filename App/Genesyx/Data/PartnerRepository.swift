import Foundation
import GenesyxCore

/// Partner linking. Unlike the health repositories, this one is NOT local-first: a partner link is
/// an agreement between two accounts, so only the server can say it happened. Every method awaits
/// the backend and throws on failure — nothing shows as invited, or as linked, until the database
/// says so.
///
/// The previous version invented an invite code on the device and appended it optimistically. The
/// server generated a *different* code, so the link she shared redeemed nothing; and an accept that
/// failed still displayed a partner.
@MainActor
final class PartnerRepository: ObservableObject {

    @Published private(set) var invites: [PartnerInvite] = []
    @Published private(set) var partner: Partner?

    private let backend: PartnerBackend?

    init(backend: PartnerBackend? = nil) {
        self.backend = backend
    }

    /// Creates the invite and returns it carrying the code the DATABASE issued — that code is what
    /// the share link redeems, so it must never be guessed on the device.
    @discardableResult
    func sendInvite(email: String) async throws -> PartnerInvite {
        guard let backend else { throw RemoteError.notConfigured }
        let invite = try await backend.sendInvite(email: email)
        await refresh()
        return invite
    }

    func revoke(id: String) async throws {
        guard let backend else { throw RemoteError.notConfigured }
        try await backend.revoke(id: id)
        await refresh()
    }

    /// Redeems an invite code. The server checks the invite is still pending and was addressed to
    /// *this* account's email, so a link forwarded to the wrong person is refused — and that refusal
    /// arrives here as a thrown error rather than a fake success.
    func accept(code: String) async throws {
        guard let backend else { throw RemoteError.notConfigured }
        try await backend.accept(code: code)
        await refresh()
    }

    func unlink() async throws {
        guard let backend else { throw RemoteError.notConfigured }
        try await backend.unlink()
        await refresh()
    }

    /// Pull invites + linked partner from the remote (no-op when local-only).
    func refresh() async {
        guard let backend else { return }
        if let remote = try? await backend.listInvites() { invites = remote }
        partner = try? await backend.fetchPartner()
    }

    /// Cleared on sign-out — the next account must not inherit a partner or a pending invite.
    func clearLocalState() {
        invites = []
        partner = nil
    }
}
