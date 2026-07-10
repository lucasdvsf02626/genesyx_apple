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

    func testContextLineByPhase() {
        XCTAssertTrue(HydrationCoach.contextLine(phase: nil).contains("Log your cycle"))
        XCTAssertTrue(HydrationCoach.contextLine(phase: .period).lowercased().contains("iron"))
        for phase in Phase.allCases {
            XCTAssertFalse(HydrationCoach.contextLine(phase: phase).isEmpty)
        }
    }
}
