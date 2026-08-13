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

    /// True when the last invite created was actually emailed to its recipient. False means the
    /// mailer isn't configured (or the send failed) and the share sheet is the only delivery.
    @Published private(set) var lastInviteEmailed = false

    /// Creates the invite and returns the row the database STORED, so the code in the share link is
    /// the code that redeems. The code itself is generated client-side and sent with the insert
    /// (`SupabasePartner.sendInvite`) — `partner_invites.code` has no default — but what comes back
    /// here is the persisted row, not the request, which is the property that actually matters.
    ///
    /// Said precisely because the previous wording claimed the database issued the code. It does
    /// not, and a future change that trusted that sentence — dropping the `.select()` round-trip as
    /// redundant, say — would quietly reintroduce the bug this class was written to kill.
    ///
    /// Then asks the server to email it. A failure there is deliberately NOT fatal: the invite is
    /// real and shareable either way, and throwing would destroy a perfectly good invite over a
    /// mail problem. What we must not do is *claim* it was emailed when it wasn't — hence the flag.
    @discardableResult
    func sendInvite(email: String) async throws -> PartnerInvite {
        guard let backend else { throw RemoteError.notConfigured }
        let invite = try await backend.sendInvite(email: email)
        lastInviteEmailed = (try? await backend.emailInvite(code: invite.code)) ?? false
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

    /// Refuses an invite addressed to this account, so the code stops being redeemable.
    ///
    /// Not the same as dismissing the sheet, which is what "Not now" does and which leaves the
    /// invite pending — and a pending invite is a standing offer to anyone the link was forwarded
    /// to. Not the same as `revoke` either: that is the inviter withdrawing one of her own.
    ///
    /// Throws on failure like every other method here, for the same reason: a decline is an
    /// agreement between two accounts, so only the server can say it happened.
    func decline(code: String) async throws {
        guard let backend else { throw RemoteError.notConfigured }
        try await backend.decline(code: code)
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
