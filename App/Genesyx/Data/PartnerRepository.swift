import Foundation
import GenesyxCore

/// Partner linking. Local-first in-memory mock (v1); mirrors to a `PartnerBackend` and refreshes
/// from it when provided. `sendInvite` generates a 16-char code locally for immediate UI feedback.
/// Mirrors the Android `PartnerRepository`.
@MainActor
final class PartnerRepository: ObservableObject {

    @Published private(set) var invites: [PartnerInvite] = []
    @Published private(set) var partner: Partner?

    private let backend: PartnerBackend?

    init(backend: PartnerBackend? = nil) {
        self.backend = backend
    }

    func sendInvite(email: String) {
        let code = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16))
        invites.append(PartnerInvite(id: UUID().uuidString, email: email, code: code))
        if let backend { Task { try? await backend.sendInvite(email: email); await refresh() } }
    }

    func revoke(id: String) {
        invites = invites.map { $0.id == id ? PartnerInvite(id: $0.id, email: $0.email, code: $0.code, status: .revoked) : $0 }
        if let backend { Task { try? await backend.revoke(id: id); await refresh() } }
    }

    func accept(code: String) {
        partner = Partner(name: "Your partner")
        if let backend { Task { try? await backend.accept(code: code); await refresh() } }
    }

    func unlink() {
        partner = nil
        if let backend { Task { try? await backend.unlink(); await refresh() } }
    }

    /// Pull invites + linked partner from the remote (no-op when local-only).
    func refresh() async {
        guard let backend else { return }
        if let remote = try? await backend.listInvites() { invites = remote }
        partner = try? await backend.fetchPartner()
    }
}
