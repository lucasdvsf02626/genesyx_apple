import XCTest
@testable import GenesyxCore

/// Day, week and phase are derived from the start date and the date passed in, and nothing else.
final class ProgrammeStateTests: XCTestCase {

    private let start = CalendarDate(2026, 6, 1)
    private var state: ProgrammeState { ProgrammeState(startedOn: start) }

    private func position(day: Int) -> ProgrammePosition {
        ProgrammeCalendar.position(state, on: start.plusDays(day - 1))
    }

    func testNotStarted() {
        let today = CalendarDate(2026, 6, 1)
        XCTAssertEqual(ProgrammeCalendar.position(.notStarted, on: today), .notStarted)
        XCTAssertNil(ProgrammeCalendar.activeDay(.notStarted, on: today))
        XCTAssertEqual(ProgrammeCalendar.progressFraction(.notStarted, on: today), 0)
        XCTAssertEqual(ProgrammeCalendar.daysRemaining(.notStarted, on: today), 90)
    }

    func testDayOneIsTheStartDate() {
        XCTAssertEqual(position(day: 1), .active(day: 1, week: 1, phase: .buildTheFoundation))
    }

    func testWeekAndPhaseAtEveryBoundary() {
        let expected: [(day: Int, week: Int, phase: ProgrammePhase)] = [
            (1, 1, .buildTheFoundation), (7, 1, .buildTheFoundation), (8, 2, .buildTheFoundation),
            (30, 5, .buildTheFoundation), (31, 5, .discoverYourPatterns),
            (60, 9, .discoverYourPatterns), (61, 9, .personaliseAndSustain),
            (84, 12, .personaliseAndSustain), (85, 13, .personaliseAndSustain),
            (90, 13, .personaliseAndSustain),
        ]
        for row in expected {
            XCTAssertEqual(position(day: row.day), .active(day: row.day, week: row.week, phase: row.phase),
                           "day \(row.day)")
        }
    }

    func testDay91OnwardsIsCompletedAndKeepsCounting() {
        XCTAssertEqual(position(day: 91), .completed(day: 91))
        XCTAssertEqual(position(day: 200), .completed(day: 200))
        XCTAssertNil(ProgrammeCalendar.activeDay(state, on: start.plusDays(90)))
        XCTAssertEqual(ProgrammeCalendar.progressFraction(state, on: start.plusDays(199)), 1)
        XCTAssertEqual(ProgrammeCalendar.daysRemaining(state, on: start.plusDays(199)), 0)
    }

    func testTodayBeforeTheStartIsNeverANegativeDay() {
        XCTAssertEqual(ProgrammeCalendar.position(state, on: start.minusDays(1)), .beforeStart(daysUntilStart: 1))
        XCTAssertEqual(ProgrammeCalendar.position(state, on: start.minusDays(400)), .beforeStart(daysUntilStart: 400))
        XCTAssertNil(ProgrammeCalendar.activeDay(state, on: start.minusDays(1)))
        XCTAssertEqual(ProgrammeCalendar.progressFraction(state, on: start.minusDays(1)), 0)
        XCTAssertEqual(ProgrammeCalendar.daysRemaining(state, on: start.minusDays(1)), 90)
    }

    func testWeeksAreSevenDaysExceptThirteenAndPhasesAreThirty() {
        for week in 1...12 { XCTAssertEqual(ProgrammeCalendar.dayRange(ofWeek: week).count, 7) }
        XCTAssertEqual(ProgrammeCalendar.dayRange(ofWeek: 13), 85...90)
        XCTAssertEqual(ProgrammePhase.buildTheFoundation.dayRange, 1...30)
        XCTAssertEqual(ProgrammePhase.discoverYourPatterns.dayRange, 31...60)
        XCTAssertEqual(ProgrammePhase.personaliseAndSustain.dayRange, 61...90)
    }

    func testProgressFractionAndDaysRemaining() {
        XCTAssertEqual(ProgrammeCalendar.progressFraction(state, on: start), 1.0 / 90.0, accuracy: 1e-12)
        XCTAssertEqual(ProgrammeCalendar.progressFraction(state, on: start.plusDays(22)), 23.0 / 90.0, accuracy: 1e-12)
        XCTAssertEqual(ProgrammeCalendar.progressFraction(state, on: start.plusDays(44)), 0.5, accuracy: 1e-12)
        XCTAssertEqual(ProgrammeCalendar.progressFraction(state, on: start.plusDays(89)), 1)
        XCTAssertEqual(ProgrammeCalendar.daysRemaining(state, on: start), 89)
        XCTAssertEqual(ProgrammeCalendar.daysRemaining(state, on: start.plusDays(89)), 0)
    }

    func testStoppedFromTheStopDateOn() {
        let stopped = ProgrammeState(startedOn: start, stoppedOn: start.plusDays(10))
        XCTAssertEqual(ProgrammeCalendar.position(stopped, on: start.plusDays(9)),
                       .active(day: 10, week: 2, phase: .buildTheFoundation))
        XCTAssertEqual(ProgrammeCalendar.position(stopped, on: start.plusDays(10)), .stopped)
        XCTAssertNil(ProgrammeCalendar.daysRemaining(stopped, on: start.plusDays(50)))
    }

    // ── Clock time never moves the day ──

    private var london: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }

    private func instant(_ y: Int, _ m: Int, _ d: Int, _ hour: Int, _ minute: Int) -> Date {
        london.date(from: DateComponents(year: y, month: m, day: d, hour: hour, minute: minute))!
    }

    /// The day she would see if she started at `startInstant` and opened the app at `nowInstant`.
    private func day(startedAt startInstant: Date, openedAt nowInstant: Date) -> Int {
        ProgrammeCalendar.dayNumber(on: CalendarDate.today(london, now: nowInstant),
                                    startedOn: CalendarDate.today(london, now: startInstant))
    }

    func testAStartLateOnNewYearsEveIsDayOneThatDateAndDayTwoAfterMidnight() {
        let started = instant(2026, 12, 31, 23, 59)
        XCTAssertEqual(CalendarDate.today(london, now: started), CalendarDate(2026, 12, 31))
        XCTAssertEqual(day(startedAt: started, openedAt: started), 1)
        XCTAssertEqual(day(startedAt: started, openedAt: instant(2027, 1, 1, 0, 1)), 2)
        XCTAssertEqual(day(startedAt: started, openedAt: instant(2027, 1, 1, 23, 59)), 2)
        XCTAssertEqual(day(startedAt: started, openedAt: instant(2027, 3, 30, 12, 0)), 90)
    }

    /// Clocks go forward on 29 March 2026, so that date is 23 hours long.
    func testTheMarchClockChangeDoesNotShiftTheDay() {
        let before = instant(2026, 3, 28, 23, 30)
        XCTAssertEqual(day(startedAt: before, openedAt: instant(2026, 3, 29, 0, 30)), 2)
        XCTAssertEqual(day(startedAt: before, openedAt: instant(2026, 3, 29, 23, 30)), 2)
        XCTAssertEqual(day(startedAt: before, openedAt: instant(2026, 3, 30, 0, 30)), 3)
        XCTAssertEqual(day(startedAt: before, openedAt: instant(2026, 6, 25, 23, 30)), 90)

        let after = instant(2026, 3, 29, 3, 0)
        XCTAssertEqual(day(startedAt: after, openedAt: instant(2026, 3, 29, 23, 59)), 1)
        XCTAssertEqual(day(startedAt: after, openedAt: instant(2026, 3, 30, 0, 1)), 2)
        XCTAssertEqual(day(startedAt: after, openedAt: instant(2026, 6, 26, 12, 0)), 90)
    }

    /// Clocks go back on 25 October 2026, so that date is 25 hours long.
    func testTheOctoberClockChangeDoesNotShiftTheDay() {
        let before = instant(2026, 10, 24, 23, 30)
        XCTAssertEqual(day(startedAt: before, openedAt: instant(2026, 10, 25, 0, 30)), 2)
        XCTAssertEqual(day(startedAt: before, openedAt: instant(2026, 10, 25, 23, 30)), 2)
        XCTAssertEqual(day(startedAt: before, openedAt: instant(2026, 10, 26, 0, 30)), 3)
        XCTAssertEqual(day(startedAt: before, openedAt: instant(2027, 1, 21, 12, 0)), 90)

        let after = instant(2026, 10, 25, 3, 0)
        XCTAssertEqual(day(startedAt: after, openedAt: instant(2026, 10, 25, 23, 59)), 1)
        XCTAssertEqual(day(startedAt: after, openedAt: instant(2026, 10, 26, 0, 1)), 2)
        // A start earlier in the summer, read on each side of the change.
        let summer = instant(2026, 9, 1, 9, 0)
        XCTAssertEqual(day(startedAt: summer, openedAt: instant(2026, 10, 24, 12, 0)), 54)
        XCTAssertEqual(day(startedAt: summer, openedAt: instant(2026, 10, 25, 12, 0)), 55)
        XCTAssertEqual(day(startedAt: summer, openedAt: instant(2026, 10, 26, 12, 0)), 56)
    }
}
