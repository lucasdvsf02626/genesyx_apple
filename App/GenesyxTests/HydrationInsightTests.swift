import XCTest
@testable import Genesyx
import GenesyxCore

final class HydrationInsightTests: XCTestCase {

    private let bannedPhrases = [
        "alkaline diet", "balance your ph", "boy or girl", "sex selection", "detox", "flush toxins",
    ]

    func testNoBannedPhrasesInInsightLines() {
        for days in 0...7 {
            for streak in [0, 3, 10] {
                let lower = HydrationInsightLogic.insightLine(daysOnGoal: days, streak: streak).lowercased()
                for phrase in bannedPhrases {
                    XCTAssertFalse(lower.contains(phrase), "Banned phrase \"\(phrase)\" in hydration insight")
                }
            }
        }
    }

    func testInsightBuckets() {
        XCTAssertTrue(HydrationInsightLogic.insightLine(daysOnGoal: 0, streak: 0).contains("started tracking"))
        XCTAssertTrue(HydrationInsightLogic.insightLine(daysOnGoal: 2, streak: 0).hasPrefix("2 days on goal"))
        XCTAssertTrue(HydrationInsightLogic.insightLine(daysOnGoal: 5, streak: 0).hasPrefix("5 of 7"))
        XCTAssertTrue(HydrationInsightLogic.insightLine(daysOnGoal: 7, streak: 0).contains("Every day on goal"))
    }

    func testStreakAppendedAtThreePlus() {
        XCTAssertTrue(HydrationInsightLogic.insightLine(daysOnGoal: 4, streak: 5).contains("5-day streak going"))
        XCTAssertFalse(HydrationInsightLogic.insightLine(daysOnGoal: 4, streak: 2).contains("streak going"))
    }

    func testComputeTotalsAndDaysOnGoal() {
        let r = HydrationInsightLogic.compute(dailyMl: [2400, 1200, 2500, 0, 2400, 800, 2400], goalMl: 2400, streak: 0)
        XCTAssertEqual(r.totalMl, 11700)
        XCTAssertEqual(r.daysOnGoal, 4)   // 2400, 2500, 2400, 2400
        XCTAssertEqual(r.dailyMl.count, 7)
    }

    func testBoundaryZeroAndSeven() {
        XCTAssertEqual(HydrationInsightLogic.compute(dailyMl: Array(repeating: 0, count: 7), streak: 0).daysOnGoal, 0)
        XCTAssertEqual(HydrationInsightLogic.compute(dailyMl: Array(repeating: 2400, count: 7), streak: 0).daysOnGoal, 7)
    }

    // MARK: - lastSevenDays (trailing window, today last)

    func testLastSevenDaysOrdersOldestToTodayLast() {
        let today = CalendarDate(2026, 7, 15)
        var logs: [CalendarDate: DailyLog] = [:]
        for i in 0..<7 { var l = DailyLog(); l.waterMl = (i + 1) * 100; logs[today.minusDays(6 - i)] = l }
        let r = HydrationInsightLogic.lastSevenDays(logByDate: logs, goalMl: 2400, streak: 0, today: today)
        XCTAssertEqual(r.dailyMl, [100, 200, 300, 400, 500, 600, 700])   // index 6 (today) = 700
    }

    /// Midnight boundary: a log on yesterday keeps its slot; today reads 0. The rollover itself is
    /// covered by `testDayRollsOverAtLocalMidnightAuckland`.
    func testLastSevenDaysTodayResetsWhileYesterdayKeepsTotal() {
        let today = CalendarDate(2026, 7, 15)
        var y = DailyLog(); y.waterMl = 2400
        let r = HydrationInsightLogic.lastSevenDays(logByDate: [today.minusDays(1): y], goalMl: 2400, streak: 0, today: today)
        XCTAssertEqual(r.dailyMl[5], 2400)   // yesterday
        XCTAssertEqual(r.dailyMl[6], 0)      // today
        XCTAssertEqual(r.daysOnGoal, 1)
    }

    func testLastSevenDaysEmptyUsesNoWaterBranchNoCrash() {
        let r = HydrationInsightLogic.lastSevenDays(logByDate: [:], streak: 0, today: CalendarDate(2026, 7, 15))
        XCTAssertEqual(r.dailyMl, Array(repeating: 0, count: 7))
        XCTAssertEqual(r.totalMl, 0)
        XCTAssertEqual(r.daysOnGoal, 0)
        XCTAssertTrue(r.insight.contains("No water logged"))   // hasAnyWater: false branch
    }

    func testHistoryRowsShowDailyTotalsAndNeutralEmptyDays() {
        let today = CalendarDate(2026, 7, 15)
        let rows = HydrationHistoryRow.lastSevenDays(today: today, dailyMl: [0, 250, 500, 0, 1200, 2400, 3000])

        XCTAssertEqual(rows.count, 7)
        XCTAssertEqual(rows.first?.date, CalendarDate(2026, 7, 9))
        XCTAssertEqual(rows.last?.date, today)
        XCTAssertEqual(rows[0].displayTotal, "0L")
        XCTAssertEqual(rows[1].displayTotal, "0.2L")
        XCTAssertEqual(rows[5].displayTotal, "2.4L")
        XCTAssertEqual(rows.last?.dayLabel(today: today), "Today")
    }

    func testTrackHubHydrationValueMatchesRepositoryFixture() {
        let today = CalendarDate(2026, 7, 15)
        var log = DailyLog()
        log.waterMl = 1_250

        let summary = TrackSignalSummary.hydration(logs: [today: log], today: today)

        XCTAssertEqual(summary.value, "1,250 / 2,400 ml")
        XCTAssertEqual(summary.sparkValues.last ?? 0, 1_250.0 / 2_400.0, accuracy: 0.001)
    }

    func testTrackHubWeeklyBucketsMatchInsightsBuckets() {
        let today = CalendarDate(2026, 7, 16)
        let week = TrackSignalSummary.currentWeekDates(today: today)
        var logs: [CalendarDate: DailyLog] = [:]
        for (index, date) in week.enumerated() {
            logs[date] = DailyLog(sleepMinutes: (index + 1) * 60, supplements: Set(Array(LogView.supplements.prefix(index % 4))))
        }

        let sleepMinutes = week.map { logs[$0]?.sleepMinutes ?? 0 }
        let supplementCounts = week.map { logs[$0]?.supplements.count ?? 0 }
        let sleepInsights = SleepInsightLogic.compute(dailyMinutes: sleepMinutes)
        let nutritionInsights = NutritionConsistencyLogic.compute(dailyCounts: supplementCounts)

        XCTAssertEqual(sleepInsights.dailyMinutes, sleepMinutes)
        XCTAssertEqual(nutritionInsights.dailyCounts, supplementCounts)
        XCTAssertEqual(TrackSignalSummary.sleep(logs: logs, today: today).sparkValues.count, 7)
        XCTAssertEqual(TrackSignalSummary.nutrition(logs: logs, today: today).sparkValues.count, 7)
    }

    func testTrackHubEmptyStatesAreNeutral() {
        let today = CalendarDate(2026, 7, 15)

        XCTAssertEqual(TrackSignalSummary.hydration(logs: [:], today: today).value, TrackSignalSummary.emptyValue)
        XCTAssertEqual(TrackSignalSummary.sleep(logs: [:], today: today).value, TrackSignalSummary.emptyValue)
        XCTAssertEqual(TrackSignalSummary.symptoms(logs: [:], today: today).value, TrackSignalSummary.emptyValue)
        XCTAssertEqual(TrackSignalSummary.nutrition(logs: [:], today: today).value, TrackSignalSummary.emptyValue)
        XCTAssertEqual(TrackSignalSummary.ph(readings: [], today: today).value, TrackSignalSummary.emptyValue)
    }

    func testSleepRowShowsRealRepositoryValue() {
        let today = CalendarDate(2026, 7, 15)
        let logs: [CalendarDate: DailyLog] = [today: DailyLog(sleepMinutes: 455)]

        let summary = TrackSignalSummary.sleep(logs: logs, today: today)

        XCTAssertEqual(summary.value, "7h 35m")
        XCTAssertEqual(summary.sparkValues.last ?? 0, 455.0 / Double(SleepInsightLogic.chartCeilingMinutes), accuracy: 0.001)
    }

    func testSleepDetailDataReadsSameRepositoryValue() {
        let today = CalendarDate(2026, 7, 15)
        let logs: [CalendarDate: DailyLog] = [today: DailyLog(sleepMinutes: 390)]

        XCTAssertEqual(SleepTrackingData.todayMinutes(logs: logs, today: today), 390)
        XCTAssertEqual(SleepTrackingData.valueLabel(SleepTrackingData.todayMinutes(logs: logs, today: today)), "6h 30m")
        XCTAssertEqual(SleepTrackingData.lastSevenRows(logs: logs, today: today).last?.minutes, 390)
    }

    func testSleepLastSevenDaysUseOldestToTodayOrder() {
        let today = CalendarDate(2026, 7, 15)
        var logs: [CalendarDate: DailyLog] = [:]
        logs[today.minusDays(6)] = DailyLog(sleepMinutes: 360)
        logs[today.minusDays(2)] = DailyLog(sleepMinutes: 420)
        logs[today] = DailyLog(sleepMinutes: 480)

        XCTAssertEqual(SleepTrackingData.lastSevenMinutes(logs: logs, today: today), [360, 0, 0, 0, 420, 0, 480])
        let rows = SleepTrackingData.lastSevenRows(logs: logs, today: today)
        XCTAssertEqual(rows.map(\.date), (0..<7).map { today.minusDays(6 - $0) })
        XCTAssertEqual(rows.last?.dayLabel(today: today), "Today")
    }

    func testSleepDetailOnlyBuildsTrendSummaryFromRealData() {
        let today = CalendarDate(2026, 7, 15)

        XCTAssertNil(SleepTrackingData.trendSummary(logs: [:], today: today))
        XCTAssertNotNil(SleepTrackingData.trendSummary(
            logs: [today.minusDays(1): DailyLog(sleepMinutes: 420)],
            today: today))
    }

    func testSleepInsightsUseSameRepositoryBackedWeekFixture() {
        let today = CalendarDate(2026, 7, 16)
        let week = TrackSignalSummary.currentWeekDates(today: today)
        var logs: [CalendarDate: DailyLog] = [:]
        for (index, date) in week.enumerated() {
            logs[date] = DailyLog(sleepMinutes: (index + 5) * 60)
        }

        let dailyMinutes = SleepTrackingData.currentWeekMinutes(logs: logs, today: today)
        let insights = SleepInsightLogic.compute(dailyMinutes: dailyMinutes)

        XCTAssertEqual(dailyMinutes, week.map { logs[$0]?.sleepMinutes ?? 0 })
        XCTAssertEqual(insights.dailyMinutes, dailyMinutes)
        XCTAssertEqual(insights.averageMinutes, 480)
    }

    func testTrackHubTrailingSevenUsesTodayLast() {
        let today = CalendarDate(2026, 7, 15)

        XCTAssertEqual(TrackSignalSummary.trailingSeven(today: today).first, CalendarDate(2026, 7, 9))
        XCTAssertEqual(TrackSignalSummary.trailingSeven(today: today).last, today)
    }

    func testDayFillLevel() {
        XCTAssertEqual(HydrationInsightLogic.dayFillLevel(ml: 0, goalMl: 2400), 0)
        XCTAssertEqual(HydrationInsightLogic.dayFillLevel(ml: 1200, goalMl: 2400), 0.5)
        XCTAssertEqual(HydrationInsightLogic.dayFillLevel(ml: 2400, goalMl: 2400), 1)
        XCTAssertEqual(HydrationInsightLogic.dayFillLevel(ml: 100, goalMl: 0), 0)   // divide-by-zero guard
    }

    /// Injected clock + Calendar; run against Pacific/Auckland. Log at 23:59 → 00:01 rolls the day.
    func testDayRollsOverAtLocalMidnightAuckland() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        func at(_ hour: Int, _ minute: Int, day: Int) -> Date {
            var c = DateComponents(); c.year = 2026; c.month = 7; c.day = day; c.hour = hour; c.minute = minute
            return cal.date(from: c)!
        }
        XCTAssertEqual(CalendarDate.today(cal, now: at(23, 59, day: 15)), CalendarDate(2026, 7, 15))
        XCTAssertEqual(CalendarDate.today(cal, now: at(0, 1, day: 16)), CalendarDate(2026, 7, 16))
    }
}
