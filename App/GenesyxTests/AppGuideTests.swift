import GenesyxCore
import XCTest
@testable import Genesyx

/// Guards for the in-app "How to use Genesyx" signposting.
///
/// The failure this file exists to prevent is silent. Every route into an explainer resolves through
/// `LearnLibrary.articles`, which withholds anything dated in the future, so a slug can be spelled
/// perfectly and still land her on the "unavailable" screen — or, in the hub, on a row that simply
/// is not drawn. Nothing crashes and nothing looks broken in review; she just cannot get an answer.
final class AppGuideTests: XCTestCase {

    // MARK: The hub

    func testEveryGuideInTheHubIsOneSheCanActuallyOpen() {
        for entry in AppGuide.entries {
            XCTAssertNotNil(LearnLibrary.allArticles.first { $0.slug == entry.slug },
                            "the \(entry.tab) hub lists \"\(entry.slug)\", which is not an article at all")
            XCTAssertNotNil(LearnLibrary.articleBySlug(entry.slug),
                            "the \(entry.tab) hub lists \"\(entry.slug)\", which is not published yet — "
                            + "the row would vanish from the index without anything failing")
        }
    }

    /// Stronger than "published today": a date-gated guide is published on every day *after* its
    /// date and missing on every day before, so a suite run after the reveal would pass while the
    /// shipped build was still hiding the row.
    func testTheHubDependsOnNoPublicationDate() {
        for entry in AppGuide.entries {
            XCTAssertNil(LearnLibrary.articleBySlug(entry.slug)?.publishedAt,
                         "\"\(entry.slug)\" is date-gated; the hub is shown from day one and must "
                         + "only list guides that are too")
        }
    }

    func testTheHubCoversEveryTabThatCarriesAnInlineSignpost() {
        let tabs = Set(AppGuide.entries.map(\.tab))
        for tab in ["Home", "Track", "pH", "Nutrition", "Insights"] {
            XCTAssertTrue(tabs.contains(tab), "\(tab) has no entry in the hub")
        }
    }

    func testTheHubListsEachGuideOnce() {
        let slugs = AppGuide.entries.map(\.slug)
        XCTAssertEqual(slugs.count, Set(slugs).count, "a guide is listed twice in the hub")
    }

    /// `byTab` is what the screen draws. Building it from `entries` is the point — this asserts the
    /// derivation actually loses nothing, so adding a row cannot fail to appear.
    func testEveryEntryIsDrawnByTheGroupingTheScreenUses() {
        let drawn = AppGuide.byTab.flatMap(\.entries).map(\.slug)
        XCTAssertEqual(drawn.sorted(), AppGuide.entries.map(\.slug).sorted(),
                       "the grouped view drops or duplicates entries")
        for group in AppGuide.byTab {
            XCTAssertTrue(group.entries.allSatisfy { $0.tab == group.tab },
                          "the \(group.tab) group contains a guide belonging to another tab")
        }
    }

    // MARK: The inline "How this works" links

    func testEveryTabSignpostOpensAPublishedGuide() {
        for slug in AppGuide.tabSignposts {
            XCTAssertNotNil(LearnLibrary.articleBySlug(slug),
                            "a tab signposts \"\(slug)\", which is not a published article — "
                            + "the link would open a blank screen")
            XCTAssertNil(LearnLibrary.articleBySlug(slug)?.publishedAt,
                         "the \"\(slug)\" signpost is shown from day one and must not be date-gated")
        }
    }

    /// The inline links are the shortcut; the hub is the index. A tab pointing at something the
    /// index does not list means one of the two was edited alone.
    func testEveryTabSignpostIsAlsoInTheHub() {
        let listed = Set(AppGuide.entries.map(\.slug))
        for slug in AppGuide.tabSignposts + [PhTabView.learnArticleSlug] {
            XCTAssertTrue(listed.contains(slug),
                          "a tab links to \"\(slug)\" but the hub does not list it")
        }
    }

    // MARK: Routing

    /// `HowToUseView.route` is appended to the same `[String]` navigation path the articles use.
    /// If it ever equalled a slug, opening the hub would open that article instead.
    func testTheHubRouteCannotBeMistakenForAnArticle() {
        XCTAssertNil(LearnLibrary.allArticles.first { $0.slug == HowToUseView.route },
                     "the hub route collides with an article slug")
        XCTAssertNotEqual(HowToUseView.route, TwelveWeekPlan.route,
                          "the hub and the 12-week plan share a route")
    }
}
