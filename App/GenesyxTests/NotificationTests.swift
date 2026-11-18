import XCTest
import UserNotifications
@testable import Genesyx

@MainActor
final class NotificationTests: XCTestCase {

    private let bannedPhrases = [
        "boy or girl", "sex selection", "gender selection", "gender sway",
        "sway the sex", "choose the sex", "alkaline diet", "balance your ph",
    ]

    // MARK: Content safety

    func testNoBannedPhrasesInNotificationCopy() {
        for s in NotificationContent.allCopyStrings {
            let lower = s.lowercased()
            for phrase in bannedPhrases {
                XCTAssertFalse(lower.contains(phrase), "Banned phrase \"\(phrase)\" in notification copy: \(s)")
            }
        }
    }

    // MARK: Weekly schedule

    func testWeeklyRequestsAreFourWithStableUniqueIDs() {
        let reqs = NotificationService.weeklyRequests(phaseLabel: "Follicular", learnArticle: learnArticles[0])
        XCTAssertEqual(reqs.count, 4)
        let ids = Set(reqs.map(\.identifier))
        XCTAssertEqual(ids.count, 4, "IDs must be unique")
        XCTAssertTrue(ids.contains(NotificationKind.weeklyPh.rawValue))
        XCTAssertTrue(ids.contains(NotificationKind.weeklyPhase.rawValue))
        XCTAssertTrue(ids.contains(NotificationKind.weeklyNutrition.rawValue))
        XCTAssertTrue(ids.contains(NotificationKind.weeklyLearn.rawValue))
    }

    func testReschedulingUsesTheSameIDs() {
        let a = NotificationService.weeklyRequests(phaseLabel: "Follicular", learnArticle: learnArticles[0])
        let b = NotificationService.weeklyRequests(phaseLabel: nil, learnArticle: learnArticles[3])
        XCTAssertEqual(Set(a.map(\.identifier)), Set(b.map(\.identifier)),
                       "Re-scheduling must reuse identifiers so add() replaces rather than duplicates")
    }

    func testLearnRequestCarriesSlugForDeepLink() {
        let article = learnArticles[2]
        let reqs = NotificationService.weeklyRequests(phaseLabel: nil, learnArticle: article)
        let learn = reqs.first { $0.identifier == NotificationKind.weeklyLearn.rawValue }
        XCTAssertEqual(learn?.content.userInfo["slug"] as? String, article.slug)
        XCTAssertEqual(learn?.content.userInfo["tab"] as? Int, NotificationTab.learn.rawValue)
    }

    // MARK: Streak milestones (pure logic)

    func testSevenDayFiresOnceThenNot() {
        let first = NotificationService.milestoneDecision(streak: 7, sent7: false, sent14: false)
        XCTAssertTrue(first.fire7); XCTAssertTrue(first.sent7); XCTAssertFalse(first.fire14)
        let again = NotificationService.milestoneDecision(streak: 7, sent7: true, sent14: false)
        XCTAssertFalse(again.fire7, "Staying at 7 must not re-fire")
    }

    func testBreakResetsThenRefires() {
        let broken = NotificationService.milestoneDecision(streak: 0, sent7: true, sent14: true)
        XCTAssertFalse(broken.sent7); XCTAssertFalse(broken.sent14); XCTAssertFalse(broken.fire7)
        let rehit = NotificationService.milestoneDecision(streak: 7, sent7: broken.sent7, sent14: broken.sent14)
        XCTAssertTrue(rehit.fire7, "Re-achieving 7 after a break must fire again")
    }

    func testFourteenFiresOnce() {
        let d = NotificationService.milestoneDecision(streak: 14, sent7: true, sent14: false)
        XCTAssertTrue(d.fire14); XCTAssertTrue(d.sent14); XCTAssertFalse(d.fire7)
    }

    func testOpeningAtNineFiresSevenNotFourteen() {
        let d = NotificationService.milestoneDecision(streak: 9, sent7: false, sent14: false)
        XCTAssertTrue(d.fire7); XCTAssertFalse(d.fire14)
    }

    // MARK: Learn rotation

    func testLearnRotationIsDeterministicAndInRange() {
        for week in [0, 1, 10, 53, 100] {
            let article = NotificationContent.rotatingLearnArticle(isoWeek: week)
            XCTAssertTrue(learnArticles.contains { $0.slug == article.slug })
        }
        XCTAssertEqual(NotificationContent.rotatingLearnArticle(isoWeek: 0).slug,
                       NotificationContent.rotatingLearnArticle(isoWeek: 10).slug)
    }
}
