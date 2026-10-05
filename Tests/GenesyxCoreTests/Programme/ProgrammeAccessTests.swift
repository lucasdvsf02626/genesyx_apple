import XCTest
@testable import GenesyxCore

/// Programme Access: the model, the activation-code rules and the decisions an access service asks.
final class ProgrammeAccessTests: XCTestCase {

    private let qaCodes = ["GX90-QA-001", "GX90-QA-002", "GX90-QA-003"]
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    func testOnlyActiveIsAccess() {
        XCTAssertFalse(ProgrammeAccess.none.hasProgrammeAccess)
        XCTAssertTrue(ProgrammeAccess(status: .active, source: .apple).hasProgrammeAccess)
        XCTAssertFalse(ProgrammeAccess(status: .revoked, source: .apple).hasProgrammeAccess)
        XCTAssertEqual(ProgrammeAccessStatus.allCases.map(\.rawValue), ["none", "active", "revoked"])
        XCTAssertEqual(ProgrammeAccessSource.allCases.map(\.rawValue),
                       ["apple", "googlePlay", "internalQA", "admin", "otherApproved"])
    }

    func testEachQACodeIsAcceptedOnlyWhenInternalQAIsAllowed() {
        for code in qaCodes {
            XCTAssertEqual(ProgrammeActivationCode.validate(code, internalQAAllowed: true),
                           .accepted(source: .internalQA))
            XCTAssertEqual(ProgrammeActivationCode.validate(code.lowercased(), internalQAAllowed: true),
                           .accepted(source: .internalQA))
            XCTAssertEqual(ProgrammeActivationCode.validate("  \(code) \n", internalQAAllowed: true),
                           .accepted(source: .internalQA))
            XCTAssertEqual(ProgrammeActivationCode.validate("\t" + code.lowercased() + "  ", internalQAAllowed: true),
                           .accepted(source: .internalQA))
        }
    }

    /// With the flag off, an internal code gets the answer any other text gets: nothing in the
    /// outcome tells them apart.
    func testWithoutTheFlagAQACodeIsRejectedExactlyLikeAnUnknownCode() {
        let unknown = ProgrammeActivationCode.validate("ZZ11-AB-999", internalQAAllowed: false)
        XCTAssertEqual(unknown, .rejectedNotAvailableInThisBuild)
        for code in qaCodes {
            for entry in [code, code.lowercased(), " \(code) "] {
                let outcome = ProgrammeActivationCode.validate(entry, internalQAAllowed: false)
                XCTAssertEqual(outcome, unknown)
                XCTAssertNotEqual(outcome, .accepted(source: .internalQA))
            }
        }
    }

    func testEmptyAndWhitespaceOnlyAreRejectedAsEmpty() {
        for entry in ["", " ", "   ", "\n", "\t \n"] {
            XCTAssertEqual(ProgrammeActivationCode.validate(entry, internalQAAllowed: true), .rejectedEmpty)
            XCTAssertEqual(ProgrammeActivationCode.validate(entry, internalQAAllowed: false), .rejectedEmpty)
        }
    }

    func testNearMissesAndMalformedEntriesAreUnknown() {
        for entry in ["GX90-QA-004", "GX90-QA-000", "GX90QA001", "GX90 QA 001", "GX90-QA-01", "GX90-QA-0011",
                      "GX90-QA-001x", "GX9O-QA-001", "QA-001", "hello", "GX90-QA-001 GX90-QA-002"] {
            XCTAssertEqual(ProgrammeActivationCode.validate(entry, internalQAAllowed: true), .rejectedUnknown, entry)
        }
    }

    func testNormaliseTrimsAndUpperCasesAndNothingElse() {
        XCTAssertEqual(ProgrammeActivationCode.normalise("  ab-12 \n"), "AB-12")
        XCTAssertEqual(ProgrammeActivationCode.normalise("ab 12"), "AB 12")
        XCTAssertEqual(ProgrammeActivationCode.normalise("   "), "")
    }

    /// Nothing that can be printed, logged or shown carries any part of a code.
    func testNoOutcomeOrAccessDescriptionCarriesCodeText() {
        var described: [String] = []
        for flag in [true, false] {
            for entry in qaCodes + ["GX90-QA-004", "", "nonsense"] {
                let outcome = ProgrammeActivationCode.validate(entry, internalQAAllowed: flag)
                let redemption = ProgrammeAccessDecisions.redeem(entry, current: .none, internalQAAllowed: flag,
                                                                 accountID: "account", now: now)
                described += [String(describing: outcome), String(reflecting: outcome),
                              String(describing: redemption), String(reflecting: redemption),
                              String(describing: redemption.access), String(reflecting: redemption.access)]
                var dumped = ""
                dump(redemption, to: &dumped)
                described.append(dumped)
            }
        }
        described.append(String(describing: ProgrammeActivationCode.self))
        described.append(String(reflecting: ProgrammeActivationCode.self))
        for text in described {
            let upper = text.uppercased()
            XCTAssertFalse(upper.contains("GX90"), text)
            XCTAssertFalse(upper.contains("QA-00"), text)
            XCTAssertFalse(upper.contains("NONSENSE"), text)
        }
    }

    // ── Decisions ──

    func testRedeemGrantsInternalQAAccess() {
        let redemption = ProgrammeAccessDecisions.redeem(" gx90-qa-002 ", current: .none, internalQAAllowed: true,
                                                         productID: "kit", accountID: "account", now: now)
        XCTAssertEqual(redemption.outcome, .accepted(source: .internalQA))
        XCTAssertTrue(redemption.access.hasProgrammeAccess)
        XCTAssertEqual(redemption.access.source, .internalQA)
        XCTAssertEqual(redemption.access.productID, "kit")
        XCTAssertEqual(redemption.access.accountID, "account")
        XCTAssertEqual(redemption.access.grantedAt, now)
        XCTAssertNil(redemption.access.externalReference)
    }

    func testARejectedRedemptionLeavesAccessUntouched() {
        let held = ProgrammeAccess(status: .revoked, source: .admin, grantedAt: now)
        for (entry, flag) in [("GX90-QA-004", true), ("", true), ("GX90-QA-001", false)] {
            XCTAssertEqual(ProgrammeAccessDecisions.redeem(entry, current: held, internalQAAllowed: flag, now: now).access, held)
            XCTAssertEqual(ProgrammeAccessDecisions.redeem(entry, current: .none, internalQAAllowed: flag, now: now).access, .none)
        }
    }

    /// A second tap, or a second code, on an account that already holds access keeps the first grant.
    func testRedeemingAgainKeepsTheOriginalGrant() {
        let first = ProgrammeAccessDecisions.redeem("GX90-QA-001", current: .none, internalQAAllowed: true, now: now)
        let again = ProgrammeAccessDecisions.redeem("GX90-QA-003", current: first.access, internalQAAllowed: true,
                                                    now: now.addingTimeInterval(600))
        XCTAssertEqual(again.outcome, .accepted(source: .internalQA))
        XCTAssertEqual(again.access, first.access)
    }

    func testRefreshAndRestoreTakeTheVerifiedAnswerAndKeepTheCacheWithoutOne() {
        let cached = ProgrammeAccess(status: .active, source: .apple, grantedAt: now)
        let revoked = ProgrammeAccess(status: .revoked, source: .apple)
        XCTAssertEqual(ProgrammeAccessDecisions.resolve(cached: cached, verified: nil), cached)
        XCTAssertEqual(ProgrammeAccessDecisions.resolve(cached: cached, verified: revoked), revoked)
        XCTAssertEqual(ProgrammeAccessDecisions.resolve(cached: .none, verified: cached), cached)
    }

    func testResetReturnsNoneOnlyWhenInternalQAIsAllowed() {
        let granted = ProgrammeAccessDecisions.redeem("GX90-QA-001", current: .none, internalQAAllowed: true, now: now).access
        XCTAssertEqual(ProgrammeAccessDecisions.reset(granted, internalQAAllowed: true), .none)
        XCTAssertEqual(ProgrammeAccessDecisions.reset(granted, internalQAAllowed: false), granted)
        // After a reset the same code works again.
        let again = ProgrammeAccessDecisions.redeem("GX90-QA-001", current: .none, internalQAAllowed: true, now: now)
        XCTAssertTrue(again.access.hasProgrammeAccess)
    }

    /// Access and progress are separate: being granted access is not day 1.
    func testActivatingAccessDoesNotStartTheProgramme() {
        let state = ProgrammeState.notStarted
        let access = ProgrammeAccessDecisions.redeem("GX90-QA-001", current: .none, internalQAAllowed: true, now: now).access
        XCTAssertTrue(access.hasProgrammeAccess)
        XCTAssertEqual(state, .notStarted)
        XCTAssertNil(state.startedOn)
        XCTAssertEqual(ProgrammeCalendar.position(state, on: CalendarDate.today(now: now)), .notStarted)
        // The access model has nowhere to hold a start date, so no grant could ever carry one.
        let labels = Mirror(reflecting: access).children.compactMap(\.label)
        XCTAssertEqual(labels, ["status", "source", "productID", "accountID", "grantedAt", "externalReference"])
    }
}
