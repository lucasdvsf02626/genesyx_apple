import XCTest
import GenesyxCore
@testable import Genesyx

/// The account area, activation and starting the programme: what the views decide, as plain
/// functions, and what the real container does with it.
@MainActor
final class FertilityKitAccessFlowTests: XCTestCase {

    private let today = CalendarDate(2026, 10, 6)

    // MARK: - Messages

    func testEveryActivationResultButBusyHasALineAndBusyHasNone() {
        for result in FertilityKitActivationResult.allCases where result != .busy {
            let line = FertilityKitAccessPresentation.activationMessage(for: result)
            XCTAssertNotNil(line, "\(result)")
            XCTAssertFalse(line?.isEmpty ?? true, "\(result)")
        }
        XCTAssertNil(FertilityKitAccessPresentation.activationMessage(for: .busy))
        XCTAssertEqual(FertilityKitActivationResult.allCases.count, FertilityKitAccessCopy.Activation.allCases.count + 1,
                       "every result but busy has its own copy case")
    }

    func testOnlyActivatedAndAlreadyActiveAreSuccesses() {
        for result in FertilityKitActivationResult.allCases {
            XCTAssertEqual(FertilityKitAccessPresentation.isSuccess(result), result == .activated || result == .alreadyActive,
                           "\(result)")
        }
    }

    func testEveryVerificationResultButBusyHasARestoreLineAndBusyHasNone() {
        let results: [FertilityKitVerificationResult] = [
            .verified(hasAccess: true), .verified(hasAccess: false),
            .couldNotVerify(hasAccess: true), .couldNotVerify(hasAccess: false), .signedOut]
        let lines = results.map { FertilityKitAccessPresentation.restoreLine(for: $0) }
        XCTAssertTrue(lines.allSatisfy { !($0 ?? "").isEmpty })
        XCTAssertEqual(Set(lines.compactMap { $0 }).count, 5, "five outcomes, five lines")
        XCTAssertNil(FertilityKitAccessPresentation.restoreLine(for: .busy))
    }

    // MARK: - Submitting and asking again

    func testCanSubmitNeedsSomethingTypedAndNoCallRunning() {
        XCTAssertFalse(FertilityKitAccessPresentation.canSubmit(entry: "", isWorking: false))
        XCTAssertFalse(FertilityKitAccessPresentation.canSubmit(entry: "   \n ", isWorking: false))
        XCTAssertTrue(FertilityKitAccessPresentation.canSubmit(entry: "a", isWorking: false))
        XCTAssertTrue(FertilityKitAccessPresentation.canSubmit(entry: "  a  ", isWorking: false))
        XCTAssertFalse(FertilityKitAccessPresentation.canSubmit(entry: "a", isWorking: true))
        XCTAssertFalse(FertilityKitAccessPresentation.canSubmit(entry: "", isWorking: true))
    }

    func testABusyAnswerIsAskedAgainOnceWhenTheOtherCallHasFinished() {
        typealias Presentation = FertilityKitAccessPresentation
        XCTAssertFalse(Presentation.shouldAskAgain(after: .busy, isWorking: true, alreadyRetried: false),
                       "not while the other call still runs")
        XCTAssertTrue(Presentation.shouldAskAgain(after: .busy, isWorking: false, alreadyRetried: false))
        XCTAssertFalse(Presentation.shouldAskAgain(after: .busy, isWorking: false, alreadyRetried: true),
                       "never twice")
        for answer in [FertilityKitVerificationResult.verified(hasAccess: true), .couldNotVerify(hasAccess: false), .signedOut] {
            XCTAssertFalse(Presentation.shouldAskAgain(after: answer, isWorking: false, alreadyRetried: false), "\(answer)")
        }
    }

    // MARK: - The start date

    func testTheAllowedDatesAreTomorrowThroughSixtyDaysAhead() {
        let allowed = ProgrammeStartPresentation.allowedDates(today: today)
        XCTAssertEqual(allowed.lowerBound, today.plusDays(1))
        XCTAssertEqual(allowed.upperBound, today.plusDays(60))
        XCTAssertFalse(allowed.contains(today))
    }

    func testTheStartDateIsWorkedOutFromTodayAtCommit() {
        typealias Presentation = ProgrammeStartPresentation
        XCTAssertEqual(Presentation.startDate(choice: .today, today: today), today)
        XCTAssertEqual(Presentation.startDate(choice: .later(today.plusDays(1)), today: today), today.plusDays(1))
        XCTAssertEqual(Presentation.startDate(choice: .later(today.plusDays(33)), today: today), today.plusDays(33))
        XCTAssertEqual(Presentation.startDate(choice: .later(today.plusDays(60)), today: today), today.plusDays(60))
        XCTAssertEqual(Presentation.startDate(choice: .later(today.plusDays(61)), today: today), today.plusDays(60),
                       "past the range: the nearest bound")
        XCTAssertEqual(Presentation.startDate(choice: .later(today.plusDays(400)), today: today), today.plusDays(60))
        XCTAssertEqual(Presentation.startDate(choice: .later(today), today: today), today,
                       "a later date that has become today is today")
        XCTAssertEqual(Presentation.startDate(choice: .later(today.minusDays(1)), today: today), today,
                       "a later date that is now the past is today, never yesterday")
        // The sheet was opened yesterday and is committed after midnight.
        let chosen = ProgrammeStartChoice.later(today)
        XCTAssertEqual(Presentation.startDate(choice: chosen, today: today.plusDays(1)), today.plusDays(1))
    }

    // MARK: - With a real container

    private func seededContainer() -> AppContainer {
        let container = KitFixture.container()
        container.kitAccess.seedGrantForUITests()
        return container
    }

    func testActivatingDoesNotStartTheProgramme() {
        let container = seededContainer()
        XCTAssertTrue(container.kitAccess.hasAccess)
        XCTAssertEqual(container.programme.state, .notStarted)
        XCTAssertNil(container.store.load(ProgrammeProgressDTO.self, forKey: "programme_progress"))
        let kit = KitFixture.context(from: container, today: today)
        XCTAssertEqual(kit.accessState, .notStarted)
    }

    func testStartingThreeDaysAheadIsScheduled() {
        let container = seededContainer()
        XCTAssertEqual(container.programme.start(today: today.plusDays(3)), .started(today.plusDays(3)))
        let kit = KitFixture.context(from: container, today: today)
        XCTAssertEqual(kit.accessState, .scheduled(startsOn: today.plusDays(3), daysUntilStart: 3))
    }

    func testASecondStartKeepsTheFirstDate() {
        let container = seededContainer()
        _ = container.programme.start(today: today.plusDays(3))
        XCTAssertEqual(container.programme.start(today: today), .alreadyStarted(today.plusDays(3)))
        XCTAssertEqual(container.programme.start(today: today.plusDays(9)), .alreadyStarted(today.plusDays(3)))
        XCTAssertEqual(container.programme.state.startedOn, today.plusDays(3))
    }

    func testStartingIsRefusedWithoutAccessAndWithoutConsent() {
        let noAccess = KitFixture.container()
        XCTAssertEqual(noAccess.programme.start(today: today), .refusedNoAccess)
        XCTAssertNil(noAccess.store.load(ProgrammeProgressDTO.self, forKey: "programme_progress"))

        let withdrawn = seededContainer()
        withdrawn.consent.withdraw()
        XCTAssertEqual(withdrawn.programme.start(today: today), .refusedNoConsent)
        XCTAssertEqual(withdrawn.programme.state, .notStarted)
    }

    func testAnAccountThatLostAccessIsNoAccessWhateverIsStored() {
        let container = seededContainer()
        _ = container.programme.start(today: today)
        container.kitAccess.resetForQA()
        let kit = KitFixture.context(from: container, today: today)
        XCTAssertFalse(kit.hasAccess)
        XCTAssertEqual(kit.accessState, .noAccess)
    }

    func testTheStateAfterTheLastDayIsCompletedAndNeverShowsADayAbove90() {
        let container = seededContainer()
        _ = container.programme.start(today: today.minusDays(90))
        XCTAssertEqual(KitFixture.context(from: container, today: today).accessState, .completed)
    }
}
