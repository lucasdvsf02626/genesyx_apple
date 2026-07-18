import XCTest
@testable import Genesyx
import GenesyxCore

/// Content-safety + logic guards for the Hydration Coach copy.
final class NutritionHydrationTests: XCTestCase {

    private let bannedPhrases = [
        "alkaline diet", "balance your ph", "boy or girl", "sex selection", "detox", "flush toxins",
    ]

    func testNoBannedPhrasesInCoachCopy() {
        for s in HydrationCoach.allStrings {
            let lower = s.lowercased()
            for phrase in bannedPhrases {
                XCTAssertFalse(lower.contains(phrase), "Banned phrase \"\(phrase)\" in hydration copy: \(s)")
            }
        }
    }

    func testCoachLineNamesDayPartFirst() {
        XCTAssertTrue(HydrationCoach.coachLine(hour: 7, pct: 0.2).hasPrefix("Morning"))
        XCTAssertTrue(HydrationCoach.coachLine(hour: 13, pct: 0.2).hasPrefix("Midday"))
        XCTAssertTrue(HydrationCoach.coachLine(hour: 17, pct: 0.2).hasPrefix("Afternoon"))
        XCTAssertTrue(HydrationCoach.coachLine(hour: 21, pct: 0.2).hasPrefix("Evening"))
        XCTAssertTrue(HydrationCoach.coachLine(hour: 2, pct: 0.2).hasPrefix("Late night"))
    }

    func testCoachLineSwitchesAtGoal() {
        let under = HydrationCoach.coachLine(hour: 7, pct: 0.5)
        let over = HydrationCoach.coachLine(hour: 7, pct: 1.0)
        XCTAssertNotEqual(under, over, "Copy must switch at/over goal")
        XCTAssertEqual(over, "Great start — you're already hydrated this morning.")
    }

    func testDayPartBoundaries() {
        XCTAssertEqual(HydrationCoach.DayPart.at(hour: 5), .morning)
        XCTAssertEqual(HydrationCoach.DayPart.at(hour: 11), .morning)
        XCTAssertEqual(HydrationCoach.DayPart.at(hour: 12), .midday)
        XCTAssertEqual(HydrationCoach.DayPart.at(hour: 16), .afternoon)
        XCTAssertEqual(HydrationCoach.DayPart.at(hour: 20), .evening)
        XCTAssertEqual(HydrationCoach.DayPart.at(hour: 23), .night)
        XCTAssertEqual(HydrationCoach.DayPart.at(hour: 3), .night)
    }

    func testStreakLabelIsAlwaysMotivating() {
        XCTAssertEqual(HydrationCoach.streakLabel(0), "Log streak — start today")
        XCTAssertEqual(HydrationCoach.streakLabel(1), "Day 1 — great start")
        XCTAssertEqual(HydrationCoach.streakLabel(2), "2-day log streak")
        XCTAssertEqual(HydrationCoach.streakLabel(9), "9-day log streak")
    }

    func testContextLineByPhase() {
        XCTAssertTrue(HydrationCoach.contextLine(phase: nil).contains("Log your cycle"))
        XCTAssertTrue(HydrationCoach.contextLine(phase: .period).lowercased().contains("iron"))
        for phase in Phase.allCases {
            XCTAssertFalse(HydrationCoach.contextLine(phase: phase).isEmpty)
        }
    }

    // MARK: - HydrationStatusEvaluator (PR1)

    func testExpectedPaceRampsFromEightToTwentyOne() {
        XCTAssertEqual(HydrationStatusEvaluator.expectedPace(hour: 7), 0)
        XCTAssertEqual(HydrationStatusEvaluator.expectedPace(hour: 8), 0)
        XCTAssertEqual(HydrationStatusEvaluator.expectedPace(hour: 21), 1)
        XCTAssertEqual(HydrationStatusEvaluator.expectedPace(hour: 23), 1)
        XCTAssertEqual(HydrationStatusEvaluator.expectedPace(hour: 14), 6.0 / 13.0, accuracy: 0.0001)
    }

    private func status(_ ml: Int, hour: Int) -> HydrationStatus {
        HydrationStatusEvaluator.evaluate(todayMl: ml, goalMl: 2400, hour: hour, daysOnGoal: 0, streak: 0)
    }

    func testEvaluatorTitles() {
        XCTAssertEqual(status(0, hour: 7).title, "A fresh start")
        XCTAssertEqual(status(1300, hour: 14).title, "On track")     // 0.54 ≥ pace 0.46
        XCTAssertEqual(status(300, hour: 15).title, "A little behind")
        XCTAssertEqual(status(2400, hour: 15).title, "Target reached")
        XCTAssertEqual(status(3200, hour: 15).title, "Hydration looks great")
    }

    /// O3: after 20:00 and under goal the chip must read neutral "Winding down", never "behind".
    func testEveningUnderGoalIsWindingDownNotBehind() {
        let s = status(500, hour: 21)
        XCTAssertEqual(s.title, "Winding down")
        XCTAssertEqual(s.tone, .neutral)
    }

    /// The two under-goal states must stay neutral — the Tone enum has no warning case at all.
    func testUnderGoalStatesAreNeutralTone() {
        XCTAssertEqual(status(300, hour: 15).tone, .neutral)   // "A little behind"
        XCTAssertEqual(status(500, hour: 21).tone, .neutral)   // "Winding down"
        XCTAssertEqual(status(0, hour: 7).tone, .neutral)      // "A fresh start"
    }

    /// The hard rule: focusLine is coachLine output byte-for-byte for the same inputs.
    func testFocusLineIsCoachLineVerbatim() {
        for (hour, ml) in [(7, 0), (13, 1200), (17, 2400), (21, 500), (2, 100), (10, 3000)] {
            let s = status(ml, hour: hour)
            XCTAssertEqual(s.focusLine, HydrationCoach.coachLine(hour: hour, pct: Double(ml) / 2400.0))
        }
    }
}
