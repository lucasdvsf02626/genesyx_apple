import XCTest
@testable import Genesyx
import GenesyxCore

/// Fertility Kit access: the service, the provider that grants nothing (production today), the
/// development provider behind the three internal QA codes, and the build gate between them.
/// The code rules themselves are tested in the core (`ProgrammeAccessTests`).
@MainActor
final class FertilityKitAccessServiceTests: XCTestCase {

    private static let cacheKey = "genesyx.fertility_kit_access"
    private static let ledgerKey = "genesyx.fertility_kit_qa_grants"

    private let qaCodes = ["GX90-QA-001", "GX90-QA-002", "GX90-QA-003"]
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    private let ada = "account-ada"
    private let bea = "account-bea"

    private func makeService(_ install: Install, provider: FertilityKitAccessProviding,
                             internalQAAllowed: Bool = true) -> FertilityKitAccessService {
        FertilityKitAccessService(store: install.store, provider: provider,
                                  accountIdentity: { install.identity },
                                  internalQAAllowed: internalQAAllowed, now: { install.now })
    }

    private func qaProvider(_ install: Install) -> InternalQAFertilityKitAccessProvider {
        InternalQAFertilityKitAccessProvider(store: install.store)
    }

    /// A verified record as a real provider would return one.
    private func grant(_ account: String, status: ProgrammeAccessStatus = .active,
                       source: ProgrammeAccessSource = .otherApproved, at date: Date? = nil,
                       reference: String = "grant-1") -> ProgrammeAccess {
        ProgrammeAccess(status: status, source: source, productID: "kit", accountID: account,
                        grantedAt: date ?? t0, externalReference: reference)
    }

    /// Every way a code is typed that must still be read as that code.
    private func spellings(of code: String) -> [String] {
        let mixed = String(code.enumerated().map { $0.offset.isMultiple(of: 2) ? Character($0.element.lowercased()) : $0.element })
        return [code, "  \(code)", "\(code)  ", "\t\(code)\t", "\n\(code)\n", " \t\(code) \r\n",
                code.lowercased(), mixed, "  \(mixed)\n"]
    }

    /// Lets the main actor run other tasks until the provider has a call waiting at the door.
    private func untilHolding(_ provider: ScriptedProvider, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<1_000 where !provider.isHolding { await Task.yield() }
        XCTAssertTrue(provider.isHolding, "the provider was never asked", file: file, line: line)
    }

    private enum Check: CaseIterable { case refresh, restore }

    private func run(_ check: Check, on service: FertilityKitAccessService) async -> FertilityKitVerificationResult {
        switch check {
        case .refresh: return await service.refresh()
        case .restore: return await service.restore()
        }
    }

    private func script(_ provider: ScriptedProvider, _ check: Check, _ access: ProgrammeAccess?) {
        switch check {
        case .refresh: provider.verified = access
        case .restore: provider.restored = access
        }
    }

    // MARK: - Activating with the internal QA codes

    func testEachQACodeActivatesThroughTheDevelopmentProvider() async throws {
        for code in qaCodes {
            let install = Install(identity: ada, now: t0)
            let service = makeService(install, provider: qaProvider(install))
            XCTAssertFalse(service.hasAccess)
            XCTAssertNil(service.source)

            let result = await service.redeem(code)
            XCTAssertEqual(result, .activated, code)
            XCTAssertTrue(service.hasAccess)
            XCTAssertEqual(service.source, .internalQA)
            XCTAssertFalse(service.isWorking)

            let cached = try XCTUnwrap(install.cache)
            XCTAssertEqual(cached.status, .active)
            XCTAssertEqual(cached.source, .internalQA)
            XCTAssertEqual(cached.grantedAt, t0, "the grant date is the injected now")
            XCTAssertEqual(cached.accountID, ada, "the grant is bound to who was signed in")
            XCTAssertEqual(cached.productID, "internal-qa-fertility-kit")
            XCTAssertNotNil(cached.externalReference)
            XCTAssertEqual(install.ledger, [ada: cached], "the phone caches exactly what the provider recorded")
        }
    }

    /// As the wiring will build it: the build's own provider and the build's own flag.
    func testThisBuildIsADevelopmentBuildSoItsOwnProviderActivates() async {
        let install = Install(identity: ada, now: t0)
        XCTAssertTrue(FertilityKitAccessProviders.internalQAAllowed)
        let provider = FertilityKitAccessProviders.current(store: install.store)
        XCTAssertTrue(provider is InternalQAFertilityKitAccessProvider)
        let service = FertilityKitAccessService(store: install.store, provider: provider,
                                                accountIdentity: { install.identity })
        let result = await service.redeem(qaCodes[2])
        XCTAssertEqual(result, .activated)
        XCTAssertTrue(service.hasAccess)
    }

    func testSpacesTabsNewlinesAndAnyCaseAllActivate() async {
        for code in qaCodes {
            for entry in spellings(of: code) {
                let install = Install(identity: ada, now: t0)
                let service = makeService(install, provider: qaProvider(install))
                let result = await service.redeem(entry)
                XCTAssertEqual(result, .activated, entry.debugDescription)
                XCTAssertTrue(service.hasAccess, entry.debugDescription)
            }
        }
    }

    func testAnEntryThatIsNotACodeIsNotRecognisedAndLeavesNothing() async {
        let install = Install(identity: ada, now: t0)
        let service = makeService(install, provider: qaProvider(install))
        for entry in ["GX90-QA-004", "GX90-QA-000", "GX90QA001", "GX90 QA 001", "GX90-QA-01", "fertility", "0"] {
            let result = await service.redeem(entry)
            XCTAssertEqual(result, .notRecognised, entry)
        }
        XCTAssertFalse(service.hasAccess)
        XCTAssertNil(service.source)
        XCTAssertNil(install.persisted[Self.cacheKey])
        XCTAssertTrue(install.ledger.isEmpty)
        XCTAssertTrue(install.persisted.isEmpty, "a rejected entry writes nothing at all")
    }

    func testABlankEntryNeverReachesTheProvider() async {
        let install = Install(identity: ada, now: t0)
        let provider = ScriptedProvider()
        provider.redeemAnswer = .granted(grant(ada))
        let service = makeService(install, provider: provider)
        for entry in ["", " ", "   ", "\n", "\t \r\n"] {
            let result = await service.redeem(entry)
            XCTAssertEqual(result, .empty, entry.debugDescription)
        }
        XCTAssertEqual(provider.redeemCalls, 0)
        XCTAssertFalse(service.hasAccess)
        XCTAssertTrue(install.persisted.isEmpty)
    }

    /// Once access is held the provider is not asked again, so a second code is never used up and
    /// the first grant keeps its date and reference.
    func testRedeemingAgainIsAlreadyActiveAndKeepsTheFirstGrant() async throws {
        let install = Install(identity: ada, now: t0)
        let provider = ScriptedProvider()
        provider.server = qaProvider(install)
        let service = makeService(install, provider: provider)
        let first = await service.redeem(qaCodes[0])
        XCTAssertEqual(first, .activated)
        let original = try XCTUnwrap(install.cache)
        XCTAssertEqual(provider.redeemCalls, 1)

        install.now = t0.addingTimeInterval(600)
        for entry in [qaCodes[0], qaCodes[2], "gx90-qa-002 ", "nonsense"] {
            let again = await service.redeem(entry)
            XCTAssertEqual(again, .alreadyActive, entry)
        }
        XCTAssertEqual(provider.redeemCalls, 1, "the provider is not asked while access is held")
        XCTAssertEqual(install.cache, original)
        XCTAssertEqual(install.cache?.grantedAt, t0)
        XCTAssertEqual(install.cache?.externalReference, original.externalReference)
        XCTAssertEqual(install.ledger, [ada: original])
    }

    /// The development provider itself keeps the first grant if it is asked twice.
    func testTheDevelopmentProviderKeepsTheFirstGrantWhenAskedAgain() async {
        let install = Install(identity: ada, now: t0)
        let qa = qaProvider(install)
        let first = await qa.redeem(qaCodes[0], accountID: ada, now: t0)
        let again = await qa.redeem(qaCodes[1], accountID: ada, now: t0.addingTimeInterval(600))
        XCTAssertEqual(again, first)
        guard case .granted(let access) = first else { return XCTFail("the first call must grant") }
        XCTAssertEqual(access.grantedAt, t0)
        XCTAssertEqual(install.ledger, [ada: access])
    }

    // MARK: - One call at a time

    func testADoubleTapAsksTheProviderOnce() async {
        let install = Install(identity: ada, now: t0)
        let provider = ScriptedProvider()
        provider.server = qaProvider(install)
        provider.holds = true
        let service = makeService(install, provider: provider)
        let code = qaCodes[0]

        let firstTap = Task { await service.redeem(code) }
        await untilHolding(provider)
        XCTAssertTrue(service.isWorking, "a call is waiting for the provider")
        XCTAssertFalse(service.hasAccess, "nothing is granted before the provider answers")
        XCTAssertNil(install.cache)

        let secondTap = await service.redeem(code)
        XCTAssertEqual(secondTap, .busy)
        let refreshWhileWaiting = await service.refresh()
        XCTAssertEqual(refreshWhileWaiting, .busy)
        let restoreWhileWaiting = await service.restore()
        XCTAssertEqual(restoreWhileWaiting, .busy)

        provider.release()
        let first = await firstTap.value
        XCTAssertEqual(first, .activated)
        XCTAssertEqual(provider.redeemCalls, 1)
        XCTAssertEqual(provider.verifyCalls + provider.restoreCalls, 0)
        XCTAssertFalse(service.isWorking)
        XCTAssertTrue(service.hasAccess)
    }

    func testOverlappingChecksAskTheProviderOnce() async {
        for check in Check.allCases {
            let install = Install(identity: ada, now: t0)
            let provider = ScriptedProvider()
            script(provider, check, grant(ada))
            provider.holds = true
            let service = makeService(install, provider: provider)

            let first = Task { await self.run(check, on: service) }
            await untilHolding(provider)
            XCTAssertTrue(service.isWorking)
            let second = await run(check, on: service)
            XCTAssertEqual(second, .busy)
            let redeemWhileWaiting = await service.redeem(qaCodes[0])
            XCTAssertEqual(redeemWhileWaiting, .busy)

            provider.release()
            let result = await first.value
            XCTAssertEqual(result, .verified(hasAccess: true))
            XCTAssertEqual(provider.verifyCalls + provider.restoreCalls, 1)
            XCTAssertEqual(provider.redeemCalls, 0)
            XCTAssertFalse(service.isWorking)
        }
    }

    // MARK: - Offline, and answers that are not a grant for this account

    func testAnUnreachableProviderGrantsNothingAndWritesNothing() async {
        let install = Install(identity: ada, now: t0)
        let provider = ScriptedProvider()   // answers `.unreachable`, and nil to every check
        let service = makeService(install, provider: provider)
        let result = await service.redeem(qaCodes[0])
        XCTAssertEqual(result, .couldNotReachProvider)
        XCTAssertEqual(provider.redeemCalls, 1)
        XCTAssertFalse(service.hasAccess)
        XCTAssertFalse(service.isWorking)
        XCTAssertTrue(install.persisted.isEmpty, "the store is untouched")

        for check in Check.allCases {
            let checked = await run(check, on: service)
            XCTAssertEqual(checked, .couldNotVerify(hasAccess: false))
        }
        XCTAssertTrue(install.persisted.isEmpty)
    }

    /// Offline grace: with no answer, access already held stays.
    func testACheckWithNoAnswerKeepsTheAccessAlreadyHeld() async throws {
        let install = Install(identity: ada, now: t0)
        let provider = ScriptedProvider()
        provider.server = qaProvider(install)
        let service = makeService(install, provider: provider)
        let activated = await service.redeem(qaCodes[0])
        XCTAssertEqual(activated, .activated)
        let original = try XCTUnwrap(install.cache)

        provider.server = nil   // the provider can no longer be reached
        for check in Check.allCases {
            let checked = await run(check, on: service)
            XCTAssertEqual(checked, .couldNotVerify(hasAccess: true))
            XCTAssertTrue(service.hasAccess)
            XCTAssertEqual(install.cache, original)
        }
    }

    func testAnAnswerThatIsNotAGrantForThisAccountStoresNothing() async {
        let answers: [FertilityKitProviderAnswer] = [
            .granted(grant(bea)),                               // someone else's
            .granted(grant(ada, status: .revoked)),             // not active
            .granted(.none),
            .granted(ProgrammeAccess(status: .active, source: .apple)),   // bound to nobody
            .granted(ProgrammeAccess(status: .active, accountID: ada)),   // from nowhere
            .rejected(.accepted(source: .internalQA)),          // a provider must never answer this
        ]
        for answer in answers {
            let install = Install(identity: ada, now: t0)
            let provider = ScriptedProvider()
            provider.redeemAnswer = answer
            let service = makeService(install, provider: provider)
            let result = await service.redeem(qaCodes[0])
            XCTAssertEqual(result, .couldNotReachProvider, "\(answer)")
            XCTAssertFalse(service.hasAccess)
            XCTAssertTrue(install.persisted.isEmpty)
        }
    }

    func testEachRejectionIsReportedAsItsOwnResult() async {
        let expected: [(ProgrammeActivationOutcome, FertilityKitActivationResult)] = [
            (.rejectedEmpty, .empty), (.rejectedUnknown, .notRecognised),
            (.rejectedNotAvailableInThisBuild, .notAvailableInThisBuild),
        ]
        for (outcome, result) in expected {
            let install = Install(identity: ada, now: t0)
            let provider = ScriptedProvider()
            provider.redeemAnswer = .rejected(outcome)
            let service = makeService(install, provider: provider)
            let got = await service.redeem("anything")
            XCTAssertEqual(got, result)
            XCTAssertTrue(install.persisted.isEmpty)
        }
    }

    // MARK: - App closed while the provider is being asked

    func testClosingTheAppBeforeTheProviderAnswersLeavesNothingBehind() async {
        let install = Install(identity: ada, now: t0)
        let silent = ScriptedProvider()
        silent.holds = true
        let abandoned = makeService(install, provider: silent)
        let code = qaCodes[0]
        let call = Task { await abandoned.redeem(code) }
        await untilHolding(silent)
        XCTAssertTrue(install.persisted.isEmpty, "nothing is written before the provider answers")

        // The next launch: a new service over the same store.
        let relaunched = makeService(install, provider: qaProvider(install))
        XCTAssertFalse(relaunched.hasAccess)
        XCTAssertFalse(relaunched.isWorking)
        XCTAssertNil(install.persisted[Self.cacheKey])
        let result = await relaunched.redeem(code)
        XCTAssertEqual(result, .activated)
        XCTAssertTrue(relaunched.hasAccess)

        // The process would have died. Here the abandoned call is let go so nothing stays suspended.
        silent.release()
        _ = await call.value
    }

    /// The provider recorded the grant but the answer never reached the phone.
    func testAGrantTheProviderRecordedButThePhoneNeverCachedComesBackOnRefresh() async throws {
        let install = Install(identity: ada, now: t0)
        let slow = ScriptedProvider()
        slow.server = qaProvider(install)
        slow.holds = true
        let abandoned = makeService(install, provider: slow)
        let code = qaCodes[1]
        let call = Task { await abandoned.redeem(code) }
        await untilHolding(slow)
        let recorded = try XCTUnwrap(install.ledger[ada], "the grant reached the provider")
        XCTAssertNil(install.persisted[Self.cacheKey], "and never reached the phone")

        install.now = t0.addingTimeInterval(86_400)
        let relaunched = makeService(install, provider: qaProvider(install))
        XCTAssertFalse(relaunched.hasAccess, "no access until the provider is asked")
        let refreshed = await relaunched.refresh()
        XCTAssertEqual(refreshed, .verified(hasAccess: true))
        XCTAssertTrue(relaunched.hasAccess)
        XCTAssertEqual(install.cache, recorded)
        XCTAssertEqual(install.cache?.grantedAt, t0, "the original grant date, not the day of the refresh")

        slow.release()
        _ = await call.value
    }

    func testRelaunchAfterSuccessHasAccessWithoutAskingTheProvider() async throws {
        let install = Install(identity: ada, now: t0)
        let activated = await makeService(install, provider: qaProvider(install)).redeem(qaCodes[0])
        XCTAssertEqual(activated, .activated)
        let original = try XCTUnwrap(install.cache)

        install.now = t0.addingTimeInterval(86_400)
        let spy = ScriptedProvider()
        let relaunched = makeService(install, provider: spy)
        XCTAssertTrue(relaunched.hasAccess)
        XCTAssertEqual(relaunched.source, .internalQA)
        XCTAssertEqual(install.cache, original)
        XCTAssertEqual(spy.redeemCalls + spy.verifyCalls + spy.restoreCalls, 0)
    }

    func testARecordThisBuildCannotReadLoadsAsNoAccess() {
        let install = Install(identity: ada, now: t0)
        // Active and hers, but from a source this build has never heard of.
        install.store.save(["status": "active", "accountID": ada, "source": "voucher"], forKey: "fertility_kit_access")
        XCTAssertNotNil(install.persisted[Self.cacheKey])
        let service = makeService(install, provider: ScriptedProvider())
        XCTAssertFalse(service.hasAccess)
        XCTAssertNil(service.source)
    }

    // MARK: - Sign-out, sign-in and another account

    func testSignOutForgetsTheCacheAndSignInGetsAccessBackOnlyFromTheProvider() async throws {
        let install = Install(identity: ada, now: t0)
        let service = makeService(install, provider: qaProvider(install))
        let activated = await service.redeem(qaCodes[0])
        XCTAssertEqual(activated, .activated)
        let original = try XCTUnwrap(install.cache)

        // Sign-out, as the container will do it.
        service.clearLocalState()
        install.identity = nil
        XCTAssertNil(install.persisted[Self.cacheKey])
        XCTAssertFalse(service.hasAccess)
        XCTAssertNil(service.source)
        let redeemed = await service.redeem(qaCodes[1])
        XCTAssertEqual(redeemed, .signedOut)
        for check in Check.allCases {
            let checked = await run(check, on: service)
            XCTAssertEqual(checked, .signedOut)
        }
        XCTAssertEqual(install.ledger, [ada: original], "the provider's record outlives sign-out")
        XCTAssertNil(install.persisted[Self.cacheKey])

        // The same account again: nothing until the provider is asked, then the original grant.
        install.now = t0.addingTimeInterval(86_400)
        install.identity = ada
        XCTAssertFalse(service.hasAccess)
        let refreshed = await service.refresh()
        XCTAssertEqual(refreshed, .verified(hasAccess: true))
        XCTAssertEqual(install.cache, original)
        XCTAssertEqual(service.source, .internalQA)

        // A different account: the provider's answer for her, which is none.
        service.clearLocalState()
        install.identity = bea
        XCTAssertFalse(service.hasAccess)
        let other = await service.refresh()
        XCTAssertEqual(other, .verified(hasAccess: false))
        XCTAssertFalse(service.hasAccess)
        XCTAssertNil(install.persisted[Self.cacheKey])
        let restored = await service.restore()
        XCTAssertEqual(restored, .verified(hasAccess: false))
    }

    /// Even if nothing cleared the cache, it counts only for the account it was granted to.
    func testAnotherAccountNeverReadsAccessLeftInTheCache() async {
        let install = Install(identity: ada, now: t0)
        let service = makeService(install, provider: qaProvider(install))
        let activated = await service.redeem(qaCodes[0])
        XCTAssertEqual(activated, .activated)

        install.identity = bea   // no clearLocalState()
        XCTAssertEqual(install.cache?.accountID, ada, "the record is still there")
        XCTAssertFalse(service.hasAccess)
        XCTAssertNil(service.source)
        install.identity = nil
        XCTAssertFalse(service.hasAccess)
        // A new service over the same store reads it the same way.
        install.identity = bea
        XCTAssertFalse(makeService(install, provider: ScriptedProvider()).hasAccess)
        install.identity = ada
        XCTAssertTrue(service.hasAccess)
    }

    func testUsableIsTheOneRuleForWhatTheCacheIsWorth() {
        let qa = grant(ada, source: .internalQA)
        let bought = grant(ada, source: .apple)
        func usable(_ cached: ProgrammeAccess, _ account: String?, _ allowed: Bool) -> ProgrammeAccess {
            FertilityKitAccessService.usable(cached, accountID: account, internalQAAllowed: allowed)
        }
        XCTAssertEqual(usable(qa, ada, true), qa)
        XCTAssertEqual(usable(qa, bea, true), .none)
        XCTAssertEqual(usable(qa, nil, true), .none)
        XCTAssertEqual(usable(qa, ada, false), .none, "a development grant is worth nothing where QA is not allowed")
        XCTAssertEqual(usable(bought, ada, false), bought)
        XCTAssertEqual(usable(bought, bea, false), .none)
        XCTAssertEqual(usable(.none, ada, true), .none)
        // A record bound to nobody belongs to nobody, signed in or not.
        let unbound = ProgrammeAccess(status: .active, source: .apple)
        XCTAssertEqual(usable(unbound, ada, true), .none)
        XCTAssertEqual(usable(unbound, nil, true), .none)
        // A grant that does not say where it came from cannot be verified, so access always has a source.
        XCTAssertEqual(usable(ProgrammeAccess(status: .active, accountID: ada), ada, true), .none)
    }

    func testSigningOutOrSwitchingAccountWhileRedeemingStoresNothing() async {
        for next in [nil, bea] as [String?] {
            let install = Install(identity: ada, now: t0)
            let provider = ScriptedProvider()
            provider.redeemAnswer = .granted(grant(ada))
            provider.holds = true
            let service = makeService(install, provider: provider)
            let code = qaCodes[0]
            let call = Task { await service.redeem(code) }
            await untilHolding(provider)
            install.identity = next
            provider.release()
            let result = await call.value
            XCTAssertEqual(result, .signedOut)
            XCTAssertFalse(service.isWorking)
            XCTAssertTrue(install.persisted.isEmpty)
            install.identity = ada
            XCTAssertFalse(service.hasAccess)
        }
    }

    // MARK: - Refresh and restore

    func testAVerifiedAnswerReplacesTheCacheWhateverItSays() async {
        for check in Check.allCases {
            let install = Install(identity: ada, now: t0)
            let provider = ScriptedProvider()
            let service = makeService(install, provider: provider)

            let bought = grant(ada, source: .apple, reference: "txn-1")
            script(provider, check, bought)
            let first = await run(check, on: service)
            XCTAssertEqual(first, .verified(hasAccess: true))
            XCTAssertEqual(install.cache, bought)
            XCTAssertEqual(service.source, .apple)

            let renewed = grant(ada, source: .apple, at: t0.addingTimeInterval(600), reference: "txn-2")
            script(provider, check, renewed)
            let second = await run(check, on: service)
            XCTAssertEqual(second, .verified(hasAccess: true))
            XCTAssertEqual(install.cache, renewed)

            let revoked = grant(ada, status: .revoked, source: .apple, reference: "txn-2")
            script(provider, check, revoked)
            let third = await run(check, on: service)
            XCTAssertEqual(third, .verified(hasAccess: false))
            XCTAssertFalse(service.hasAccess)
            XCTAssertNil(service.source, "no source without access")
            XCTAssertEqual(install.cache, revoked)

            script(provider, check, ProgrammeAccess.none)
            let fourth = await run(check, on: service)
            XCTAssertEqual(fourth, .verified(hasAccess: false))
            XCTAssertNil(install.persisted[Self.cacheKey], "no access is stored as the absence of the key")

            // Each check asked its own provider call, and only that one.
            XCTAssertEqual(provider.verifyCalls, check == .refresh ? 4 : 0)
            XCTAssertEqual(provider.restoreCalls, check == .restore ? 4 : 0)
        }
    }

    func testAnAnswerForAnotherAccountIsNoAnswer() async {
        for check in Check.allCases {
            let install = Install(identity: ada, now: t0)
            let provider = ScriptedProvider()
            let service = makeService(install, provider: provider)

            script(provider, check, grant(bea))
            let nothingHeld = await run(check, on: service)
            XCTAssertEqual(nothingHeld, .couldNotVerify(hasAccess: false))
            XCTAssertTrue(install.persisted.isEmpty)

            let own = grant(ada)
            script(provider, check, own)
            let verified = await run(check, on: service)
            XCTAssertEqual(verified, .verified(hasAccess: true))

            script(provider, check, grant(bea, reference: "grant-2"))
            let ignored = await run(check, on: service)
            XCTAssertEqual(ignored, .couldNotVerify(hasAccess: true))
            XCTAssertEqual(install.cache, own)

            // Nor is a refusal meant for someone else: it does not take this account's access away.
            script(provider, check, grant(bea, status: .revoked))
            let othersRefusal = await run(check, on: service)
            XCTAssertEqual(othersRefusal, .couldNotVerify(hasAccess: true))
            XCTAssertEqual(install.cache, own)

            // A refusal bound to nobody is still an answer about the account that was asked for.
            script(provider, check, ProgrammeAccess(status: .revoked))
            let refusal = await run(check, on: service)
            XCTAssertEqual(refusal, .verified(hasAccess: false))
            XCTAssertFalse(service.hasAccess)
        }
    }

    func testSigningOutOrSwitchingAccountDuringACheckStoresNothing() async {
        for check in Check.allCases {
            for next in [nil, bea] as [String?] {
                let install = Install(identity: ada, now: t0)
                let provider = ScriptedProvider()
                script(provider, check, grant(ada))
                provider.holds = true
                let service = makeService(install, provider: provider)
                let call = Task { await self.run(check, on: service) }
                await untilHolding(provider)
                install.identity = next
                provider.release()
                let result = await call.value
                XCTAssertEqual(result, .signedOut)
                XCTAssertFalse(service.isWorking)
                XCTAssertTrue(install.persisted.isEmpty)
            }
        }
    }

    // MARK: - Production behaviour

    func testTheProductionProviderTreatsAQACodeLikeAnyOtherText() async {
        let install = Install(identity: ada, now: t0)
        let provider = UnconfiguredFertilityKitAccessProvider()
        let service = makeService(install, provider: provider, internalQAAllowed: false)

        let unrelated = await service.redeem("ZZ11-AB-999")
        XCTAssertEqual(unrelated, .notAvailableInThisBuild)
        for code in qaCodes {
            for entry in spellings(of: code) {
                let result = await service.redeem(entry)
                XCTAssertEqual(result, unrelated, entry.debugDescription)
                let answer = await provider.redeem(entry, accountID: ada, now: t0)
                XCTAssertEqual(answer, .rejected(.rejectedNotAvailableInThisBuild), entry.debugDescription)
            }
        }
        let blank = await service.redeem(" \n")
        XCTAssertEqual(blank, .empty)

        XCTAssertFalse(service.hasAccess)
        XCTAssertNil(service.source)
        for check in Check.allCases {
            let checked = await run(check, on: service)
            XCTAssertEqual(checked, .couldNotVerify(hasAccess: false))
        }
        XCTAssertTrue(install.persisted.isEmpty, "the production provider stores nothing")
    }

    /// A Release build installed over a development build neither honours nor keeps its grant.
    func testAReleaseConfiguredServiceErasesACachedDevelopmentGrant() async {
        let install = Install(identity: ada, now: t0)
        let activated = await makeService(install, provider: qaProvider(install)).redeem(qaCodes[0])
        XCTAssertEqual(activated, .activated)
        XCTAssertEqual(install.cache?.source, .internalQA)

        let release = makeService(install, provider: UnconfiguredFertilityKitAccessProvider(), internalQAAllowed: false)
        XCTAssertFalse(release.hasAccess)
        XCTAssertNil(release.source)
        XCTAssertNil(install.persisted[Self.cacheKey], "the development grant is erased, not just ignored")
        let checked = await release.refresh()
        XCTAssertEqual(checked, .couldNotVerify(hasAccess: false))

        // Only a development grant is erased: a verified grant from a real source is kept.
        let bought = grant(ada, source: .apple)
        install.store.save(bought, forKey: "fertility_kit_access")
        let kept = makeService(install, provider: UnconfiguredFertilityKitAccessProvider(), internalQAAllowed: false)
        XCTAssertTrue(kept.hasAccess)
        XCTAssertEqual(kept.source, .apple)
        XCTAssertEqual(install.cache, bought)
    }

    /// Where internal QA is not allowed, a development grant handed over by a provider is not
    /// access and is not kept: activated always means access.
    func testAServiceThatDoesNotAllowInternalQANeverKeepsADevelopmentGrant() async {
        let install = Install(identity: ada, now: t0)
        let service = makeService(install, provider: qaProvider(install), internalQAAllowed: false)
        let result = await service.redeem(qaCodes[0])
        XCTAssertEqual(result, .couldNotReachProvider)
        XCTAssertEqual(install.ledger[ada]?.source, .internalQA, "the provider did hand over a development grant")
        XCTAssertFalse(service.hasAccess)
        XCTAssertNil(install.persisted[Self.cacheKey])

        for check in Check.allCases {
            let checked = await run(check, on: service)
            XCTAssertEqual(checked, .couldNotVerify(hasAccess: false))
            XCTAssertFalse(service.hasAccess)
            XCTAssertNil(install.persisted[Self.cacheKey])
        }
    }

    // MARK: - Nothing of a code is kept

    func testNothingOfACodeIsStoredDescribedOrHeld() async throws {
        let install = Install(identity: ada, now: t0)
        let qa = qaProvider(install)
        let service = makeService(install, provider: qa)
        let entries = ["GX90-QA-004", " gx90-qa-002 \n", "GX90-QA-001"]

        let rejected = await service.redeem(entries[0])
        XCTAssertEqual(rejected, .notRecognised)
        let first = await service.redeem(entries[1])
        XCTAssertEqual(first, .activated)
        install.identity = bea
        let second = await service.redeem(entries[2])
        XCTAssertEqual(second, .activated)

        // The only reference kept is the provider's own random grant id, new for every grant.
        let references = try [ada, bea].map { try XCTUnwrap(install.ledger[$0]?.externalReference) }
        XCTAssertNotEqual(references[0], references[1])
        for reference in references {
            XCTAssertTrue(reference.hasPrefix("qa-"))
            XCTAssertNotNil(UUID(uuidString: String(reference.dropFirst(3))), "a random id, not something made from the code")
        }

        var described = [install.persistedText, String(describing: service), String(reflecting: service)]
        dump(service, to: &described[1])
        let answers: [FertilityKitProviderAnswer] = [
            await qa.redeem(entries[0], accountID: ada, now: t0), await qa.redeem(entries[1], accountID: ada, now: t0),
            await qa.redeem("", accountID: ada, now: t0), .unreachable,
        ]
        let checks: [FertilityKitVerificationResult] = [
            .verified(hasAccess: true), .verified(hasAccess: false),
            .couldNotVerify(hasAccess: true), .couldNotVerify(hasAccess: false), .signedOut, .busy,
        ]
        let values = FertilityKitActivationResult.allCases.map { $0 as Any } + checks.map { $0 as Any }
            + answers.map { $0 as Any }
        for value in values {
            var dumped = ""
            dump(value, to: &dumped)
            described += [String(describing: value), String(reflecting: value), dumped]
        }

        XCTAssertTrue(described[0].contains(Self.cacheKey) && described[0].contains(Self.ledgerKey),
                      "the store was read: a search that finds nothing proves nothing")
        XCTAssertTrue(described[1].contains("internal-qa-fertility-kit"), "the dump reached the cached record")
        for text in described {
            // The grant ids are random, so they are taken out before looking for anything code-shaped.
            let upper = references.reduce(text) { $0.replacingOccurrences(of: $1, with: "") }.uppercased()
            XCTAssertFalse(upper.contains("GX90"), text)
            XCTAssertFalse(upper.contains("QA-00"), text)
            for entry in entries {
                XCTAssertFalse(upper.contains(ProgrammeActivationCode.normalise(entry)), text)
            }
        }
    }

    /// Access and progress are separate: activating writes the access cache and the development
    /// ledger, and nothing about the programme.
    func testActivatingDoesNotStartTheProgramme() async {
        let install = Install(identity: ada, now: t0)
        let result = await makeService(install, provider: qaProvider(install)).redeem(qaCodes[0])
        XCTAssertEqual(result, .activated)
        XCTAssertEqual(Set(install.persisted.keys), [Self.cacheKey, Self.ledgerKey])
        for key in install.persisted.keys {
            XCTAssertFalse(key.lowercased().contains("programme"), key)
        }
        XCTAssertFalse(install.persistedText.lowercased().contains("started"))
    }

    // MARK: - QA reset

    func testQAResetLetsTheSameCodeActivateAgain() async throws {
        let install = Install(identity: ada, now: t0)
        let qa = qaProvider(install)
        let service = makeService(install, provider: qa)
        _ = await qa.redeem(qaCodes[2], accountID: bea, now: t0)   // someone else's grant, to be left alone
        let beas = try XCTUnwrap(install.ledger[bea])
        let first = await service.redeem(qaCodes[0])
        XCTAssertEqual(first, .activated)
        let original = try XCTUnwrap(install.cache)

        service.resetForQA()
        XCTAssertFalse(service.hasAccess)
        XCTAssertNil(install.persisted[Self.cacheKey])
        XCTAssertEqual(install.ledger, [bea: beas], "only this account's grant is forgotten")
        let checked = await service.refresh()
        XCTAssertEqual(checked, .verified(hasAccess: false))

        install.now = t0.addingTimeInterval(3_600)
        let again = await service.redeem(qaCodes[0])
        XCTAssertEqual(again, .activated)
        let renewed = try XCTUnwrap(install.cache)
        XCTAssertEqual(renewed.grantedAt, t0.addingTimeInterval(3_600), "a new grant, with a new date")
        XCTAssertNotEqual(renewed.externalReference, original.externalReference)

        // Signed out there is nobody to forget: the cache goes, the provider's record stays.
        install.identity = nil
        service.resetForQA()
        XCTAssertFalse(service.hasAccess)
        XCTAssertNil(install.persisted[Self.cacheKey])
        XCTAssertEqual(install.ledger, [ada: renewed, bea: beas])
        install.identity = ada
        let back = await service.refresh()
        XCTAssertEqual(back, .verified(hasAccess: true))
    }

    // MARK: - The build gate, read from the source

    private static let providersPath = "App/Genesyx/Services/FertilityKit/FertilityKitAccessProviders.swift"
    private static let servicePath = "App/Genesyx/Services/FertilityKit/FertilityKitAccessService.swift"

    /// `#if !DEBUG` cannot be run by a test, so the Release branch is read instead.
    func testTheBuildDecidesTheProviderAndTheFlagInOnePlace() throws {
        let providers = Self.collapsed(try Self.source(Self.providersPath))
        XCTAssertTrue(
            providers.contains("#if DEBUG static let internalQAAllowed = true #else static let internalQAAllowed = false #endif"),
            "Outside DEBUG internal QA must not be allowed")
        XCTAssertTrue(
            providers.contains("""
                #if DEBUG return InternalQAFertilityKitAccessProvider(store: store) \
                #else return UnconfiguredFertilityKitAccessProvider() #endif
                """),
            "Outside DEBUG the provider must be the one that grants nothing")
        XCTAssertEqual(Self.count("static let internalQAAllowed", in: providers), 2,
                       "`internalQAAllowed` is defined once, in its `#if DEBUG` / `#else` pair")

        // The flag reaches the service through one wire: the default of its initialiser.
        let service = Self.collapsed(try Self.source(Self.servicePath))
        XCTAssertTrue(service.contains("internalQAAllowed: Bool = FertilityKitAccessProviders.internalQAAllowed,"),
                      "the service takes the build's own flag unless a test passes one")
        XCTAssertEqual(Self.count("FertilityKitAccessProviders.internalQAAllowed", in: service), 1)
        XCTAssertEqual(Self.count("internalQAAllowed: Bool =", in: service), 1, "and it has no other default")
    }

    func testDevelopmentOnlyNamesStayInsideDebugRegions() throws {
        let files = try Self.appSources()
        XCTAssertGreaterThan(files.count, 60, "Source scan found almost nothing: the path is wrong, not the code")

        let developmentOnly = ["InternalQAFertilityKitAccessProvider", "internalQAAllowed: true", "internalQAAllowed = true"]
        // Written nowhere today: a default of `true` would allow internal QA in every build.
        let names = developmentOnly + ["internalQAAllowed: Bool = true"]
        var offenders: [String] = []
        var seenInDebug: Set<String> = []
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (number, line, inDebug) in Self.annotated(source) {
                for name in names where line.contains(name) {
                    if inDebug { seenInDebug.insert(name) } else { offenders.append("\(file.lastPathComponent):\(number)  \(line)") }
                }
            }
        }
        XCTAssertEqual(seenInDebug, Set(developmentOnly), "a search that finds nothing proves nothing")
        XCTAssertTrue(offenders.isEmpty, """
            The development provider or its flag is named outside `#if DEBUG`, so it would compile into Release:
            \(offenders.joined(separator: "\n"))
            """)
    }

    /// No console output, no code text, no pregnancy test code, and nothing of programme progress.
    func testTheAccessFilesNameNothingTheyMustNot() throws {
        let forbidden = ["print(", "NSLog", "os_log", "Logger(", "debugPrint", "dump(", "GX90", "hcg", "Hcg",
                         "ProgrammeState", "startedOn", "ProgrammeRepository", "programme_progress"]
        for path in [Self.providersPath, Self.servicePath] {
            let text = try Self.source(path)
            XCTAssertTrue(text.contains("FertilityKitAccess"), "\(path) was not read")
            for term in forbidden {
                XCTAssertFalse(text.contains(term), "\(path) names \(term)")
            }
        }
    }

    // MARK: - Helpers (copied from `ScanReleaseGateTests`, which keeps its own private)

    /// `#filePath` is this file's location at compile time, App/GenesyxTests, so three components
    /// up is the repo root.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // GenesyxTests
            .deletingLastPathComponent()   // App
            .deletingLastPathComponent()   // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private static func appSources() throws -> [URL] {
        let root = repoRoot.appendingPathComponent("App/Genesyx")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw XCTSkip("Source tree not readable at \(root.path)")
        }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// Every line that is not a comment, numbered from 1, with whether it sits inside `#if DEBUG`.
    private static func annotated(_ source: String) -> [(number: Int, line: String, inDebug: Bool)] {
        var frames: [Bool] = []
        var result: [(number: Int, line: String, inDebug: Bool)] = []
        for (offset, raw) in source.components(separatedBy: .newlines).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#if") {
                frames.append(line == "#if DEBUG")
            } else if line.hasPrefix("#else") {   // also `#elseif`
                if !frames.isEmpty { frames[frames.count - 1] = false }
            } else if line.hasPrefix("#endif") {
                if !frames.isEmpty { frames.removeLast() }
            } else if !line.hasPrefix("//") {
                result.append((number: offset + 1, line: line, inDebug: frames.contains(true)))
            }
        }
        return result
    }

    private static func collapsed(_ source: String) -> String {
        source.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func count(_ needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }
}

/// One install of the app: its own defaults suite, who is signed in, and the clock.
private final class Install {
    let suite = "test.\(UUID().uuidString)"
    let store: LocalStore
    var identity: String?
    var now: Date

    init(identity: String?, now: Date) {
        self.identity = identity
        self.now = now
        store = LocalStore(defaults: UserDefaults(suiteName: suite)!)
    }

    /// The cached access record, as the service saved it.
    var cache: ProgrammeAccess? { store.load(ProgrammeAccess.self, forKey: "fertility_kit_access") }

    /// The development provider's ledger of grants.
    var ledger: [String: ProgrammeAccess] {
        store.load([String: ProgrammeAccess].self, forKey: "fertility_kit_qa_grants") ?? [:]
    }

    /// Everything this install has written, read back from the defaults domain itself.
    var persisted: [String: Any] { UserDefaults.standard.persistentDomain(forName: suite) ?? [:] }

    /// Every stored key and value as text (stored JSON read as UTF-8).
    var persistedText: String {
        persisted.map { key, value in
            key + " = " + ((value as? Data).map { String(decoding: $0, as: UTF8.self) } ?? String(describing: value))
        }.joined(separator: "\n")
    }
}

/// A provider the test scripts and counts, and can hold at the door until `release()`.
@MainActor
private final class ScriptedProvider: FertilityKitAccessProviding {
    var redeemAnswer: FertilityKitProviderAnswer = .unreachable
    var verified: ProgrammeAccess?
    var restored: ProgrammeAccess?
    /// When set, every call is passed on to it first: what really happened at the provider.
    var server: FertilityKitAccessProviding?
    /// When true a call does not return until `release()`.
    var holds = false
    private(set) var redeemCalls = 0
    private(set) var verifyCalls = 0
    private(set) var restoreCalls = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    var isHolding: Bool { !waiting.isEmpty }

    func release() {
        let held = waiting
        waiting = []
        held.forEach { $0.resume() }
    }

    private func door() async {
        guard holds else { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    func redeem(_ entry: String, accountID: String, now: Date) async -> FertilityKitProviderAnswer {
        redeemCalls += 1
        let served = await server?.redeem(entry, accountID: accountID, now: now)
        await door()
        return served ?? redeemAnswer
    }

    func verifiedAccess(accountID: String) async -> ProgrammeAccess? {
        verifyCalls += 1
        let served = await server?.verifiedAccess(accountID: accountID)
        await door()
        return served ?? verified
    }

    func restoredAccess(accountID: String) async -> ProgrammeAccess? {
        restoreCalls += 1
        let served = await server?.restoredAccess(accountID: accountID)
        await door()
        return served ?? restored
    }
}
