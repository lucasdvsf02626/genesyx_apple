// ConsistencyInsightLogicTests.swift

import XCTest
@testable import GenesyxCore

final class ConsistencyInsightLogicTests: XCTestCase {

    private func state(
        daily: Int = 0, weekly: Int = 0, thisWeek: Int = 0, best: Int = 0,
        dots: [Bool] = Array(repeating: false, count: 7)
    ) -> StreakState {
        StreakState(dailyHydration: daily, weeklyStreak: weekly,
                    daysLoggedThisWeek: thisWeek, bestDailyStreak: best,
                    milestones: [], lapsedCelebrations: [], weekDots: dots)
    }

    func testEmptyStateIsDePressured() {
        let m = ConsistencyInsightLogic.model(from: state())
        XCTAssertTrue(m.isEmpty)
        XCTAssertFalse(m.insight.lowercased().contains("streak broken"))
        XCTAssertFalse(m.insight.lowercased().contains("missed"))
        XCTAssertTrue(m.insight.contains("one small entry"))
    }

    func testInsightNamesWeeklyStreakWhenPresent() {
        let m = ConsistencyInsightLogic.model(from: state(daily: 3, weekly: 2, thisWeek: 4))
        XCTAssertEqual(m.insight, "You've logged 4 of 7 days this week — 2 steady weeks.")
    }

    func testSingularWeekCopy() {
        let m = ConsistencyInsightLogic.model(from: state(weekly: 1, thisWeek: 5))
        XCTAssertTrue(m.insight.hasSuffix("1 steady week."))
    }

    func testNoWeeklyStreakFallbackNeverGuilts() {
        let m = ConsistencyInsightLogic.model(from: state(daily: 2, thisWeek: 2))
        XCTAssertTrue(m.insight.contains("steady counts more than perfect"))
    }

    // Hydration delta (§5.2)

    func testDeltaNilWhenEitherWeekEmpty() {
        XCTAssertNil(HydrationDeltaLogic.weekOverWeekLine(thisWeekMl: [2000], lastWeekMl: []))
        XCTAssertNil(HydrationDeltaLogic.weekOverWeekLine(thisWeekMl: [], lastWeekMl: [2000]))
    }

    func testPositiveNegativeAndLevelDeltas() {
        XCTAssertEqual(HydrationDeltaLogic.weekOverWeekLine(thisWeekMl: [2300], lastWeekMl: [2000]),
                       "+300ml vs last week")
        XCTAssertEqual(HydrationDeltaLogic.weekOverWeekLine(thisWeekMl: [1500], lastWeekMl: [2000]),
                       "−500ml vs last week")
        XCTAssertEqual(HydrationDeltaLogic.weekOverWeekLine(thisWeekMl: [2000], lastWeekMl: [2000]),
                       "Level with last week")
    }

    // pH context (§5.3)

    func testPhCountKeepsEarlyDaysGuard() {
        XCTAssertTrue(PhContextLogic.readingCountLine(count: 0).contains("No readings yet"))
        XCTAssertTrue(PhContextLogic.readingCountLine(count: 2).contains("early days"))
        XCTAssertEqual(PhContextLogic.readingCountLine(count: 9), "9 readings in 30 days.")
    }
}
