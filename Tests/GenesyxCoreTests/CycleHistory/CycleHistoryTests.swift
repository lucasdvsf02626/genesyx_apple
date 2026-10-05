import XCTest
@testable import GenesyxCore

final class CycleHistoryTests: XCTestCase {

    private func stored(_ y: Int, _ m: Int, _ d: Int, end: CalendarDate? = nil,
                        source: PeriodSource = .recorded, deleted: Bool = false) -> StoredPeriodRecord {
        PeriodFixture.stored(CalendarDate(y, m, d), end: end, source: source, deleted: deleted)
    }

    /// Recorded starts `gaps` days apart, beginning 1 January 2026.
    private func history(gaps: [Int], firstSource: PeriodSource = .recorded) -> [StoredPeriodRecord] {
        var start = CalendarDate(2026, 1, 1)
        var records = [PeriodFixture.stored(start, source: firstSource)]
        for gap in gaps {
            start = start.plusDays(gap)
            records.append(PeriodFixture.stored(start))
        }
        return records
    }

    // MARK: - Derivation

    func testNoRecordsMeansNoCycles() {
        XCTAssertTrue(CycleHistory.cycles(from: []).isEmpty)
        XCTAssertNil(CycleHistory.cycleDay(on: CalendarDate(2026, 3, 1), in: []))
        XCTAssertFalse(CycleHistory.canMakeCrossCycleStatement([]))
    }

    /// The user who never logs again: one open cycle that never closes, and nothing to summarise.
    func testOneSeededRecordIsOneOpenCycle() {
        let cycles = CycleHistory.cycles(from: [stored(2026, 3, 3, source: .seeded)])

        XCTAssertEqual(cycles.count, 1)
        XCTAssertEqual(cycles[0].id, CalendarDate(2026, 3, 3))
        XCTAssertEqual(cycles[0].status, .active)
        XCTAssertNil(cycles[0].end)
        XCTAssertNil(cycles[0].length)
        XCTAssertNil(cycles[0].periodDays)
        XCTAssertEqual(cycles[0].source, .seeded)
        XCTAssertFalse(cycles[0].isRecorded)
        XCTAssertTrue(CycleHistory.completedLengths(cycles).isEmpty)
    }

    func testTwoStartsGiveOneCompletedAndOneOpenCycle() {
        let cycles = CycleHistory.cycles(from: [
            stored(2026, 3, 3, end: CalendarDate(2026, 3, 7)),
            stored(2026, 4, 1),
        ])

        XCTAssertEqual(cycles.map(\.status), [.completed, .active])
        XCTAssertEqual(cycles[0].start, CalendarDate(2026, 3, 3))
        XCTAssertEqual(cycles[0].end, CalendarDate(2026, 3, 31))
        XCTAssertEqual(cycles[0].length, 29)
        XCTAssertEqual(cycles[0].periodDays, 5)
        XCTAssertTrue(cycles[0].isRecorded)
        XCTAssertNil(cycles[1].length)
        XCTAssertNil(cycles[1].periodDays, "no end was recorded for the second period")
    }

    func testOutOfOrderRecordsAreDerivedInDateOrder() {
        let cycles = CycleHistory.cycles(from: [stored(2026, 4, 1), stored(2026, 2, 1), stored(2026, 3, 3)])

        XCTAssertEqual(cycles.map(\.start), [CalendarDate(2026, 2, 1), CalendarDate(2026, 3, 3), CalendarDate(2026, 4, 1)])
        XCTAssertEqual(CycleHistory.completedLengths(cycles), [30, 29])
    }

    func testTombstonesAreNotCycles() {
        let cycles = CycleHistory.cycles(from: [stored(2026, 2, 1), stored(2026, 3, 3, deleted: true), stored(2026, 4, 1)])

        XCTAssertEqual(cycles.map(\.start), [CalendarDate(2026, 2, 1), CalendarDate(2026, 4, 1)])
        XCTAssertEqual(cycles[0].length, 59)
    }

    /// No clamping and no assumed length: three days is three days, half a year is half a year.
    func testVeryShortAndVeryLongCyclesAreRepresentedFaithfully() {
        let cycles = CycleHistory.cycles(from: [stored(2026, 3, 1), stored(2026, 3, 4), stored(2026, 9, 1)])

        XCTAssertEqual(CycleHistory.completedLengths(cycles), [3, 181])
        XCTAssertEqual(cycles[0].end, CalendarDate(2026, 3, 3))
        XCTAssertEqual(cycles[1].end, CalendarDate(2026, 8, 31))
        XCTAssertTrue(CycleHistory.countableCycles(cycles).isEmpty, "neither is inside the accepted range")
    }

    func testSeededStartMarksTheCycleItOpensAndTheCycleItCloses() {
        // A back-filled period before the seeded one, then a recorded one after it.
        let cycles = CycleHistory.cycles(from: [stored(2026, 2, 1), stored(2026, 3, 3, source: .seeded), stored(2026, 4, 1)])

        XCTAssertEqual(cycles.map(\.source), [.recorded, .seeded, .recorded])
        XCTAssertEqual(cycles.map(\.closingSource), [.seeded, .recorded, nil])
        XCTAssertEqual(cycles.map(\.isRecorded), [false, false, true])
    }

    /// An end that reaches the next start can only come from two devices' edits meeting in a merge.
    func testPeriodDaysIgnoreAnEndThatReachesTheNextStart() {
        let cycles = CycleHistory.cycles(from: [stored(2026, 3, 1, end: CalendarDate(2026, 3, 6)), stored(2026, 3, 5)])

        XCTAssertNil(cycles[0].periodDays)
        XCTAssertEqual(cycles[0].length, 4)
    }

    // MARK: - Date arithmetic: month, year, leap day and clock changes

    func testLengthsAcrossMonthYearAndLeapDayBoundaries() {
        let cycles = CycleHistory.cycles(from: [
            stored(2023, 12, 10), stored(2024, 1, 9), stored(2024, 2, 10), stored(2024, 3, 10),
        ])

        XCTAssertEqual(CycleHistory.completedLengths(cycles), [30, 32, 29])
        XCTAssertEqual(cycles[0].end, CalendarDate(2024, 1, 8))
        XCTAssertEqual(CycleHistory.cycleDay(on: CalendarDate(2023, 12, 31), in: cycles), 22)
        XCTAssertEqual(CycleHistory.cycleDay(on: CalendarDate(2024, 1, 1), in: cycles), 23)
        XCTAssertEqual(CycleHistory.cycleDay(on: CalendarDate(2024, 2, 29), in: cycles), 20)
    }

    /// The clocks change in London on 29 March and 25 October 2026. Dates taken late at night and
    /// just after midnight either side of each change must still be whole days apart.
    func testLengthsAndCycleDaysAcrossLondonClockChanges() throws {
        var london = Calendar(identifier: .gregorian)
        london.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        func local(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> CalendarDate {
            let instant = try XCTUnwrap(london.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)))
            return CalendarDate.today(london, now: instant)
        }

        let records = [
            PeriodFixture.stored(try local(3, 1, 23, 30)),
            PeriodFixture.stored(try local(3, 30, 0, 30)),     // the day after the spring change
            PeriodFixture.stored(try local(4, 27, 12, 0)),
            PeriodFixture.stored(try local(9, 27, 23, 59)),
            PeriodFixture.stored(try local(10, 26, 0, 1)),     // the day after the autumn change
        ]
        let cycles = CycleHistory.cycles(from: records)

        XCTAssertEqual(cycles.map(\.start), [
            CalendarDate(2026, 3, 1), CalendarDate(2026, 3, 30), CalendarDate(2026, 4, 27),
            CalendarDate(2026, 9, 27), CalendarDate(2026, 10, 26),
        ])
        XCTAssertEqual(CycleHistory.completedLengths(cycles), [29, 28, 153, 29])
        XCTAssertEqual(cycles[0].end, CalendarDate(2026, 3, 29))
        XCTAssertEqual(cycles[3].end, CalendarDate(2026, 10, 25))
        XCTAssertEqual(CycleHistory.cycleDay(on: try local(3, 29, 23, 30), in: cycles), 29, "the 23-hour day")
        XCTAssertEqual(CycleHistory.cycleDay(on: try local(3, 30, 0, 30), in: cycles), 1)
        XCTAssertEqual(CycleHistory.cycleDay(on: try local(10, 25, 1, 30), in: cycles), 29, "the 25-hour day")
        XCTAssertEqual(CycleHistory.cycleDay(on: try local(10, 26, 0, 1), in: cycles), 1)
    }

    // MARK: - Which cycle, which day

    func testCycleDay() {
        let cycles = CycleHistory.cycles(from: [stored(2026, 3, 3), stored(2026, 4, 1)])

        XCTAssertNil(CycleHistory.cycleDay(on: CalendarDate(2026, 3, 2), in: cycles), "before the first record")
        XCTAssertNil(CycleHistory.cycle(containing: CalendarDate(2026, 3, 2), in: cycles))
        XCTAssertEqual(CycleHistory.cycleDay(on: CalendarDate(2026, 3, 3), in: cycles), 1, "a start date is day 1")
        XCTAssertEqual(CycleHistory.cycleDay(on: CalendarDate(2026, 3, 17), in: cycles), 15, "inside a completed cycle")
        XCTAssertEqual(CycleHistory.cycleDay(on: CalendarDate(2026, 3, 31), in: cycles), 29, "its last day")
        XCTAssertEqual(CycleHistory.cycle(containing: CalendarDate(2026, 3, 31), in: cycles)?.start, CalendarDate(2026, 3, 3))
        XCTAssertEqual(CycleHistory.cycleDay(on: CalendarDate(2026, 4, 1), in: cycles), 1)
        XCTAssertEqual(CycleHistory.cycleDay(on: CalendarDate(2026, 4, 20), in: cycles), 20, "inside the open cycle")
        XCTAssertEqual(CycleHistory.cycleDay(on: CalendarDate(2026, 7, 9), in: cycles), 100, "the open cycle never wraps")
    }

    // MARK: - Cross-cycle statements

    func testTwoCompletedCyclesAreNotEnoughAndThreeAre() {
        let two = CycleHistory.cycles(from: history(gaps: [29, 30]))
        let three = CycleHistory.cycles(from: history(gaps: [29, 30, 31]))

        XCTAssertEqual(CycleHistory.completedLengths(two), [29, 30])
        XCTAssertFalse(CycleHistory.canMakeCrossCycleStatement(two))
        XCTAssertEqual(CycleHistory.completedLengths(three), [29, 30, 31])
        XCTAssertTrue(CycleHistory.canMakeCrossCycleStatement(three))
        XCTAssertEqual(CycleHistory.minimumCyclesForCrossCycleStatement, 3)
    }

    func testASeededCycleDoesNotCount() {
        let cycles = CycleHistory.cycles(from: history(gaps: [29, 30, 31], firstSource: .seeded))

        XCTAssertEqual(CycleHistory.completedLengths(cycles), [29, 30, 31], "it is still listed")
        XCTAssertEqual(CycleHistory.countableCycles(cycles).compactMap(\.length), [30, 31])
        XCTAssertFalse(CycleHistory.canMakeCrossCycleStatement(cycles))

        let oneMore = CycleHistory.cycles(from: history(gaps: [29, 30, 31, 27], firstSource: .seeded))
        XCTAssertTrue(CycleHistory.canMakeCrossCycleStatement(oneMore))
    }

    func testACycleOutsideTheAcceptedRangeDoesNotCount() {
        XCTAssertFalse(CycleHistory.canMakeCrossCycleStatement(CycleHistory.cycles(from: history(gaps: [29, 60, 31]))))
        XCTAssertFalse(CycleHistory.canMakeCrossCycleStatement(CycleHistory.cycles(from: history(gaps: [29, 20, 31]))))
        XCTAssertFalse(CycleHistory.canMakeCrossCycleStatement(CycleHistory.cycles(from: history(gaps: [29, 36, 31]))))
    }

    func testTheRangeBoundsThemselvesCount() {
        let cycles = CycleHistory.cycles(from: history(gaps: [21, 35, 30]))

        XCTAssertEqual(CycleEngine.cycleLengthRange, 21...35)
        XCTAssertTrue(CycleHistory.canMakeCrossCycleStatement(cycles))
    }

    // MARK: - Observations by date range

    func testObservationsAreGroupedByTheCycleTheirDateFallsIn() {
        struct Reading: Equatable { let name: String; let date: CalendarDate }
        let cycles = CycleHistory.cycles(from: [stored(2026, 3, 3), stored(2026, 4, 1)])
        let readings = [
            Reading(name: "before", date: CalendarDate(2026, 3, 2)),
            Reading(name: "first day", date: CalendarDate(2026, 3, 3)),
            Reading(name: "open, later", date: CalendarDate(2026, 5, 20)),
            Reading(name: "last day", date: CalendarDate(2026, 3, 31)),
            Reading(name: "next first day", date: CalendarDate(2026, 4, 1)),
            Reading(name: "middle", date: CalendarDate(2026, 3, 15)),
        ]

        let groups = CycleHistory.group(readings, by: cycles, date: \.date)

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[CalendarDate(2026, 3, 3)]?.map(\.name), ["first day", "last day", "middle"])
        XCTAssertEqual(groups[CalendarDate(2026, 4, 1)]?.map(\.name), ["open, later", "next first day"])
        XCTAssertEqual(groups.values.joined().count, 5, "the reading before the first start belongs to no cycle")
    }

    func testGroupingWithNoCyclesIsEmpty() {
        XCTAssertTrue(CycleHistory.group([CalendarDate(2026, 3, 3)], by: [], date: { $0 }).isEmpty)
    }
}
