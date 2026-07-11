import XCTest
@testable import Genesyx
import GenesyxCore

/// Content safety and the two decisions the notification system makes: when the daily hydration
/// nudge should fire, and where a tap lands.
final class NotificationTests: XCTestCase {

    // MARK: - Content safety

    /// Nothing we send may make a medical claim or imply the app influences an outcome.
    private static let bannedPhrases = [
        "alkaline diet", "balance your ph", "boy or girl", "sex selection", "gender sway",
        "sway the sex", "choose the sex", "detox", "flush toxins",
    ]

    /// Nor may it guilt her. A missed day costs almost nothing — that's the brand contract, and a
    /// "you broke your streak" push would be the fastest way to break it.
    private static let guiltPhrases = ["broke", "broken", "failed", "don't lose", "you missed", "streak is over"]

    func testNoBannedPhrasesInAnyNotificationCopy() {
        for copy in NotificationContent.allCopyStrings {
            let lowered = copy.lowercased()
            for phrase in Self.bannedPhrases {
                XCTAssertFalse(lowered.contains(phrase), "Banned phrase '\(phrase)' in: \(copy)")
            }
        }
    }

    func testNoGuiltInAnyNotificationCopy() {
        for copy in NotificationContent.allCopyStrings {
            let lowered = copy.lowercased()
            for phrase in Self.guiltPhrases {
                XCTAssertFalse(lowered.contains(phrase), "Guilt phrase '\(phrase)' in: \(copy)")
            }
        }
    }

    func testEveryMilestoneHasCopy() {
        for milestone in Milestone.allCases {
            XCTAssertFalse(NotificationContent.milestoneTitle(milestone).isEmpty)
            XCTAssertFalse(NotificationContent.milestoneBody(milestone).isEmpty)
            XCTAssertTrue(NotificationKind(milestone: milestone).rawValue.hasPrefix("genesyx.milestone."))
        }
    }

    // MARK: - The daily hydration rule (nudge only on days she hasn't started)

    private func date(_ hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026; components.month = 7; components.day = 12
        components.hour = hour; components.minute = minute
        return Calendar.current.date(from: components)!
    }

    func testHydrationNudgeFiresTodayWhenNothingIsLoggedYet() {
        let fire = NotificationService.nextHydrationFire(now: date(8), hour: 10, loggedToday: false)
        XCTAssertEqual(fire, date(10))
    }

    /// The one the doc asks for: she logged water, so today's nudge is not sent at all.
    func testHydrationNudgeSkipsTodayOnceWaterIsLogged() {
        let fire = NotificationService.nextHydrationFire(now: date(8), hour: 10, loggedToday: true)
        XCTAssertEqual(fire, date(10).addingTimeInterval(86_400), "she's already started — wait for tomorrow")
    }

    /// No evening follow-up: once 10:00 has passed unanswered, the next one is tomorrow morning.
    func testHydrationNudgeDoesNotChaseHerLaterTheSameDay() {
        let fire = NotificationService.nextHydrationFire(now: date(18), hour: 10, loggedToday: false)
        XCTAssertEqual(fire, date(10).addingTimeInterval(86_400))
    }

    // MARK: - Learn rotation

    func testLearnRotationIsDeterministicAndInRange() {
        XCTAssertEqual(
            NotificationContent.rotatingLearnArticle(isoWeek: 7).slug,
            NotificationContent.rotatingLearnArticle(isoWeek: 7).slug
        )
        XCTAssertNotEqual(
            NotificationContent.rotatingLearnArticle(isoWeek: 7).slug,
            NotificationContent.rotatingLearnArticle(isoWeek: 8).slug
        )
        // Week numbers wrap without trapping.
        XCTAssertNotNil(NotificationContent.rotatingLearnArticle(isoWeek: 53))
        XCTAssertNotNil(NotificationContent.rotatingLearnArticle(isoWeek: 0))
    }

    // MARK: - Tap routing

    func testLearnTapCarriesTheArticleSlug() {
        let payload = NotificationRouter.payload(tab: .learn, learnSlug: "first-week")
        let destination = NotificationRouter.destination(from: payload)

        XCTAssertEqual(destination, NotificationRouter.Destination(tab: .learn, learnSlug: "first-week"))
    }

    func testMilestoneTapLandsOnInsights() {
        let destination = NotificationRouter.destination(from: NotificationRouter.payload(tab: .insights))

        XCTAssertEqual(destination?.tab, .insights)
        XCTAssertNil(destination?.learnSlug)
    }

    func testAnUnknownPayloadRoutesNowhere() {
        XCTAssertNil(NotificationRouter.destination(from: ["something": "else"]))
    }
}
