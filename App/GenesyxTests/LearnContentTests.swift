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
            // Health-adjacent guides (A, C, D, F, G) also carry the disclaimer.
            "guide-vaginal-ph-tracker",
            "guide-how-to-log-ph",
            "guide-nutrition-focus",
            "guide-track-ph-in-nutrition",
            "guide-cycle-and-phases",
            "guide-understanding-vaginal-ph",
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
            "shettles-method",
        ]
        let actual = Set(LearnLibrary.allArticles.filter { $0.disclaimerRequired }.map { $0.slug })
        XCTAssertEqual(actual, expected, "Medical disclaimer must be pinned to exactly these slugs (6 articles + 6 guides + 12 weekly)")
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
        XCTAssertEqual(articles.count, 32, "Ten articles + ten guides + twelve weekly")
        XCTAssertEqual(articles.filter { $0.featured }.count, 1, "Exactly one featured article")
        XCTAssertEqual(Set(articles.map { $0.slug }).count, 32, "Slugs must be unique")
        XCTAssertEqual(Set(articles.map { $0.id }).count, 32, "Ids must be unique")
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

    /// The phase card's reading, per phase. Two ways this goes wrong and both leave her on a blank
    /// screen: a typo in a slug, or a piece of the weekly series that is not published yet — the
    /// card is due the day her phase turns, not the day the article lands.
    func testEveryPhaseOffersAnArticleSheCanActuallyRead() {
        let slugs = Set(LearnLibrary.allArticles.map(\.slug))
        for (phase, slug) in NutritionView.phaseArticleSlugs {
            XCTAssertTrue(slugs.contains(slug), "\(phase) points at \"\(slug)\", which is not an article")
        }
        for phase in Phase.allCases {
            let article = NutritionView.phaseArticle(phase)
            XCTAssertNotNil(article, "\(phase) leaves the card with nothing to open")
            XCTAssertNotNil(article.flatMap { LearnLibrary.articleBySlug($0.slug) },
                            "\(phase) offers \(article?.slug ?? "-"), which is not published yet")
            XCTAssertFalse(article?.title.isEmpty ?? true, "the link is labelled with the title")
        }
    }

    /// L14. The pH tab now signposts the pH explainer in Learn. The obvious target was
    /// `vaginal-ph-explained`, and it would have shipped as a dead link: it carries
    /// `publishedAt: 2026-08-30`, and every Learn deep link resolves through `LearnLibrary.articles`,
    /// which withholds anything dated ahead. Nothing would have thrown — she would have tapped a
    /// confident link and arrived at the "unavailable" screen.
    ///
    /// So this asserts through `articleBySlug` (published today) rather than against the full set:
    /// spelling the slug correctly is not the property that matters, being readable is.
    func testThePhTabSignpostsAnArticleSheCanActuallyOpen() {
        let slug = PhTabView.learnArticleSlug
        XCTAssertNotNil(LearnLibrary.allArticles.first { $0.slug == slug },
                        "the pH tab points at \"\(slug)\", which is not an article at all")

        let article = LearnLibrary.articleBySlug(slug)
        XCTAssertNotNil(article,
                        "\"\(slug)\" exists but is not published yet — the pH tab would send her to a blank screen")
        XCTAssertNil(article?.publishedAt,
                     "the pH signpost must not depend on a publication date; it is shown from day one")
    }

    /// Distinct destinations are the whole point of the row — one article for four phases is what
    /// the card did before. Checked on the mapping rather than on what is published today, because
    /// the series unlocks by date and this must not start passing for the wrong reason.
    func testThePhasesDoNotAllPointAtTheSameArticle() {
        XCTAssertEqual(Set(NutritionView.phaseArticleSlugs.keys), Set(Phase.allCases))
        XCTAssertEqual(Set(NutritionView.phaseArticleSlugs.values).count, Phase.allCases.count,
                       "two phases share an article; she is told something changed and shown the same page")
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
    func testTheTwelveWeekPlanListsEveryWeeklyArticleInOrder() {
        let series = LearnLibrary.weeklySeries
        XCTAssertEqual(series.count, 12)
        XCTAssertEqual(series.map(\.id), (1...12).map { "w\($0)" })
        XCTAssertEqual(series.map(\.title), [
            "Understanding your fertile window",
            "What your vaginal pH is actually telling you",
            "Eating in the months before conception",
            "What cervical mucus can tell you",
            "Hydration and reproductive health",
            "Timing sex when you are trying to conceive",
            "Sleep, stress and your cycle",
            "Understanding ovulation tests",
            "Supporting sperm health",
            "Fertility supplements, and what the evidence says",
            "When to ask for fertility support",
            "The Shettles method, and what the evidence shows",
        ])
        XCTAssertFalse(LearnLibrary.allArticles.contains { $0.slug == TwelveWeekPlan.route },
                       "the plan page is a contents list, not a 33rd article")
    }

    func testEveryWeeklyArticleIsCited() {
        let weekly = LearnLibrary.allArticles.filter { $0.publishedAt != nil }
        XCTAssertEqual(weekly.count, 12)
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
            guard let name = a.heroImage else {
                XCTFail("Missing hero asset mapping for \(a.slug)")
                continue
            }
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
        XCTAssertEqual(undated.count, 20, "The original library plus the vaginal-pH guide added in build 18")
    }

    func testSeriesRevealsOneArticlePerWeek() {
        let dated = LearnLibrary.allArticles
            .compactMap { $0.publishedAt }
            .sorted()
        XCTAssertEqual(dated.count, 12, "Twelve dated articles")
        XCTAssertEqual(Set(dated).count, 12, "No two articles share a publish date — one drop per week")
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

    // MARK: - The Shettles piece

    /// This replaces `testShettlesArticleIsAbsent`, which held the slot while the piece was
    /// believed to be unwritable inside the banned-phrase guard. It turned out to be writable —
    /// the guard bans claims, not the subject — so absence stopped being the thing worth pinning
    /// and the *framing* became it.
    ///
    /// The risk this now guards is the realistic one. Nobody is going to add "choose the sex" and
    /// sail past `testNoBannedPhrasesAnywhere`. What could happen is a slow softening under
    /// commercial pressure: the negations trimmed, the piece left describing the method neutrally,
    /// and an article that was a correction quietly reading as an endorsement — with every
    /// existing guard still green, because not one banned phrase was ever typed.
    private func shettles(file: StaticString = #filePath, line: UInt = #line) throws -> LearnArticle {
        try XCTUnwrap(LearnLibrary.allArticles.first { $0.slug == "shettles-method" },
                      "shettles-method is missing — see the series header in LearnContent.swift",
                      file: file, line: line)
    }

    /// Under the CAP Code an efficacy claim needs substantiation, and for this one there is none to
    /// give. So the article is only publishable while it says so: these negations are the legal
    /// basis of the piece, not decoration on it.
    func testShettlesArticleStatesThereIsNoEvidence() throws {
        let text = try scannableStrings(shettles()).joined(separator: " ").lowercased()
        let negations = [
            "no controlled evidence",
            "has never actually been demonstrated",
            "no effect whatsoever on the sex of the baby",
            "not been shown to exist",
        ]
        for phrase in negations {
            XCTAssertTrue(text.contains(phrase),
                "The Shettles piece must keep stating the evidence is absent. Missing: \"\(phrase)\"")
        }
    }

    /// The inverse, and the one that catches a rewrite rather than a deletion. None of these is a
    /// banned phrase, so `testNoBannedPhrasesAnywhere` would pass on every one of them.
    func testShettlesArticleMakesNoEfficacyClaim() throws {
        let claims = [
            "increase your chances of having",
            "improve your odds of",
            "works best if you",
            "will help you have",
            "if you want a son",
            "if you want a daughter",
            "shettles method works",
            "studies show it works",
        ]
        for s in try scannableStrings(shettles()) {
            let lower = s.lowercased()
            for claim in claims {
                XCTAssertFalse(lower.contains(claim),
                    "Efficacy claim \"\(claim)\" in the Shettles piece: \(s)")
            }
        }
    }

    func testShettlesArticleIsCitedAndCarriesTheDisclaimer() throws {
        XCTAssertTrue(try shettles().disclaimerRequired)
        let ids = LearnSourceMap.sources(for: "shettles-method") ?? []
        XCTAssertTrue(ids.contains("wilcox-1995"),
            "The no-effect finding is the article's load-bearing claim and must cite the study it comes from")
    }

    // MARK: - Cross-article integrity

    /// Source titles render in `SourcesFooter` exactly as written, so they are reader-facing copy
    /// that `testNoBannedPhrasesAnywhere` never sees — it scans articles. A citation titled with a
    /// claim phrase would put it on screen under the article that exists to refute it.
    func testNoBannedPhrasesInCitedSourceTitles() {
        let store = MedicalSourceStore.shared
        for ids in LearnSourceMap.bySlug.values {
            for id in ids {
                guard let source = store.source(id) else { continue }
                let lower = "\(source.title) \(source.organisation)".lowercased()
                for phrase in bannedPhrases {
                    XCTAssertFalse(lower.contains(phrase),
                        "Banned phrase \"\(phrase)\" in the rendered title of source \(id)")
                }
            }
        }
    }

    /// An `.openArticle` CTA whose target is still withheld renders the "unavailable" screen — no
    /// crash, and no failing test either. The reader just gets a dead end on the one button the
    /// article asked her to press.
    func testArticleCtaTargetsAreVisibleWheneverTheirArticleIs() {
        for a in LearnLibrary.allArticles {
            guard let cta = a.cta, cta.type == .openArticle, let target = cta.targetSlug else { continue }
            let visibleThen = LearnLibrary.published(asOf: a.publishedAt ?? CalendarDate(2020, 1, 1))
            XCTAssertTrue(visibleThen.contains { $0.slug == target },
                "\(a.slug) links to \(target), which is not published yet when \(a.slug) appears")
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
