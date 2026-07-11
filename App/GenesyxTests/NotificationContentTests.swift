// NotificationContentTests.swift
// Content-safety + schedule invariants (Master Implementation Doc §4, §8).

import XCTest
import GenesyxCore
@testable import Genesyx

final class NotificationContentTests: XCTestCase {

    // Same list as the Learn/Insights content-safety suite (Honesty Standard §K).
    private let bannedPhrases = [
        "alkaline diet", "balance your ph", "boy or girl", "sex selection",
        "gender sway", "sway the sex", "choose the sex", "detox", "flush toxins",
    ]

    func testEveryVisibleStringPassesBannedPhraseScan() {
        for string in NotificationContent.allVisibleStrings() {
            for phrase in bannedPhrases {
                XCTAssertFalse(string.localizedCaseInsensitiveContains(phrase),
                               "\"\(string)\" contains banned phrase \"\(phrase)\"")
            }
        }
    }

    func testNoGuiltLanguageAnywhere() {
        let guiltMarkers = ["broke your streak", "streak broken", "you missed",
                            "don't lose", "at risk", "shame", "failed"]
        for string in NotificationContent.allVisibleStrings() {
            for marker in guiltMarkers {
                XCTAssertFalse(string.localizedCaseInsensitiveContains(marker),
                               "\"\(string)\" reads as guilt: \"\(marker)\"")
            }
        }
    }

    func testScheduleMatchesTheSpecTable() {
        // Calendar weekday: 1 = Sunday … 7 = Saturday.
        XCTAssertEqual(NotificationContent.dailyHydration.schedule?.hour, 10)
        XCTAssertNil(NotificationContent.dailyHydration.schedule?.weekday) // daily

        XCTAssertEqual(NotificationContent.weeklyPh.schedule?.weekday, 2)      // Mon
        XCTAssertEqual(NotificationContent.weeklyPh.schedule?.hour, 9)

        let phase = NotificationContent.weeklyPhase(phaseName: "luteal")
        XCTAssertEqual(phase.schedule?.weekday, 4)                             // Wed
        XCTAssertEqual(phase.schedule?.hour, 8)

        XCTAssertEqual(NotificationContent.weeklyNutrition.schedule?.weekday, 6) // Fri
        XCTAssertEqual(NotificationContent.weeklyNutrition.schedule?.hour, 12)

        let learn = NotificationContent.weeklyLearn(articleSlugs: ["a"], isoWeek: 1)
        XCTAssertEqual(learn.schedule?.weekday, 1)                             // Sun
        XCTAssertEqual(learn.schedule?.hour, 9)
    }

    func testExactlyOneDailyNotificationExists() {
        // Only the hydration nudge repeats daily; everything else is weekly or one-shot.
        let daily = [NotificationContent.dailyHydration,
                     NotificationContent.weeklyPh,
                     NotificationContent.weeklyPhase(phaseName: nil),
                     NotificationContent.weeklyNutrition,
                     NotificationContent.weeklyLearn(articleSlugs: [], isoWeek: 0)]
            .filter { $0.schedule != nil && $0.schedule?.weekday == nil }
        XCTAssertEqual(daily.map(\.id), [NotificationID.dailyHydration])
    }

    func testLearnRotationCoversTheLibraryAndDeepLinks() {
        let slugs = (1...16).map { "article-\($0)" }
        var seen = Set<String>()
        for week in 0..<16 {
            let spec = NotificationContent.weeklyLearn(articleSlugs: slugs, isoWeek: week)
            guard case .learn(let slug) = spec.route, let slug else {
                return XCTFail("Learn nudge must deep-link to an article")
            }
            seen.insert(slug)
        }
        XCTAssertEqual(seen.count, 16, "16 weeks should rotate through all 16 articles")
    }

    func testLearnRotationSafeWithEmptyLibrary() {
        let spec = NotificationContent.weeklyLearn(articleSlugs: [], isoWeek: 5)
        XCTAssertEqual(spec.route, .learn(slug: nil)) // falls back to the Learn tab
    }

    func testMilestoneCopyExistsForAllFourAndTargetsInsights() {
        for m in Milestone.allCases {
            let spec = NotificationContent.milestone(m)
            XCTAssertFalse(spec.title.isEmpty)
            XCTAssertFalse(spec.body.isEmpty)
            XCTAssertEqual(spec.route, .insights)
            XCTAssertNil(spec.schedule) // one-shot
        }
    }

    func testPhaseNudgeHandlesNoCycleGracefully() {
        let spec = NotificationContent.weeklyPhase(phaseName: nil)
        XCTAssertTrue(spec.body.contains("Set up your cycle"))
    }

    func testRouteUserInfoRoundTrips() {
        let routes: [NotificationRoute] = [.home, .track, .nutrition, .insights,
                                           .learn(slug: "some-article"), .learn(slug: nil)]
        for route in routes {
            XCTAssertEqual(NotificationRoute.from(userInfo: route.userInfo), route)
        }
    }
}
