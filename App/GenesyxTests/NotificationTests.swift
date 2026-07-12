import XCTest
@testable import Genesyx
import GenesyxCore

/// The app-side half of the notification system: content safety across everything the planner can
/// reach, when the hydration nudge actually fires, and where a tap lands. The planner's own rules
/// are covered by `NotificationPlannerTests` in GenesyxCore.
final class NotificationTests: XCTestCase {

    // MARK: - Content safety

    /// Nothing we send may make a medical claim or imply the app influences an outcome.
    private static let bannedPhrases = [
        "alkaline diet", "balance your ph", "boy or girl", "sex selection", "gender sway",
        "sway the sex", "choose the sex", "detox", "flush toxins",
    ]

    /// Nor may it guilt her. A missed day costs almost nothing — that's the brand contract, and a
    /// "you broke your streak" push would be the fastest way to break it.
    private static let guiltPhrases = ["you broke", "you failed", "you missed", "don't lose", "streak is over"]

    func testNoBannedPhraseInAnySentenceTheAppCanSend() {
        for copy in NotificationContent.allCopyStrings {
            let lowered = copy.lowercased()
            for phrase in Self.bannedPhrases {
                XCTAssertFalse(lowered.contains(phrase), "Banned phrase '\(phrase)' in: \(copy)")
            }
        }
    }

    func testNoGuiltInAnySentenceTheAppCanSend() {
        for copy in NotificationContent.allCopyStrings {
            let lowered = copy.lowercased()
            for phrase in Self.guiltPhrases {
                XCTAssertFalse(lowered.contains(phrase), "Guilt phrase '\(phrase)' in: \(copy)")
            }
        }
    }

    func testEveryMilestoneHasCopyAndAnId() {
        for milestone in Milestone.allCases {
            XCTAssertFalse(NotificationContent.milestoneTitle(milestone).isEmpty)
            XCTAssertFalse(NotificationContent.milestoneBody(milestone).isEmpty)
            XCTAssertTrue(NotificationKind(milestone: milestone).rawValue.hasPrefix("genesyx.milestone."))
        }
    }

    /// Build 9 scheduled a nutrition and a phase nudge. They're retired, but their IDs must survive
    /// so an upgrading app can still cancel what it already scheduled.
    func testRetiredIdsSurviveSoTheyCanBeCancelled() {
        let ids = NotificationKind.allCases.map(\.rawValue)
        XCTAssertTrue(ids.contains("genesyx.weekly.nutrition"))
        XCTAssertTrue(ids.contains("genesyx.weekly.phase"))
    }

    func testEverySlotHasItsOwnStableId() {
        let ids = NotificationSlot.allCases.map { NotificationKind(slot: $0).rawValue }
        XCTAssertEqual(Set(ids).count, NotificationSlot.allCases.count)
    }

    // MARK: - When the hydration nudge fires

    private func date(_ day: Int, _ hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026; components.month = 7; components.day = day
        components.hour = hour; components.minute = 0
        return Calendar.current.date(from: components)!
    }

    func testHydrationNudgeFiresTodayWhenNothingIsLoggedYet() {
        let fire = NotificationService.nextHydrationFire(now: date(13, 8), hour: 10, loggedToday: false)
        XCTAssertEqual(fire, date(13, 10))
    }

    /// The rule that matters: she logged water, so today's nudge is not sent at all.
    func testHydrationNudgeSkipsTodayOnceWaterIsLogged() {
        let fire = NotificationService.nextHydrationFire(now: date(13, 8), hour: 10, loggedToday: true)
        XCTAssertEqual(fire, date(14, 10), "she's already started — wait for tomorrow")
    }

    /// No evening chase: once 10:00 has passed unanswered, the next one is tomorrow morning.
    func testHydrationNudgeDoesNotChaseHerLaterTheSameDay() {
        let fire = NotificationService.nextHydrationFire(now: date(13, 18), hour: 10, loggedToday: false)
        XCTAssertEqual(fire, date(14, 10))
    }

    /// Invariant 2 — one a day. 2026-07-14 is a Tuesday (ISO 2); hydration steps over it.
    func testHydrationStandsDownOnADayAWeeklyNudgeOwns() {
        let fire = NotificationService.nextHydrationFire(
            now: date(13, 18), hour: 10, loggedToday: false, restDays: [2])

        XCTAssertEqual(fire, date(15, 10), "Tuesday belongs to a weekly nudge — take Wednesday")
    }

    func testIsoWeekdayMapsMondayToOne() {
        XCTAssertEqual(NotificationService.isoWeekday(of: date(13, 9)), 1)   // Mon 13 Jul 2026
        XCTAssertEqual(NotificationService.isoWeekday(of: date(19, 9)), 7)   // Sun 19 Jul 2026
    }

    func testNextOccurrenceFindsTheComingWeekday() {
        let next = NotificationService.nextOccurrence(isoWeekday: 3, hour: 8, now: date(13, 12))
        XCTAssertEqual(next, date(15, 8), "Wednesday 08:00")
    }

    // MARK: - Tap routing

    func testLearnTapCarriesTheArticleSlug() {
        let payload = NotificationRouter.payload(tab: .learn, learnSlug: "first-week")
        XCTAssertEqual(NotificationRouter.destination(from: payload),
                       NotificationRouter.Destination(tab: .learn, learnSlug: "first-week"))
    }

    func testMilestoneTapLandsOnInsights() {
        let destination = NotificationRouter.destination(from: NotificationRouter.payload(tab: .insights))
        XCTAssertEqual(destination?.tab, .insights)
        XCTAssertNil(destination?.learnSlug)
    }

    func testAnUnknownPayloadRoutesNowhere() {
        XCTAssertNil(NotificationRouter.destination(from: ["something": "else"]))
    }

    /// The planner's target and the app's tab are two enums that must not drift apart.
    func testPlannerTargetsMapOntoRealTabs() {
        for target in [NotificationTarget.home, .track, .nutrition, .insights, .learn, .profile] {
            XCTAssertNotNil(NotificationTab(rawValue: target.rawValue))
        }
    }

    // MARK: - Learn read log

    func testAnArticleSheHasOpenedIsNotOfferedAgain() {
        let slug = "test-\(UUID().uuidString)"
        XCTAssertFalse(LearnReadLog.readSlugs.contains(slug))

        LearnReadLog.markRead(slug)

        XCTAssertTrue(LearnReadLog.readSlugs.contains(slug))
    }
}
