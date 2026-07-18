// NutritionConsistencyLogicTests.swift

import XCTest
@testable import GenesyxCore

final class NutritionConsistencyLogicTests: XCTestCase {

    func testEmptyWeekInvitesAStartNeverGuilt() {
        let m = NutritionConsistencyLogic.compute(dailyCounts: Array(repeating: 0, count: 7))
        XCTAssertEqual(m.daysLogged, 0)
        XCTAssertEqual(m.totalTaken, 0)
        XCTAssertTrue(m.insight.contains("gentle start"))
        for word in ["missed", "failed", "streak broken", "behind"] {
            XCTAssertFalse(m.insight.lowercased().contains(word), "'\(word)' guilts: \(m.insight)")
        }
    }

    func testCountsAndTotalsAreDerivedFromRealLog() {
        let m = NutritionConsistencyLogic.compute(dailyCounts: [2, 0, 4, 1, 0, 3, 0])
        XCTAssertEqual(m.daysLogged, 4)
        XCTAssertEqual(m.totalTaken, 10)
        XCTAssertEqual(m.dailyCounts, [2, 0, 4, 1, 0, 3, 0])
    }

    func testGentleRhythmCopyForAFewDays() {
        let m = NutritionConsistencyLogic.compute(dailyCounts: [1, 1, 0, 2, 0, 0, 0])
        XCTAssertEqual(m.daysLogged, 3)
        XCTAssertTrue(m.insight.contains("3 days with supplements"))
        XCTAssertTrue(m.insight.contains("gentle rhythm"))
    }

    func testSingularDayReads() {
        let m = NutritionConsistencyLogic.compute(dailyCounts: [2, 0, 0, 0, 0, 0, 0])
        XCTAssertEqual(m.daysLogged, 1)
        XCTAssertTrue(m.insight.contains("1 day with supplements"))
        XCTAssertFalse(m.insight.contains("1 days"))
    }

    func testSteadyConsistencyCopyForMostDays() {
        let m = NutritionConsistencyLogic.compute(dailyCounts: [1, 1, 1, 1, 1, 0, 0])
        XCTAssertEqual(m.daysLogged, 5)
        XCTAssertTrue(m.insight.contains("5 of 7 days"))
    }

    func testEveryDayEarnsItsOwnCopy() {
        let m = NutritionConsistencyLogic.compute(dailyCounts: [1, 2, 1, 3, 1, 4, 2])
        XCTAssertEqual(m.daysLogged, 7)
        XCTAssertTrue(m.insight.contains("every day"))
    }
}
