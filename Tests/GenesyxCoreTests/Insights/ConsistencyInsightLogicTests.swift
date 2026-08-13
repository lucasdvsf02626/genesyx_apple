// ConsistencyInsightLogicTests.swift

import XCTest
@testable import GenesyxCore

final class ConsistencyInsightLogicTests: XCTestCase {

    /// Hydration and logging are separate arguments on purpose: this card reads only the logging
    /// pair, and a fixture that set both at once could not tell the two apart.
    private func state(
        logging: Int = 0, weekly: Int = 0, thisWeek: Int = 0, bestLogging: Int = 0,
        hydration: Int = 0, bestHydration: Int = 0,
        dots: [Bool] = Array(repeating: false, count: 7)
    ) -> StreakState {
        StreakState(dailyHydration: hydration, dailyLogging: logging, weeklyStreak: weekly,
                    daysLoggedThisWeek: thisWeek, bestDailyStreak: bestHydration,
                    bestLoggingStreak: bestLogging,
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
        let m = ConsistencyInsightLogic.model(from: state(logging: 3, weekly: 2, thisWeek: 4))
        XCTAssertEqual(m.insight, "You've logged 4 of 7 days this week — 2 steady weeks.")
    }

    func testSingularWeekCopy() {
        let m = ConsistencyInsightLogic.model(from: state(weekly: 1, thisWeek: 5))
        XCTAssertTrue(m.insight.hasSuffix("1 steady week."))
    }

    func testNoWeeklyStreakFallbackNeverGuilts() {
        let m = ConsistencyInsightLogic.model(from: state(logging: 2, thisWeek: 2))
        XCTAssertTrue(m.insight.contains("steady counts more than perfect"))
    }

    /// The card's tiles are labelled "Daily streak" and "Best daily streak" and sit directly above a
    /// row counting logged days, so both must be the logging numbers.
    func testDailyTilesReadTheLoggingStreakNotHydration() {
        let m = ConsistencyInsightLogic.model(
            from: state(logging: 12, weekly: 1, thisWeek: 7, bestLogging: 20))
        XCTAssertEqual(m.dailyStreak, 12)
        XCTAssertEqual(m.bestDailyStreak, 20)
        XCTAssertFalse(m.isEmpty)
    }

    /// `compute` can never produce this state — every watered day is also a logged day — which is
    /// precisely what makes it a clean detector: it fails, and only fails, if the card is wired back
    /// onto the hydration pair.
    func testHydrationNumbersNeverReachTheCard() {
        let m = ConsistencyInsightLogic.model(from: state(hydration: 9, bestHydration: 30))
        XCTAssertEqual(m.dailyStreak, 0)
        XCTAssertEqual(m.bestDailyStreak, 0)
        XCTAssertTrue(m.isEmpty, "nothing logged is an empty card, whatever the water says")
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
