// WaterChallengeTests.swift

import XCTest
@testable import GenesyxCore

private struct FakeDay: TrackingLoggable {
    var waterMl: Int
    var isMeaningfulLog: Bool { waterMl > 0 }
}

final class WaterChallengeTests: XCTestCase {

    private let monday = CalendarDate(year: 2026, month: 7, day: 6)
    private let goal = TrackingEngine.defaultWaterGoalMl

    private func days(_ offsets: [Int], ml: Int) -> [CalendarDate: FakeDay] {
        Dictionary(uniqueKeysWithValues: offsets.map { (monday.addingDays(-$0), FakeDay(waterMl: ml)) })
    }

    private func state(_ logs: [CalendarDate: FakeDay], today: CalendarDate? = nil) -> WaterChallengeState {
        WaterChallenge.state(logsByDate: logs, goalMl: goal, today: today ?? monday)
    }

    func testNoHistoryStartsAtZeroOfSeven() {
        let s = state([:])
        XCTAssertEqual(s.daysDone, 0)
        XCTAssertEqual(s.target, 7)
        XCTAssertFalse(s.isComplete)
        XCTAssertEqual(s.progressLabel, "0 of 7 days")
    }

    func testCountsConsecutiveDaysAtOrAboveGoal() {
        XCTAssertEqual(state(days([0, 1, 2], ml: goal)).daysDone, 3)
        XCTAssertEqual(state(days([0, 1, 2], ml: goal + 500)).daysDone, 3)
    }

    /// The challenge is "at your goal", not "logged something". A day of three glasses is a day on
    /// the hydration streak and not a day on this.
    func testADayShortOfGoalDoesNotCount() {
        XCTAssertEqual(state(days([0, 1, 2], ml: goal - 1)).daysDone, 0)
    }

    func testAMissedDayReturnsTheCountToZeroWithoutScolding() {
        var logs = days([2, 3, 4], ml: goal)   // ends two days ago
        logs[monday] = FakeDay(waterMl: 0)
        let s = state(logs)
        XCTAssertEqual(s.daysDone, 0)
        XCTAssertEqual(s.detail, "Reach 2.4L today and day one is done.")
    }

    /// Same grace as every other streak: at 8am, before she has drunk anything, a run that reached
    /// yesterday still reads at full length. Without it the card would reset itself every night and
    /// ask her to start over each morning.
    func testMorningGraceKeepsYesterdaysRun() {
        XCTAssertEqual(state(days([1, 2, 3], ml: goal)).daysDone, 3)
    }

    func testSevenConsecutiveDaysCompletesTheChallenge() {
        let s = state(days(Array(0..<7), ml: goal))
        XCTAssertEqual(s.daysDone, 7)
        XCTAssertTrue(s.isComplete)
        XCTAssertEqual(s.progressLabel, "7 of 7 days")
        XCTAssertEqual(s.detail, "Seven days at your goal — challenge complete.")
    }

    /// An eighth day extends the run rather than opening a second challenge to keep books on — the
    /// reason this type persists nothing at all.
    func testRunBeyondSevenStaysCompleteAndCapsTheProgress() {
        let s = state(days(Array(0..<11), ml: goal))
        XCTAssertEqual(s.daysDone, 7, "progress is capped so the dot row can't overflow")
        XCTAssertTrue(s.isComplete)
        XCTAssertEqual(s.detail, "Challenge complete, and 11 days running.")
    }

    func testRemainingDaysCopyIsSingularAtSix() {
        XCTAssertEqual(state(days(Array(0..<6), ml: goal)).detail, "One more day at 2.4L to finish.")
        XCTAssertEqual(state(days(Array(0..<5), ml: goal)).detail, "2 more days at 2.4L to finish.")
    }

    /// Same guards as the rest of the hydration copy, and no guilt: a run that has just ended reads
    /// the same as one that never started.
    func testCopyIsCleanAndNeverScolds() {
        let banned = ["alkaline diet", "balance your ph", "boy or girl", "sex selection",
                      "detox", "flush toxins"]
        let guilt = ["missed", "failed", "you broke", "should have", "behind", "don't forget"]
        for line in WaterChallenge.allStrings() {
            let lower = line.lowercased()
            for phrase in banned {
                XCTAssertFalse(lower.contains(phrase), "Banned phrase \"\(phrase)\" in: \(line)")
            }
            for phrase in guilt {
                XCTAssertFalse(lower.contains(phrase), "Guilt phrase \"\(phrase)\" in: \(line)")
            }
        }
    }

    func testCopyTracksTheGoalRatherThanHardcodingIt() {
        XCTAssertEqual(WaterChallenge.detail(run: 0, goalMl: 2000), "Reach 2.0L today and day one is done.")
    }
}
