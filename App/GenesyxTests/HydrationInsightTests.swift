import XCTest
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
}
