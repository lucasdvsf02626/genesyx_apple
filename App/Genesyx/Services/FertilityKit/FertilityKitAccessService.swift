import Foundation
import GenesyxCore

/// What came of one attempt to activate. Typed, with no text in it: the screen chooses the words.
enum FertilityKitActivationResult: Equatable, CaseIterable {
    case activated, alreadyActive, empty, notRecognised, notAvailableInThisBuild, couldNotReachProvider, signedOut, busy
}

enum FertilityKitVerificationResult: Equatable {
    /// The provider answered; the cache now holds its answer.
    case verified(hasAccess: Bool)
    /// No answer; the cache was kept.
    case couldNotVerify(hasAccess: Bool)
    case signedOut
    case busy
}

/// Fertility Kit access for the signed-in account: `hasAccess`, `redeem`, `refresh`, `restore`
/// and `source`, and nothing else. The provider decides who holds access; this type keeps a cache
/// of its last answer and asks `ProgrammeAccessDecisions` what each call should leave behind.
///
/// Access is all it knows. Activating never starts the programme: nothing here reads or writes a
/// start date or any programme progress.
///
/// Sign-out and account change. `clearLocalState()` removes the cache, as every other per-account
/// store is wiped at sign-out. The same account signing in again gets access back only from the
/// provider, through `refresh()`. A different account gets the provider's answer for that account.
/// The cache is never the source of truth, and it is only ever read through `usable`, so a record
/// left behind by another account counts for nothing even if nothing cleared it. Only a change to
/// the cache publishes, so whoever changes the identity calls `clearLocalState()` or `refresh()`.
@MainActor
final class FertilityKitAccessService: ObservableObject {

    /// A call is waiting for the provider.
    @Published private(set) var isWorking = false
    /// The provider's last answer for whoever was signed in when it was given. Read through `usable`.
    @Published private var cached: ProgrammeAccess

    private let store: LocalStore
    private let provider: FertilityKitAccessProviding
    private let accountIdentity: @MainActor () -> String?
    private let internalQAAllowed: Bool
    private let now: () -> Date
    private let cacheKey = "fertility_kit_access"

    /// `accountIdentity` answers nil when signed out. `internalQAAllowed` is a parameter so a test
    /// can build the Release configuration.
    init(store: LocalStore,
         provider: FertilityKitAccessProviding,
         accountIdentity: @escaping @MainActor () -> String?,
         internalQAAllowed: Bool = FertilityKitAccessProviders.internalQAAllowed,
         now: @escaping () -> Date = Date.init) {
        self.store = store
        self.provider = provider
        self.accountIdentity = accountIdentity
        self.internalQAAllowed = internalQAAllowed
        self.now = now
        // A record this build cannot decode loads as no access.
        let stored = store.load(ProgrammeAccess.self, forKey: cacheKey) ?? ProgrammeAccess.none
        if stored.source == .internalQA && !internalQAAllowed {
            // A Release build installed over a development build neither honours nor keeps its grant.
            store.remove(forKey: cacheKey)
            cached = .none
        } else {
            cached = stored
        }
    }

    var hasAccess: Bool { usableAccess.hasProgrammeAccess }

    /// Where the access came from. nil unless `hasAccess`.
    var source: ProgrammeAccessSource? { hasAccess ? usableAccess.source : nil }

    /// The single rule for what a record is worth: nothing, unless it belongs to the account
    /// signed in right now, says where it came from, and is not a development grant in a build
    /// that does not allow one. The cache is read through it, and a provider's grant is kept only
    /// if it passes.
    static func usable(_ cached: ProgrammeAccess, accountID: String?, internalQAAllowed: Bool) -> ProgrammeAccess {
        guard let accountID, cached.accountID == accountID, cached.source != nil,
              cached.source != .internalQA || internalQAAllowed else { return .none }
        return cached
    }

    private var usableAccess: ProgrammeAccess {
        Self.usable(cached, accountID: accountIdentity(), internalQAAllowed: internalQAAllowed)
    }

    /// Activate. Nothing is written before the provider answers, and the entry is passed on, never kept.
    func redeem(_ entry: String) async -> FertilityKitActivationResult {
        guard !isWorking else { return .busy }
        guard !ProgrammeActivationCode.normalise(entry).isEmpty else { return .empty }
        guard let account = accountIdentity() else { return .signedOut }
        // The provider is not asked, so a second code can never be used up on an account that has access.
        guard !usableAccess.hasProgrammeAccess else { return .alreadyActive }

        isWorking = true
        let answer = await provider.redeem(entry, accountID: account, now: now())
        isWorking = false
        // Signed out or switched account while waiting: the answer belongs to nobody here.
        guard accountIdentity() == account else { return .signedOut }

        switch answer {
        case .granted(let access)
            where Self.usable(access, accountID: account, internalQAAllowed: internalQAAllowed).hasProgrammeAccess:
            keep(access)
            return .activated
        case .rejected(.rejectedEmpty):
            return .empty
        case .rejected(.rejectedUnknown):
            return .notRecognised
        case .rejected(.rejectedNotAvailableInThisBuild):
            return .notAvailableInThisBuild
        case .granted, .rejected(.accepted), .unreachable:
            return .couldNotReachProvider
        }
    }

    func refresh() async -> FertilityKitVerificationResult {
        await verify { await $0.verifiedAccess(accountID: $1) }
    }

    func restore() async -> FertilityKitVerificationResult {
        await verify { await $0.restoredAccess(accountID: $1) }
    }

    /// A verified answer replaces the cache, whatever it says; no answer keeps it (offline grace).
    private func verify(
        _ ask: @MainActor (FertilityKitAccessProviding, String) async -> ProgrammeAccess?
    ) async -> FertilityKitVerificationResult {
        guard !isWorking else { return .busy }
        guard let account = accountIdentity() else { return .signedOut }

        isWorking = true
        var verified = await ask(provider, account)
        isWorking = false
        guard accountIdentity() == account else { return .signedOut }

        // An answer bound to another account, or access `usable` would not honour, says nothing
        // about this one. A refusal bound to nobody is still an answer.
        if let answer = verified {
            let honoured = Self.usable(answer, accountID: account, internalQAAllowed: internalQAAllowed).hasProgrammeAccess
            if (answer.accountID ?? account) != account || answer.hasProgrammeAccess != honoured { verified = nil }
        }
        let held = Self.usable(cached, accountID: account, internalQAAllowed: internalQAAllowed)
        keep(ProgrammeAccessDecisions.resolve(cached: held, verified: verified))
        return verified == nil ? .couldNotVerify(hasAccess: hasAccess) : .verified(hasAccess: hasAccess)
    }

    /// Sign-out: forget the cache, in memory and in the store.
    func clearLocalState() {
        keep(.none)
    }

    #if DEBUG
    /// QA reset: the stand-in server forgets the grant and the cache goes with it, so the
    /// activation flow can be run again. Touches nothing else.
    func resetForQA() {
        if let account = accountIdentity() {
            (provider as? InternalQAFertilityKitAccessProvider)?.forget(accountID: account)
        }
        keep(ProgrammeAccessDecisions.reset(cached, internalQAAllowed: internalQAAllowed))
    }

    /// UI-test seed: the signed-in account holds access, in the stand-in server's ledger and in
    /// the cache, so the first `refresh()` keeps it. Nothing is typed and no entry is stored.
    func seedGrantForUITests() {
        guard let account = accountIdentity(),
              let access = (provider as? InternalQAFertilityKitAccessProvider)?.seedGrant(accountID: account, now: now())
        else { return }
        keep(access)
    }
    #endif

    /// No access is stored as the absence of the key.
    private func keep(_ access: ProgrammeAccess) {
        cached = access
        if access.status == .none {
            store.remove(forKey: cacheKey)
        } else {
            store.save(access, forKey: cacheKey)
        }
    }
}
