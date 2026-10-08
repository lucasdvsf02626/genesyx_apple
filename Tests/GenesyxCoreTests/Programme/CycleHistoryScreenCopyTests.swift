import XCTest
@testable import GenesyxCore

/// The words of the cycle history screen and its period sheet.
final class CycleHistoryScreenCopyTests: XCTestCase {

    func testTheRegistryPassesTheGuard() {
        XCTAssertGreaterThanOrEqual(CycleHistoryScreenCopy.allSurfaces.count, 45, "the registry must not shrink")
        XCTAssertEqual(FertilityKitCopyGuard.violations(in: CycleHistoryScreenCopy.allSurfaces), [])
    }

    func testEveryStringInTheRegistryFileIsRegistered() throws {
        XCTAssertEqual(try FertilityKitCopyGuard.unregisteredLiterals(
            inFile: "CycleHistoryScreenCopy.swift", surfaces: CycleHistoryScreenCopy.allSurfaces), [])
    }

    func testTheFrozenLabelsAreExact() {
        // The journeys find these by their text: a menu item and an alert carry no identifier.
        XCTAssertEqual(CycleHistoryScreenCopy.setEnd, "Set period end")
        XCTAssertEqual(CycleHistoryScreenCopy.changeEnd, "Change period end")
        XCTAssertEqual(CycleHistoryScreenCopy.correctStart, "Correct start date")
        XCTAssertEqual(CycleHistoryScreenCopy.deletePeriod, "Delete this period")
        XCTAssertEqual(CycleHistoryScreenCopy.deleteTitle, "Delete this period?")
        XCTAssertEqual(FertilityKitCopy.delete, "Delete")
        XCTAssertEqual(FertilityKitCopy.cancel, "Cancel")
    }

    func testTheOtherBriefStringsArePresent() {
        XCTAssertEqual(CycleHistoryScreenCopy.addStart, "Add a period start")
        XCTAssertEqual(CycleHistoryScreenCopy.currentCycle, "Current cycle")
        XCTAssertEqual(CycleHistoryScreenCopy.started("6 October"), "Started 6 October")
        XCTAssertEqual(CycleHistoryScreenCopy.length(29), "29 days")
        XCTAssertEqual(CycleHistoryScreenCopy.periodDays(5), "Period: 5 days")
        XCTAssertEqual(CycleHistoryScreenCopy.periodDays(1), "Period: 1 day")
        XCTAssertEqual(CycleHistoryScreenCopy.fromSettings, "From your cycle settings")
        XCTAssertEqual(CycleHistoryScreenCopy.rowActions, "Period actions")
        XCTAssertEqual(CycleHistoryScreenCopy.predictionsNote, "Predictions use your latest period start.")
        XCTAssertEqual(CycleHistoryScreenCopy.endCleared, "Period end cleared.")
        XCTAssertEqual(CycleHistoryScreenCopy.deleteBody, "This removes the record from your history.")
        XCTAssertEqual(CycleHistoryScreenCopy.deleteLatestBody,
                       "This is your latest period start. Your cycle predictions will use the start before it.")
        XCTAssertEqual(CycleHistoryScreenCopy.correctionNote("28 September"),
                       "This date is within 10 days of the start on 28 September, so that start will move to this date.")
        XCTAssertEqual(CycleHistoryScreenCopy.correctRange(CycleHistoryRules.correctionWindowDays),
                       "You can move this start by up to 10 days. To move it further, delete it and add a new one.")
        XCTAssertEqual(CycleHistoryScreenCopy.emptyState, CycleHistoryScreenCopy.intro,
                       "the empty state says plainly that history starts from her first record")
        XCTAssertTrue(CycleHistoryScreenCopy.emptyState.contains("Nothing is filled in from before"))
    }

    func testEveryOutcomeHasASentence() {
        let a = CalendarDate(2026, 9, 28), b = CalendarDate(2026, 10, 6)
        let starts: [PeriodStartOutcome] = [.append(b), .backFill(a), .correction(from: a, to: b), .noChange, .refused]
        XCTAssertEqual(starts.map(CycleHistoryScreenCopy.sentence(for:)), [
            "Period start added.", "Earlier period start added.", "Start date moved from 28 September to 6 October.",
            "That start date is already recorded.", "That date cannot be recorded as a period start."])
        let ends: [PeriodEndOutcome] = [.updated, .noChange, .refusedUnknownStart, .refusedBeforeStart, .refusedTooLong,
                                        .refusedReachesNextStart, .refusedFuture]
        XCTAssertEqual(ends.map(CycleHistoryScreenCopy.sentence(for:)), [
            "Period end saved.", "Nothing changed.", "That period could not be found.",
            "The end date cannot be before the start date.", "A period can be recorded for up to 10 days.",
            "The end date cannot reach the period start recorded after it.", "The end date cannot be in the future."])
        XCTAssertEqual(Set(starts.map(CycleHistoryScreenCopy.sentence(for:))).count, starts.count)
        XCTAssertEqual(Set(ends.map(CycleHistoryScreenCopy.sentence(for:))).count, ends.count)
    }

    func testTheNumberOfDaysComesFromTheRulesNeverTyped() {
        XCTAssertEqual(CycleHistoryRules.correctionWindowDays, CycleEngine.periodLengthRange.upperBound)
        XCTAssertTrue(CycleHistoryScreenCopy.sentence(for: PeriodEndOutcome.refusedTooLong)
            .contains("\(CycleEngine.periodLengthRange.upperBound)"))
        XCTAssertTrue(CycleHistoryScreenCopy.correctionNote("1 May").contains("\(CycleHistoryRules.correctionWindowDays)"))
    }

    /// The history states facts about what she recorded: no verdict on a length, nothing about a
    /// period that is expected or late, and nothing about fertility or ovulation.
    func testTheRegistryNeverJudgesOrPredicts() {
        let terms = FertilityKitCopyGuard.Terms(
            anywhere: ["ovulat", "fertil"],
            wholeWords: ["regular", "irregular", "normal", "short", "long", "late", "expected", "overdue"])
        for surface in CycleHistoryScreenCopy.allSurfaces {
            XCTAssertEqual(FertilityKitCopyGuard.hits(terms, in: surface), [], surface)
        }
    }

    func testTheGuardWouldCatchAJudgement() {
        let terms = FertilityKitCopyGuard.Terms(anywhere: ["ovulat", "fertil"], wholeWords: ["normal", "late", "long"])
        XCTAssertEqual(FertilityKitCopyGuard.hits(terms, in: "A normal cycle, late again, ovulation soon"),
                       ["ovulat", "normal", "late"])
        XCTAssertEqual(FertilityKitCopyGuard.hits(terms, in: "Your latest period start, a longer record"), [])
    }
}
