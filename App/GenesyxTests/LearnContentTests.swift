import GenesyxCore
import XCTest
@testable import Genesyx
#if canImport(UIKit)
import UIKit
#endif

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

    /// Scans `allArticles`, NOT `articles`. The weekly series is compiled in months before it is
    /// revealed, and a guard that only saw the published set would leave every unreleased piece
    /// unchecked until the day it shipped to readers — which is exactly the day it is too late.
    func testNoBannedPhrasesAnywhere() {
        for a in LearnLibrary.allArticles {
            for s in scannableStrings(a) {
                let lower = s.lowercased()
                for phrase in bannedPhrases {
                    XCTAssertFalse(lower.contains(phrase),
                        "Banned phrase \"\(phrase)\" found in article \(a.slug): \(s)")
                }
            }
        }
    }

    func testDisclaimerPinnedToExactSlugs() {
        let expected: Set<String> = [
            "hydration-basics",
            "eating-with-your-cycle",
            "gentle-guide-supplements",
            "reading-your-trends",
            "small-habits-that-hold",
            "using-what-you-learn",
            // Health-adjacent guides (A, C, D, F) also carry the disclaimer.
            "guide-vaginal-ph-tracker",
            "guide-how-to-log-ph",
            "guide-nutrition-focus",
            "guide-track-ph-in-nutrition",
            // The weekly series: every piece states external health facts, so every piece carries it.
            "fertile-window",
            "vaginal-ph-explained",
            "nutrition-before-conception",
            "cervical-mucus",
            "hydration-and-reproductive-health",
            "timing-sex-when-ttc",
            "sleep-stress-and-your-cycle",
            "understanding-ovulation-tests",
            "supporting-sperm-health",
            "fertility-supplements-explained",
            "when-to-ask-for-support",
        ]
        let actual = Set(LearnLibrary.allArticles.filter { $0.disclaimerRequired }.map { $0.slug })
        XCTAssertEqual(actual, expected, "Medical disclaimer must be pinned to exactly these slugs (6 articles + 4 guides + 11 weekly)")
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
        let articles = LearnLibrary.allArticles
        XCTAssertEqual(articles.count, 27, "Ten articles + six guides + eleven weekly")
        XCTAssertEqual(articles.filter { $0.featured }.count, 1, "Exactly one featured article")
        XCTAssertEqual(Set(articles.map { $0.slug }).count, 27, "Slugs must be unique")
        XCTAssertEqual(Set(articles.map { $0.id }).count, 27, "Ids must be unique")
        let byId = Dictionary(uniqueKeysWithValues: articles.map { ($0.id, $0) })
        for a in articles {
            for id in a.relatedArticleIds {
                XCTAssertNotNil(byId[id],
                    "Related id \(id) in \(a.slug) must resolve to a real article")
            }
        }
    }

    // MARK: - Citations (Guideline 1.4.1)

    /// `SourcesFooter` renders nothing for an id that does not resolve — no fallback, no crash.
    /// So a typo in a source id costs an article a citation it claims to have, and the only
    /// symptom is a shorter list nobody counted. This is that count.
    func testEveryCitedSourceIdResolves() {
        let store = MedicalSourceStore.shared
        XCTAssertFalse(store.sources.isEmpty, "medical_sources.json failed to load in the test bundle")
        for (slug, ids) in LearnSourceMap.bySlug {
            XCTAssertFalse(ids.isEmpty, "\(slug) has a Sources footer with nothing in it")
            for id in ids {
                XCTAssertNotNil(store.source(id),
                    "Source id \"\(id)\" cited by \(slug) is not in medical_sources.json")
            }
        }
    }

    /// A citation keyed to a slug that no longer exists is dead weight that reads as coverage.
    func testEveryCitationKeyIsARealArticle() {
        let slugs = Set(LearnLibrary.allArticles.map(\.slug))
        for slug in LearnSourceMap.bySlug.keys {
            XCTAssertTrue(slugs.contains(slug),
                "LearnSourceMap cites \"\(slug)\", which is not an article")
        }
    }

    /// Every piece in the weekly series states external health facts, so every piece must ship
    /// already cited. They are withheld by date, not by readiness — there is no later pass.
    func testEveryWeeklyArticleIsCited() {
        let weekly = LearnLibrary.allArticles.filter { $0.publishedAt != nil }
        XCTAssertEqual(weekly.count, 11)
        for a in weekly {
            XCTAssertNotNil(LearnSourceMap.sources(for: a.slug),
                "Weekly article \(a.slug) makes health claims but carries no sources")
        }
    }

    #if canImport(UIKit)
    /// `LearnHero` falls back to a category gradient when an asset is missing, so a mistyped name
    /// costs an article its artwork without failing anything — the piece just quietly looks
    /// unfinished, and only on the day it is revealed. Same lookup the view performs.
    func testEveryHeroImageAssetExists() {
        for a in LearnLibrary.allArticles {
            guard let name = a.heroImage else { continue }
            XCTAssertNotNil(UIImage(named: name),
                "Missing hero asset \"\(name)\" for \(a.slug)")
        }
    }
    #endif

    // MARK: - Weekly drip

    /// The series is shipped in one build and revealed by date. These pin the gate, because the
    /// failure modes are silent in both directions: a wrong date either leaks eleven articles at
    /// once or withholds one forever, and neither shows up as a crash.

    func testUndatedArticlesAreAlwaysVisible() {
        let longAgo = CalendarDate(2020, 1, 1)
        let visible = Set(LearnLibrary.published(asOf: longAgo).map(\.slug))
        let undated = Set(LearnLibrary.allArticles.filter { $0.publishedAt == nil }.map(\.slug))
        XCTAssertEqual(visible, undated, "Before the series starts, only the original library shows")
        XCTAssertEqual(undated.count, 16, "The original library is the sixteen that predate the series")
    }

    func testSeriesRevealsOneArticlePerWeek() {
        let dated = LearnLibrary.allArticles
            .compactMap { $0.publishedAt }
            .sorted()
        XCTAssertEqual(dated.count, 11, "Eleven dated articles")
        XCTAssertEqual(Set(dated).count, 11, "No two articles share a publish date — one drop per week")
        for (a, b) in zip(dated, dated.dropFirst()) {
            XCTAssertEqual(b.dayNumber - a.dayNumber, 7, "Consecutive drops must be exactly a week apart")
        }
    }

    /// Sunday, because `NotificationPlanner.learnWeekday` is 7 and the nudge fires at 09:00 — an
    /// article published any other day is announced late, or announced before it exists.
    func testEveryDropLandsOnASunday() {
        for date in LearnLibrary.allArticles.compactMap({ $0.publishedAt }) {
            XCTAssertEqual(date.weekdaySundayZero, 0,
                "Drop on \(date.year)-\(date.month)-\(date.day) must be a Sunday to match the Learn nudge")
        }
    }

    func testDropIsVisibleOnItsDayAndNotTheDayBefore() {
        guard let first = LearnLibrary.allArticles.compactMap({ $0.publishedAt }).min() else {
            return XCTFail("expected a dated article")
        }
        let onTheDay = Set(LearnLibrary.published(asOf: first).map(\.slug))
        let dayBefore = Set(LearnLibrary.published(asOf: first.minusDays(1)).map(\.slug))
        XCTAssertEqual(onTheDay.count, dayBefore.count + 1, "Exactly one article arrives on the day")
        XCTAssertTrue(onTheDay.contains("fertile-window"))
        XCTAssertFalse(dayBefore.contains("fertile-window"))
    }

    /// A withheld article must be unreachable by slug, not merely absent from the list — the deep
    /// link in a share URL or a notification resolves through the same lookup.
    func testWithheldArticleIsNotReachableBySlug() {
        let beforeSeries = CalendarDate(2026, 8, 1)
        let visible = LearnLibrary.published(asOf: beforeSeries)
        XCTAssertNil(visible.first { $0.slug == "when-to-ask-for-support" },
                     "An unreleased article must not resolve by slug")
    }

    /// The Shettles piece is held pending client + medical-reviewer sign-off. If it ever lands,
    /// this test failing is the intended reminder that the guard list has to be revisited first.
    func testShettlesArticleIsAbsent() {
        let slugs = Set(LearnLibrary.allArticles.map(\.slug))
        XCTAssertFalse(slugs.contains("shettles-method"),
                       "Held for medical review — see LearnContent.swift series header")
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
