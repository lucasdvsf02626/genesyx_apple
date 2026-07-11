// StreakEngineTests.swift
// Covers every bucket named in Master Implementation Doc §3.

import XCTest
@testable import GenesyxCore

private struct FakeLog: StreakLoggable {
    var waterMl: Int = 0
    var hasAnyEntry: Bool = false
    static func water(_ ml: Int = 200) -> FakeLog { .init(waterMl: ml, hasAnyEntry: true) }
    static func moodOnly() -> FakeLog { .init(waterMl: 0, hasAnyEntry: true) }
}

final class StreakEngineTests: XCTestCase {

    // A Monday, so week math is easy to reason about in tests.
    private let monday = CalendarDate(year: 2026, month: 7, day: 6)

    private func compute(
        logs: [CalendarDate: FakeLog],
        ph: Set<CalendarDate> = [],
        today: CalendarDate,
        celebrated: Set<String> = []
    ) -> StreakState {
        StreakEngine.compute(logsByDate: logs, phByDate: ph, today: today, celebrated: celebrated)
    }

    // MARK: empty history

    func testEmptyHistoryIsAllZeros() {
        let s = compute(logs: [:], today: monday)
        XCTAssertEqual(s.dailyHydration, 0)
        XCTAssertEqual(s.weeklyStreak, 0)
        XCTAssertEqual(s.daysLoggedThisWeek, 0)
        XCTAssertEqual(s.bestDailyStreak, 0)
        XCTAssertTrue(s.milestones.isEmpty)
        XCTAssertEqual(s.weekDots, Array(repeating: false, count: 7))
    }

    // MARK: daily hydration streak

    func testDailyStreakCountsBackFromToday() {
        var logs: [CalendarDate: FakeLog] = [:]
        for i in 0..<3 { logs[monday.addingDays(-i)] = .water() }
        XCTAssertEqual(compute(logs: logs, today: monday).dailyHydration, 3)
    }

    func testMorningGraceKeepsYesterdaysStreak() {
        // Water yesterday + the two days before, nothing today (yet) → 3, not 0.
        var logs: [CalendarDate: FakeLog] = [:]
        for i in 1...3 { logs[monday.addingDays(-i)] = .water() }
        XCTAssertEqual(compute(logs: logs, today: monday).dailyHydration, 3)
    }

    func testFullyMissedDayBreaksDailyStreak() {
        var logs: [CalendarDate: FakeLog] = [:]
        logs[monday.addingDays(-2)] = .water() // gap at -1 and today
        XCTAssertEqual(compute(logs: logs, today: monday).dailyHydration, 0)
    }

    func testMoodOnlyDayDoesNotExtendHydrationStreak() {
        let logs: [CalendarDate: FakeLog] = [monday: .moodOnly()]
        XCTAssertEqual(compute(logs: logs, today: monday).dailyHydration, 0)
    }

    func testBestDailyStreakFindsHistoricRun() {
        var logs: [CalendarDate: FakeLog] = [:]
        for i in 30..<40 { logs[monday.addingDays(-i)] = .water() } // 10-day run long ago
        logs[monday] = .water()
        let s = compute(logs: logs, today: monday)
        XCTAssertEqual(s.bestDailyStreak, 10)
        XCTAssertEqual(s.dailyHydration, 1)
    }

    // MARK: weekly streak — 5-of-7 boundary

    func testFourOfSevenDaysIsNotACompleteWeek() {
        var logs: [CalendarDate: FakeLog] = [:]
        let lastMonday = monday.addingDays(-7)
        for i in 0..<4 { logs[lastMonday.addingDays(i)] = .moodOnly() }
        XCTAssertEqual(compute(logs: logs, today: monday).weeklyStreak, 0)
    }

    func testFiveOfSevenDaysIsACompleteWeek() {
        var logs: [CalendarDate: FakeLog] = [:]
        let lastMonday = monday.addingDays(-7)
        for i in 0..<5 { logs[lastMonday.addingDays(i)] = .moodOnly() }
        XCTAssertEqual(compute(logs: logs, today: monday).weeklyStreak, 1)
    }

    func testPhOnlyDaysCountTowardWeeklyCompleteness() {
        let lastMonday = monday.addingDays(-7)
        let ph = Set((0..<5).map { lastMonday.addingDays($0) })
        XCTAssertEqual(compute(logs: [:], ph: ph, today: monday).weeklyStreak, 1)
    }

    func testInProgressWeekNeverBreaksTheStreak() {
        // Two complete past weeks; current week only has Monday logged (day 1 of 7).
        var logs: [CalendarDate: FakeLog] = [:]
        for week in 1...2 {
            let start = monday.addingDays(-7 * week)
            for i in 0..<5 { logs[start.addingDays(i)] = .moodOnly() }
        }
        logs[monday] = .moodOnly()
        let s = compute(logs: logs, today: monday)
        XCTAssertEqual(s.weeklyStreak, 2)
        XCTAssertEqual(s.daysLoggedThisWeek, 1)
    }

    func testCurrentWeekCountsOnceComplete() {
        // 5 active days Mon–Fri this week; today is Friday.
        var logs: [CalendarDate: FakeLog] = [:]
        for i in 0..<5 { logs[monday.addingDays(i)] = .moodOnly() }
        let friday = monday.addingDays(4)
        XCTAssertEqual(compute(logs: logs, today: friday).weeklyStreak, 1)
    }

    func testIncompleteWeekInThePastResetsWeeklyStreak() {
        var logs: [CalendarDate: FakeLog] = [:]
        // Week -1 complete, week -2 only 3 days, week -3 complete → streak is 1.
        let w1 = monday.addingDays(-7), w2 = monday.addingDays(-14), w3 = monday.addingDays(-21)
        for i in 0..<5 { logs[w1.addingDays(i)] = .moodOnly() }
        for i in 0..<3 { logs[w2.addingDays(i)] = .moodOnly() }
        for i in 0..<6 { logs[w3.addingDays(i)] = .moodOnly() }
        XCTAssertEqual(compute(logs: logs, today: monday).weeklyStreak, 1)
    }

    // MARK: milestones

    func testDay7MilestoneFiresOnceThenStaysQuiet() {
        var logs: [CalendarDate: FakeLog] = [:]
        for i in 0..<7 { logs[monday.addingDays(-i)] = .water() }

        let first = compute(logs: logs, today: monday)
        XCTAssertTrue(first.milestones.contains(.day7))

        let after = compute(logs: logs, today: monday, celebrated: [Milestone.day7.flagKey])
        XCTAssertFalse(after.milestones.contains(.day7))
    }

    func testLapsedStreakClearsFlagSoReachievingRefires() {
        // Celebrated day7 previously; streak now broken → flag reported lapsed.
        let broken = compute(logs: [:], today: monday, celebrated: [Milestone.day7.flagKey])
        XCTAssertTrue(broken.lapsedCelebrations.contains(Milestone.day7.flagKey))

        // Re-achieve with the flag cleared → fires again.
        var logs: [CalendarDate: FakeLog] = [:]
        for i in 0..<7 { logs[monday.addingDays(-i)] = .water() }
        let again = compute(logs: logs, today: monday, celebrated: [])
        XCTAssertTrue(again.milestones.contains(.day7))
    }

    func testWeekMilestones() {
        var logs: [CalendarDate: FakeLog] = [:]
        for week in 1...4 {
            let start = monday.addingDays(-7 * week)
            for i in 0..<5 { logs[start.addingDays(i)] = .moodOnly() }
        }
        let s = compute(logs: logs, today: monday)
        XCTAssertEqual(s.weeklyStreak, 4)
        XCTAssertTrue(s.milestones.contains(.week1))
        XCTAssertTrue(s.milestones.contains(.week4))
    }

    func testDay14RequiresFourteenConsecutiveHydrationDays() {
        var logs: [CalendarDate: FakeLog] = [:]
        for i in 0..<13 { logs[monday.addingDays(-i)] = .water() }
        XCTAssertFalse(compute(logs: logs, today: monday).milestones.contains(.day14))
        logs[monday.addingDays(-13)] = .water()
        XCTAssertTrue(compute(logs: logs, today: monday).milestones.contains(.day14))
    }
}
