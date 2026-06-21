import Foundation

/// Current-focus toggle on Profile (fertility prep vs pregnancy mode).
public enum FocusMode: String, CaseIterable, Sendable {
    case prep, pregnancy
}

/// App theme preference; `.system` follows the device setting.
public enum ThemeMode: String, CaseIterable, Sendable {
    case system, light, dark
}

public enum InviteStatus: String, Sendable {
    case pending, accepted, revoked
}

/// A partner invite the current user has sent. Mirrors `partner_invites`.
public struct PartnerInvite: Identifiable, Hashable, Sendable {
    public let id: String
    public let email: String
    public let code: String
    public var status: InviteStatus

    public init(id: String, email: String, code: String, status: InviteStatus = .pending) {
        self.id = id
        self.email = email
        self.code = code
        self.status = status
    }
}

/// A linked partner.
public struct Partner: Hashable, Sendable {
    public let name: String
    public init(name: String) { self.name = name }
}
