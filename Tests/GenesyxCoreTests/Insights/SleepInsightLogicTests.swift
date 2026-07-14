// SleepInsightLogicTests.swift

import XCTest
@testable import GenesyxCore

final class SleepInsightLogicTests: XCTestCase {

    func testEmptyWeekInvitesAStartNeverGuilt() {
        let m = SleepInsightLogic.compute(dailyMinutes: Array(repeating: 0, count: 7))
        XCTAssertEqual(m.nightsLogged, 0)
        XCTAssertEqual(m.averageMinutes, 0)
        XCTAssertTrue(m.insight.contains("picture build"))
        for word in ["missed", "failed", "poor", "score", "should"] {
            XCTAssertFalse(m.insight.lowercased().contains(word), "'\(word)' in: \(m.insight)")
        }
    }

    func testAverageIsOverLoggedNightsOnlyNotZeros() {
        // Two logged nights (7h and 8h); the five 0 days must not drag the mean down.
        let m = SleepInsightLogic.compute(dailyMinutes: [420, 0, 480, 0, 0, 0, 0])
        XCTAssertEqual(m.nightsLogged, 2)
        XCTAssertEqual(m.averageMinutes, 450) // (420 + 480) / 2
        XCTAssertEqual(m.dailyMinutes, [420, 0, 480, 0, 0, 0, 0])
    }

    func testSteadyRestfulRhythmCopyInBand() {
        let m = SleepInsightLogic.compute(dailyMinutes: [450, 450, 450, 450, 450, 0, 0])
        XCTAssertEqual(m.averageMinutes, 450)
        XCTAssertTrue(m.insight.contains("7h 30m"))
        XCTAssertTrue(m.insight.contains("steady, restful"))
    }

    func testShortAveragesGetGentleNotAlarmingCopy() {
        let m = SleepInsightLogic.compute(dailyMinutes: [300, 330, 0, 0, 0, 0, 0])
        XCTAssertEqual(m.averageMinutes, 315) // 5h15m
        XCTAssertTrue(m.insight.contains("rest where the day allows"))
    }

    func testSingularNightReads() {
        let m = SleepInsightLogic.compute(dailyMinutes: [480, 0, 0, 0, 0, 0, 0])
        XCTAssertTrue(m.insight.contains("1 night"))
        XCTAssertFalse(m.insight.contains("1 nights"))
    }

    func testDurationLabelDropsZeroMinutes() {
        XCTAssertEqual(SleepInsightLogic.durationLabel(420), "7h")
        XCTAssertEqual(SleepInsightLogic.durationLabel(445), "7h 25m")
    }
}
