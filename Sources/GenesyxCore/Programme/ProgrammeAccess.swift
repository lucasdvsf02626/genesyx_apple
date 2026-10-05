import Foundation

/// Whether an account holds Programme Access.
public enum ProgrammeAccessStatus: String, Codable, Sendable, CaseIterable {
    case none, active, revoked
}

/// Where a grant of Programme Access came from. The production source is not decided; the model
/// names every source it could be so that choosing one later is a new provider, not a new model.
public enum ProgrammeAccessSource: String, Codable, Sendable, CaseIterable {
    case apple, googlePlay, internalQA, admin, otherApproved
}

/// One account's Programme Access. A record of a grant, not a local switch: the production source
/// has to be verifiable, and this is the shape a verified answer is cached in.
///
/// Independent of `ProgrammeState` on purpose. Holding access says nothing about whether the
/// programme has started, and nothing here can set a start date.
public struct ProgrammeAccess: Hashable, Codable, Sendable {
    public var status: ProgrammeAccessStatus
    public var source: ProgrammeAccessSource?
    public var productID: String?
    public var accountID: String?
    public var grantedAt: Date?
    /// The granting system's own reference (a transaction or grant id). Never an activation code.
    public var externalReference: String?

    public init(
        status: ProgrammeAccessStatus,
        source: ProgrammeAccessSource? = nil,
        productID: String? = nil,
        accountID: String? = nil,
        grantedAt: Date? = nil,
        externalReference: String? = nil
    ) {
        self.status = status
        self.source = source
        self.productID = productID
        self.accountID = accountID
        self.grantedAt = grantedAt
        self.externalReference = externalReference
    }

    public static let none = ProgrammeAccess(status: .none)

    /// The one access decision. Only `active` counts; `revoked` and `none` do not.
    public var hasProgrammeAccess: Bool { status == .active }
}

/// What came of checking an activation code. Carries no part of the code that was entered, so it
/// is safe to describe, compare and pass around.
public enum ProgrammeActivationOutcome: Hashable, Sendable {
    case accepted(source: ProgrammeAccessSource)
    /// Not a code this build recognises.
    case rejectedUnknown
    /// Nothing was entered.
    case rejectedEmpty
    /// This build has no way to redeem a code at all. Returned for every non-empty entry alike.
    case rejectedNotAvailableInThisBuild
}

/// Activation-code rules. Pure: the caller decides what an accepted code grants.
public enum ProgrammeActivationCode {

    /// The internal QA codes. Private, and absent from every outcome and description.
    private static let internalQACodes: Set<String> = ["GX90-QA-001", "GX90-QA-002", "GX90-QA-003"]

    /// Surrounding whitespace removed, upper-cased. Nothing inside the entry is altered, so a code
    /// typed without its hyphens stays a different code.
    public static func normalise(_ entry: String) -> String {
        entry.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// Checks an entry.
    ///
    /// `internalQAAllowed` is for the app layer to pass `true` in development builds only. When it
    /// is `false` no code can be redeemed, and every non-empty entry gets the same answer: the
    /// internal codes are told apart from any other text only when the flag is `true`.
    public static func validate(_ entry: String, internalQAAllowed: Bool) -> ProgrammeActivationOutcome {
        let code = normalise(entry)
        guard !code.isEmpty else { return .rejectedEmpty }
        guard internalQAAllowed else { return .rejectedNotAvailableInThisBuild }
        return internalQACodes.contains(code) ? .accepted(source: .internalQA) : .rejectedUnknown
    }
}

/// The result of trying to redeem a code: what happened, and the access that now holds.
public struct ProgrammeRedemption: Hashable, Sendable {
    public let outcome: ProgrammeActivationOutcome
    /// The new grant when the code was accepted; otherwise the access held before, untouched.
    public let access: ProgrammeAccess
}

/// The pure decisions behind an app-layer access service. That service offers exactly
/// `hasAccess`, `activate`/`redeem(code)`, `refresh`, `restore` and `source`; it owns storage and
/// the provider, and asks these functions what each call should leave behind:
///
///     hasAccess  ->  ProgrammeAccess.hasProgrammeAccess
///     source     ->  ProgrammeAccess.source
///     redeem     ->  ProgrammeAccessDecisions.redeem
///     refresh, restore  ->  ProgrammeAccessDecisions.resolve, with the provider's verified answer
///     QA reset   ->  ProgrammeAccessDecisions.reset
///
/// None of them reads or writes a programme start date.
public enum ProgrammeAccessDecisions {

    /// Redeems an entry against the access currently held.
    ///
    /// An accepted code on an account that already holds active access changes nothing, so a
    /// second tap or a second redemption keeps the original grant and its date.
    public static func redeem(
        _ entry: String,
        current: ProgrammeAccess,
        internalQAAllowed: Bool,
        productID: String? = nil,
        accountID: String? = nil,
        now: Date
    ) -> ProgrammeRedemption {
        let outcome = ProgrammeActivationCode.validate(entry, internalQAAllowed: internalQAAllowed)
        guard case .accepted(let source) = outcome, !current.hasProgrammeAccess else {
            return ProgrammeRedemption(outcome: outcome, access: current)
        }
        let granted = ProgrammeAccess(status: .active, source: source, productID: productID,
                                      accountID: accountID, grantedAt: now)
        return ProgrammeRedemption(outcome: outcome, access: granted)
    }

    /// Refresh and restore. A verified answer from the provider replaces the cached one, whatever
    /// it says; no answer (offline, or the provider could not be reached) keeps the cache.
    public static func resolve(cached: ProgrammeAccess, verified: ProgrammeAccess?) -> ProgrammeAccess {
        verified ?? cached
    }

    /// QA reset: back to no access, so the activation flow can be run again. Does nothing unless
    /// internal QA is allowed in this build.
    public static func reset(_ current: ProgrammeAccess, internalQAAllowed: Bool) -> ProgrammeAccess {
        internalQAAllowed ? .none : current
    }
}
