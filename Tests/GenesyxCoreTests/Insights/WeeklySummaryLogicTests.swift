// WeeklySummaryLogicTests.swift
// Covers the pure Weekly Summary aggregation + deterministic narrative.

import XCTest
@testable import GenesyxCore

final class WeeklySummaryLogicTests: XCTestCase {

    // 2026-07-06 is a Monday, so day 0…6 maps cleanly to Mon…Sun.
    private let monday = CalendarDate(year: 2026, month: 7, day: 6)

    private func summary(
        _ logs: [CalendarDate: DailyLog],
        ph: [CalendarDate: [Double]] = [:],
        weekStart: CalendarDate? = nil,
        goalMl: Int = 2400
    ) -> WeeklySummary {
        WeeklySummaryLogic.summary(
            weekStart: weekStart ?? monday, logsByDate: logs, phValuesByDate: ph, goalMl: goalMl)
    }

    // MARK: empty week

    func testEmptyWeekIsZeroed() {
        let s = summary([:])
        XCTAssertTrue(s.isEmpty)
        XCTAssertEqual(s.waterByDay, Array(repeating: 0, count: 7))
        XCTAssertEqual(s.loggedDays, Array(repeating: false, count: 7))
        XCTAssertEqual(s.daysLogged, 0)
        XCTAssertEqual(s.daysOnGoal, 0)
        XCTAssertNil(s.sleepAverageMinutes)
        XCTAssertNil(s.phAverage)
        XCTAssertTrue(s.moodTallies.isEmpty)
        XCTAssertEqual(s.narrative, "Nothing logged this week yet — one small entry starts the picture.")
    }

    // MARK: aggregation

    func testWaterBarsDotsAndGoal() {
        var logs: [CalendarDate: DailyLog] = [:]
        logs[monday] = DailyLog(waterMl: 2400)                 // Mon on goal
        logs[monday.addingDays(1)] = DailyLog(waterMl: 1000)   // Tue logged, under goal
        logs[monday.addingDays(2)] = DailyLog(mood: .good)     // Wed meaningful, no water
        let s = summary(logs)
        XCTAssertEqual(s.waterByDay, [2400, 1000, 0, 0, 0, 0, 0])
        XCTAssertEqual(s.loggedDays, [true, true, true, false, false, false, false])
        XCTAssertEqual(s.waterTotalMl, 3400)
        XCTAssertEqual(s.daysLogged, 3)
        XCTAssertEqual(s.daysOnGoal, 1)
        XCTAssertFalse(s.isEmpty)
    }

    func testSleepAndPhAverages() {
        var logs: [CalendarDate: DailyLog] = [:]
        logs[monday] = DailyLog(sleepMinutes: 420)             // 7h
        logs[monday.addingDays(1)] = DailyLog(sleepMinutes: 480) // 8h
        let ph: [CalendarDate: [Double]] = [
            monday: [6.0, 7.0],              // two readings that day
            monday.addingDays(3): [6.5],
        ]
        let s = summary(logs, ph: ph)
        XCTAssertEqual(s.sleepAverageMinutes, 450)              // (420+480)/2
        XCTAssertEqual(s.phAverage!, (6.0 + 7.0 + 6.5) / 3, accuracy: 0.0001)
        // A pH-only day counts as logged.
        XCTAssertTrue(s.loggedDays[3])
    }

    func testMoodAndEnergyTalliesInCanonicalOrder() {
        var logs: [CalendarDate: DailyLog] = [:]
        logs[monday] = DailyLog(mood: .low, energy: .high)
        logs[monday.addingDays(1)] = DailyLog(mood: .great)
        logs[monday.addingDays(2)] = DailyLog(mood: .great)
        let s = summary(logs)
        XCTAssertEqual(s.moodTallies, [MoodTally(mood: .great, count: 2), MoodTally(mood: .low, count: 1)])
        XCTAssertEqual(s.energyTallies, [EnergyTally(level: .high, count: 1)])
    }

    // MARK: deltas (honest comparisons only)

    func testNoDeltasWhenPreviousWeekEmpty() {
        let logs = [monday: DailyLog(sleepMinutes: 400, waterMl: 2000)]
        let s = summary(logs)
        XCTAssertNil(s.deltas.waterTotalMl)
        XCTAssertNil(s.deltas.daysLogged)
        XCTAssertNil(s.deltas.sleepAverageMinutes)
    }

    func testDeltasComputedAgainstPreviousWeek() {
        let lastMonday = monday.addingDays(-7)
        var logs: [CalendarDate: DailyLog] = [:]
        // Previous week: 1 day, 1000ml, 400 min sleep.
        logs[lastMonday] = DailyLog(sleepMinutes: 400, waterMl: 1000)
        // This week: 2 days, 1000+1500ml, 500 min sleep.
        logs[monday] = DailyLog(sleepMinutes: 500, waterMl: 1000)
        logs[monday.addingDays(1)] = DailyLog(waterMl: 1500)
        let s = summary(logs)
        XCTAssertEqual(s.deltas.waterTotalMl, 2500 - 1000)
        XCTAssertEqual(s.deltas.daysLogged, 2 - 1)
        XCTAssertEqual(s.deltas.sleepAverageMinutes, 500 - 400)
    }

    func testSleepDeltaNilWhenOnlyOneWeekHasSleep() {
        let lastMonday = monday.addingDays(-7)
        var logs: [CalendarDate: DailyLog] = [:]
        logs[lastMonday] = DailyLog(waterMl: 1000)              // prev week has data, but no sleep
        logs[monday] = DailyLog(sleepMinutes: 500, waterMl: 1000)
        let s = summary(logs)
        XCTAssertNil(s.deltas.sleepAverageMinutes)
        XCTAssertEqual(s.deltas.daysLogged, 0)                  // both weeks 1 logged day
    }

    // MARK: narrative

    func testNarrativeConsistencyBands() {
        XCTAssertEqual(
            WeeklySummaryLogic.narrativeLine(daysLogged: 7, daysOnGoal: 7, hasAnyWater: true, isEmpty: false),
            "A really consistent week — 7 of 7 days logged. Hydration was on goal most days.")
        XCTAssertEqual(
            WeeklySummaryLogic.narrativeLine(daysLogged: 4, daysOnGoal: 2, hasAnyWater: true, isEmpty: false),
            "A steady week — 4 of 7 days logged. Hydration reached goal on 2 days.")
        XCTAssertEqual(
            WeeklySummaryLogic.narrativeLine(daysLogged: 1, daysOnGoal: 0, hasAnyWater: false, isEmpty: false),
            "1 day logged this week — every entry counts.")
    }
}
