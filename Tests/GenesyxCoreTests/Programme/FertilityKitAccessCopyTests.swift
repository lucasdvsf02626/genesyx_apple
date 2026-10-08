import XCTest
@testable import GenesyxCore

/// The wording of activating, restoring and starting the programme.
final class FertilityKitAccessCopyTests: XCTestCase {

    func testTheRegistryPassesTheGuard() {
        XCTAssertGreaterThanOrEqual(FertilityKitAccessCopy.allSurfaces.count, 30, "the registry must not shrink")
        XCTAssertEqual(FertilityKitCopyGuard.violations(in: FertilityKitAccessCopy.allSurfaces), [])
    }

    func testEveryStringInTheRegistryFileIsRegistered() throws {
        XCTAssertEqual(try FertilityKitCopyGuard.unregisteredLiterals(
            inFile: "FertilityKitAccessCopy.swift", surfaces: FertilityKitAccessCopy.allSurfaces), [])
    }

    func testTheExactStringsArePresent() {
        XCTAssertEqual(FertilityKitAccessCopy.stopped, "Your 90-Day Programme is not running.",
                       "no journey reaches the stopped state: the line is pinned here")
        XCTAssertEqual(FertilityKitAccessCopy.activateAction, "Activate")
        XCTAssertEqual(FertilityKitAccessCopy.restore, "Restore access")
        XCTAssertEqual(FertilityKitAccessCopy.commit, "Start My Programme")
        XCTAssertEqual(FertilityKitAccessCopy.finalNote, "Once you confirm, the start date cannot be changed.")
        XCTAssertEqual(FertilityKitAccessCopy.startsTomorrow, "Starts tomorrow")
        XCTAssertEqual(FertilityKitAccessCopy.startsInDays(3), "Starts in 3 days")
        XCTAssertEqual(FertilityKitAccessCopy.startOn("12 October"), "Start on 12 October")
        XCTAssertEqual(FertilityKitAccessCopy.reviewLater("12 October"), "Your programme will start on 12 October.")
        XCTAssertEqual(FertilityKitAccessCopy.alreadyStarted("12 October"),
                       "Your programme already has a start date: 12 October.")
        XCTAssertEqual(FertilityKitAccessCopy.startsOn("12 October"), "Your programme starts on 12 October")
    }

    func testEveryActivationOutcomeHasALine() {
        XCTAssertEqual(FertilityKitAccessCopy.Activation.allCases.count, 7)
        for outcome in FertilityKitAccessCopy.Activation.allCases {
            XCTAssertFalse(FertilityKitAccessCopy.message(for: outcome).isEmpty, "\(outcome)")
        }
        let lines = FertilityKitAccessCopy.Activation.allCases.map(FertilityKitAccessCopy.message(for:))
        XCTAssertEqual(Set(lines).count, lines.count, "two outcomes must not share a line")
    }

    func testEveryRestoreOutcomeHasADistinctLine() {
        let lines = [true, false].flatMap { verified in
            [true, false].map { FertilityKitAccessCopy.restoreMessage(verified: verified, hasAccess: $0) }
        } + [FertilityKitAccessCopy.restoreSignedOut]
        XCTAssertEqual(lines.count, 5)
        XCTAssertEqual(Set(lines).count, 5)
        XCTAssertTrue(lines.allSatisfy { !$0.isEmpty })
    }

    func testTheThreeStartOutcomesHaveALine() {
        XCTAssertFalse(FertilityKitAccessCopy.alreadyStarted("1 January").isEmpty)
        XCTAssertFalse(FertilityKitAccessCopy.refusedNoAccess.isEmpty)
        XCTAssertFalse(FertilityKitAccessCopy.refusedNoConsent.isEmpty)
    }

    func testNoLineHintsAtACodeOrItsShape() {
        let digitRun = try! NSRegularExpression(pattern: "[0-9]{3,}")
        for surface in FertilityKitAccessCopy.allSurfaces {
            XCTAssertNil(digitRun.firstMatch(in: surface, range: NSRange(surface.startIndex..., in: surface)),
                         "a run of digits in: \(surface)")
            XCTAssertFalse(surface.lowercased().contains("internal"), surface)
            XCTAssertFalse(surface.lowercased().contains("test code"), surface)
        }
    }

    func testActivatingIsNotStarting() {
        // Activation says the programme starts only when she chooses.
        XCTAssertTrue(FertilityKitAccessCopy.activationBody.contains("starts only when you choose"))
        XCTAssertTrue(FertilityKitAccessCopy.message(for: .activated).contains("whenever you are ready"))
    }
}
