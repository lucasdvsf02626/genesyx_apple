import XCTest
@testable import Genesyx

/// Content-safety + integrity guards for the Learn library (parity with Android `LearnContentTest`).
final class LearnContentTests: XCTestCase {

    /// Banned claim phrases. Deliberately specific so the debunking prose in the articles
    /// (e.g. "the sex of any future child are not influenced by what you eat") does NOT trip them.
    private let bannedPhrases = [
        "boy or girl",
        "sex selection",
        "gender selection",
        "gender sway",
        "sway the sex",
        "choose the sex",
        "alkaline diet",
        "balance your ph",
    ]

    private func blockTexts(_ block: ArticleBlock) -> [String] {
        switch block {
        case .heading(let t), .paragraph(let t), .callout(let t): return [t]
        case .bulletList(let items): return items
        }
    }

    /// Everything a reader can see, per article: title, excerpt, tags, CTA label, every body block.
    private func scannableStrings(_ a: LearnArticle) -> [String] {
        var out = [a.title, a.excerpt]
        out += a.tags
        if let cta = a.cta { out.append(cta.label) }
        out += a.body.flatMap(blockTexts)
        return out
    }

    func testNoBannedPhrasesAnywhere() {
        for a in LearnLibrary.articles {
            for s in scannableStrings(a) {
                let lower = s.lowercased()
                for phrase in bannedPhrases {
                    XCTAssertFalse(lower.contains(phrase),
                        "Banned phrase \"\(phrase)\" found in article \(a.slug): \(s)")
                }
            }
        }
    }

    func testDisclaimerPinnedToExactSixSlugs() {
        let expected: Set<String> = [
            "hydration-basics",
            "eating-with-your-cycle",
            "gentle-guide-supplements",
            "reading-your-trends",
            "small-habits-that-hold",
            "using-what-you-learn",
        ]
        let actual = Set(LearnLibrary.articles.filter { $0.disclaimerRequired }.map { $0.slug })
        XCTAssertEqual(actual, expected, "Medical disclaimer must be pinned to exactly these six slugs")
    }

    func testArticleCtaRequiresTarget() {
        XCTAssertNil(ArticleCta(type: .openArticle, label: "x", targetSlug: nil),
                     "openArticle CTA with no target must fail construction")
        XCTAssertNil(ArticleCta(type: .openArticle, label: "x", targetSlug: ""),
                     "openArticle CTA with empty target must fail construction")
        XCTAssertNotNil(ArticleCta(type: .openArticle, label: "x", targetSlug: "getting-started-first-week"))
        XCTAssertNotNil(ArticleCta(type: .openLog, label: "x"))
    }

    func testLibraryIntegrity() {
        let articles = LearnLibrary.articles
        XCTAssertEqual(articles.count, 10, "Exactly ten bundled articles")
        XCTAssertEqual(articles.filter { $0.featured }.count, 1, "Exactly one featured article")
        XCTAssertEqual(Set(articles.map { $0.slug }).count, 10, "Slugs must be unique")
        XCTAssertEqual(Set(articles.map { $0.id }).count, 10, "Ids must be unique")
        for a in articles {
            for id in a.relatedArticleIds {
                XCTAssertNotNil(LearnLibrary.articleById(id),
                    "Related id \(id) in \(a.slug) must resolve to a real article")
            }
        }
    }

    func testSearchMatchesTitleExcerptAndTags() {
        XCTAssertFalse(LearnLibrary.search("hydration").isEmpty, "Should match a title/tag")
        XCTAssertFalse(LearnLibrary.search("memory").isEmpty, "Should match an excerpt/tag word")
        XCTAssertTrue(LearnLibrary.search("").isEmpty, "Empty query returns nothing")
        XCTAssertTrue(LearnLibrary.search("zzzznotathing").isEmpty, "No spurious matches")
    }

    func testFeaturedIsFirstWeek() {
        XCTAssertEqual(LearnLibrary.featured?.slug, "getting-started-first-week")
    }
}
