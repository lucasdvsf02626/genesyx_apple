import Foundation
import GenesyxCore

/// What a provider answered to one redemption attempt. Carries no part of what was typed.
enum FertilityKitProviderAnswer: Equatable {
    /// Granted now, or already held: the provider's own record.
    case granted(ProgrammeAccess)
    /// Never `.accepted`.
    case rejected(ProgrammeActivationOutcome)
    /// Could not be reached; nothing changed anywhere.
    case unreachable
}

/// Where Fertility Kit access comes from. `FertilityKitAccessService` asks only this, so the
/// screens never learn which provider granted access. Every call must return: the service takes
/// one call at a time, so a provider that cannot be reached times out to `.unreachable` or nil.
@MainActor
protocol FertilityKitAccessProviding: AnyObject {
    func redeem(_ entry: String, accountID: String, now: Date) async -> FertilityKitProviderAnswer
    /// The provider's own verified answer for this account. nil = it cannot give one (offline, or
    /// nothing configured).
    func verifiedAccess(accountID: String) async -> ProgrammeAccess?
    /// As `verifiedAccess`, after asking the provider to look again for grants made elsewhere
    /// (reinstall, another device).
    func restoredAccess(accountID: String) async -> ProgrammeAccess?
}

/// The production provider today: nothing is configured, so it grants nothing and stores nothing.
/// Every non-empty entry gets the same answer, the internal QA codes included.
///
/// THE PRODUCTION INTEGRATION POINT. A real provider (Apple in-app purchase, Google Play on
/// Android, or a Genesyx backend entitlement) replaces this type and nothing else: the service,
/// its cache and every screen stay as they are. It must return a record that can be verified:
/// `source`, `productID`, `accountID`, `grantedAt`, and `externalReference` set to the granting
/// system's own transaction or grant id.
///
/// Which source that is remains the owner's decision and is not chosen here. A code or QR card
/// redeemed for digital content has App Store 3.1.1 exposure and needs advice before it is built.
/// No store credentials are invented in this file.
final class UnconfiguredFertilityKitAccessProvider: FertilityKitAccessProviding {

    func redeem(_ entry: String, accountID: String, now: Date) async -> FertilityKitProviderAnswer {
        .rejected(ProgrammeActivationCode.validate(entry, internalQAAllowed: false))
    }

    func verifiedAccess(accountID: String) async -> ProgrammeAccess? { nil }

    func restoredAccess(accountID: String) async -> ProgrammeAccess? { nil }
}

#if DEBUG
/// The development stand-in for a server. It keeps a ledger of grants per account that survives
/// sign-out, so refresh, restore and sign-out then sign-in can be exercised by QA. Whether an
/// entry is a QA code is the core's decision; no code is written in the app.
final class InternalQAFertilityKitAccessProvider: FertilityKitAccessProviding {

    private let store: LocalStore
    private let makeGrantReference: () -> String
    private let ledgerKey = "fertility_kit_qa_grants"

    init(store: LocalStore, makeGrantReference: @escaping () -> String = { "qa-" + UUID().uuidString }) {
        self.store = store
        self.makeGrantReference = makeGrantReference
    }

    private var ledger: [String: ProgrammeAccess] {
        get { store.load([String: ProgrammeAccess].self, forKey: ledgerKey) ?? [:] }
        set { store.save(newValue, forKey: ledgerKey) }
    }

    func redeem(_ entry: String, accountID: String, now: Date) async -> FertilityKitProviderAnswer {
        let redemption = ProgrammeAccessDecisions.redeem(
            entry, current: ledger[accountID] ?? ProgrammeAccess.none, internalQAAllowed: true,
            productID: "internal-qa-fertility-kit", accountID: accountID, now: now)
        guard case .accepted = redemption.outcome else { return .rejected(redemption.outcome) }
        var access = redemption.access
        // Only a new grant gets a reference: a repeat keeps the first grant untouched.
        if access.externalReference == nil { access.externalReference = makeGrantReference() }
        ledger[accountID] = access
        return .granted(access)
    }

    func verifiedAccess(accountID: String) async -> ProgrammeAccess? { ledger[accountID] ?? ProgrammeAccess.none }

    func restoredAccess(accountID: String) async -> ProgrammeAccess? { ledger[accountID] ?? ProgrammeAccess.none }

    /// QA reset: the stand-in server forgets this account's grant.
    func forget(accountID: String) { ledger[accountID] = nil }

    /// UI-test seed: the stand-in server records a grant for this account, with no entry at all.
    func seedGrant(accountID: String, now: Date) -> ProgrammeAccess {
        let access = ProgrammeAccess(status: .active, source: .internalQA, productID: "internal-qa-fertility-kit",
                                     accountID: accountID, grantedAt: now, externalReference: makeGrantReference())
        ledger[accountID] = access
        return access
    }
}
#endif

/// The one place the build decides where access comes from.
enum FertilityKitAccessProviders {

    #if DEBUG
    static let internalQAAllowed = true
    #else
    static let internalQAAllowed = false
    #endif

    @MainActor static func current(store: LocalStore) -> FertilityKitAccessProviding {
        #if DEBUG
        return InternalQAFertilityKitAccessProvider(store: store)
        #else
        return UnconfiguredFertilityKitAccessProvider()
        #endif
    }
}
