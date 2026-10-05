import XCTest
@testable import GenesyxCore

/// The written copy for the ninety programme days: complete, distinct, plugged into the draft
/// content, guarded and marked for review.
final class ProgrammeDayCopyDraftTests: XCTestCase {

    private typealias Guard = ProgrammeWrittenCopyGuard
    private let content = ProgrammeContent.draft
    private let written = ProgrammeDayCopyDraft.all

    // ── Completeness ──

    func testAllNinetyDaysAreWrittenOnceAndInOrder() {
        XCTAssertEqual(written.map(\.day), Array(1...90))
        XCTAssertEqual(ProgrammeDayCopyDraft.dayCopy.count, 90)
        XCTAssertNil(ProgrammeDayCopyDraft.writing(forDay: 0))
        XCTAssertNil(ProgrammeDayCopyDraft.writing(forDay: 91))
        XCTAssertEqual(ProgrammeDayCopyDraft.writing(forDay: 23)?.day, 23)
    }

    func testEveryDayHasATitleAFocusAnIntroductionAndAReason() {
        for day in written {
            for text in [day.copy.title, day.copy.focus, day.copy.introduction, day.whyThisMatters] {
                XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "day \(day.day)")
            }
            XCTAssertLessThanOrEqual(day.copy.title.count, 45, "title too long for a card on day \(day.day)")
            // One line: a single sentence, short enough for one row of a phone screen and a half.
            XCTAssertEqual(Guard.sentenceCount(day.copy.focus), 1, "focus on day \(day.day)")
            XCTAssertLessThanOrEqual(day.copy.focus.count, 90, "focus on day \(day.day)")
            XCTAssertTrue((2...3).contains(Guard.sentenceCount(day.copy.introduction)), "introduction on day \(day.day)")
            XCTAssertTrue((1...2).contains(Guard.sentenceCount(day.whyThisMatters)), "why on day \(day.day)")
        }
    }

    func testNoTwoDaysShareATitleOrAnyOtherLine() {
        func assertDistinct(_ values: [String], _ what: String) {
            XCTAssertEqual(Set(values.map { $0.lowercased() }).count, values.count, "\(what) repeated")
        }
        assertDistinct(written.map(\.copy.title), "title")
        assertDistinct(written.map(\.copy.introduction), "introduction")
        assertDistinct(written.map(\.whyThisMatters), "why this matters")
        assertDistinct(written.compactMap(\.reflection), "reflection question")
    }

    // ── Plugged into the draft content ──

    func testTheDraftContentShowsTheWrittenCopyOnEveryDay() throws {
        for day in 1...90 {
            let definition = try XCTUnwrap(content.day(day))
            let writing = try XCTUnwrap(ProgrammeDayCopyDraft.writing(forDay: day))
            XCTAssertEqual(definition.title, writing.copy.title)
            XCTAssertEqual(definition.focus, writing.copy.focus)
            XCTAssertEqual(definition.introduction, writing.copy.introduction)
            // No generated "<week theme>: <kind>" title is left.
            let week = try XCTUnwrap(content.week(definition.week))
            XCTAssertFalse(definition.title.hasPrefix(week.themeTitle + ":"), "generated title on day \(day)")
            for kind in content.kindCopy.values {
                XCTAssertNotEqual(definition.focus, kind.focus, "generated focus on day \(day)")
            }
        }
    }

    func testTheWeekThemesAreFollowed() throws {
        // The first day of each week opens that week's subject. A cheap check that the copy has
        // not slid against the schedule: each opening title names its week's subject.
        let openers = [
            1: "90 days", 8: "cycle", 15: "Diet Plan", 22: "Water", 29: "Mood and energy", 36: "fertile window",
            43: "test", 50: "Consistency", 57: "pattern", 64: "goal", 71: "routines", 78: "evidence levels",
            85: "programme",
        ]
        for (day, phrase) in openers {
            let title = try XCTUnwrap(content.day(day)?.title)
            XCTAssertEqual(content.dayKind(forDay: day), .shortLesson)
            XCTAssertTrue(title.lowercased().contains(phrase.lowercased()), "day \(day): \(title)")
        }
        // Nutrition-focus days name the week's focus; progress reviews close each phase.
        for day in content.days where day.kind == .nutritionFocus {
            XCTAssertTrue(day.introduction.contains("This week's nutrition focus is"), "day \(day.day)")
        }
        XCTAssertEqual(content.days.filter { $0.kind == .progressReview }.map(\.title),
                       ["Thirty days: your foundation", "Sixty days: your patterns so far", "Ninety days: your review"])
        // Days 85 to 90 are the final review.
        XCTAssertEqual(content.days.filter { $0.week == 13 }.map(\.title), [
            "Looking back over your programme", "Your routine, your way", "Your programme history",
            "Food habits to carry on with", "Life after day 90", "Ninety days: your review",
        ])
    }

    // ── Reflection questions ──

    func testAQuestionIsWrittenForEveryReflectiveDayAndNoOther() throws {
        for writing in written {
            let kind = content.dayKind(forDay: writing.day)
            let reflective = [.reflection, .weeklyReview, .progressReview].contains(kind)
            XCTAssertEqual(writing.reflection != nil, reflective, "day \(writing.day)")
            if let question = writing.reflection {
                XCTAssertTrue(question.hasSuffix("?"), question)
                XCTAssertEqual(Guard.sentenceCount(question), 1, question)
            }
        }
        XCTAssertEqual(written.compactMap(\.reflection).count, 12 + 12 + 3)
    }

    // ── Related Learn content ──

    func testRelatedLearnSlugsAreRealAndNeverTheShettlesPiece() throws {
        guard let source = Guard.learnSource() else { throw XCTSkip("App sources not present") }
        var checked = 0
        for writing in written {
            let slugs = Guard.learnSlugs(in: writing.relatedContent)
            XCTAssertEqual(slugs.count, writing.relatedContent.count, "day \(writing.day) points at something that is not a Learn article")
            XCTAssertEqual(Set(slugs).count, slugs.count, "slug repeated on day \(writing.day)")
            for slug in slugs {
                XCTAssertTrue(source.contains("slug: \"\(slug)\""), "no Learn article with slug \(slug) (day \(writing.day))")
                XCTAssertFalse(slug.contains("shettles"))
                XCTAssertNotEqual(slug, "timing-sex-when-ttc")
                checked += 1
            }
        }
        XCTAssertEqual(checked, 61, "related Learn links across the ninety days")
    }

    // ── Guard ──

    func testDayCopyPassesTheGuardWithNoExceptionAtAll() {
        // Day copy is on the day screen and in `ProgrammeContent.allSurfaces`, so it gets the
        // strict guard: the test product is never named here.
        XCTAssertEqual(Guard.violations(in: ProgrammeDayCopyDraft.allSurfaces), [])
        XCTAssertEqual(Guard.violations(in: content.allSurfaces), [])
    }

    func testEveryDayStringIsInTheRegistries() {
        let own = Set(ProgrammeDayCopyDraft.allSurfaces)
        let all = Set(ProgrammeContent.draftWrittenSurfaces)
        let schema = Set(content.allSurfaces)
        for day in written {
            for s in [day.copy.title, day.copy.focus, day.copy.introduction, day.whyThisMatters]
                + (day.reflection.map { [$0] } ?? []) {
                XCTAssertTrue(own.contains(s), s)
                XCTAssertTrue(all.contains(s), s)
            }
            for s in [day.copy.title, day.copy.focus, day.copy.introduction] {
                XCTAssertTrue(schema.contains(s), "not reached by ProgrammeContent.allSurfaces: \(s)")
            }
        }
        XCTAssertEqual(ProgrammeDayCopyDraft.allSurfaces.count, 90 * 4 + 27)
    }

    /// The guard has to be able to fail, or the tests above prove nothing.
    func testTheGuardCatchesWhatItShould() {
        XCTAssertEqual(Guard.violations(in: ["Activate My Kit", "Still testing your routine", "A colour chart in the programme"]), [])
        for bad in ["You are pregnant", "A positive result", "A negative result", "Boost your chances", "We guarantee it",
                    "A detox week", "A superfood", "A cure for it", "Treatment options", "This can diagnose it",
                    "Signs of infertility", "You failed today", "You are behind", "Keep your streak", "You should have logged",
                    "Count each calorie", "Watch your weight", "Your BMI", "A good food", "A bad food",
                    "Unlock your programme", "A week \u{2014} and counting", "Coming soon", "To be written",
                    "Your program", "Pick a color", "Organize your week", "A pregnancy test", "LH is a hormone",
                    "A common misconception", " leading space", "two  spaces"] {
            XCTAssertFalse(Guard.violations(in: [bad]).isEmpty, "the guard let through: \(bad)")
        }
        // The product name is let through only on request, and nothing else with it.
        XCTAssertEqual(Guard.violations(in: ["Your kit includes pregnancy tests."], allowingProductName: true), [])
        XCTAssertFalse(Guard.violations(in: ["A pregnancy test shows you are pregnant."], allowingProductName: true).isEmpty)
        XCTAssertFalse(Guard.violations(in: ["Early pregnancy"], allowingProductName: true).isEmpty)
    }

    // ── Review status ──

    func testEveryDayIsADraftAndHealthTopicsAreFlaggedForClinicalReview() {
        for day in written {
            XCTAssertEqual(day.review.status, .draft, "day \(day.day)")
            let text = ([day.copy.title, day.copy.focus, day.copy.introduction, day.whyThisMatters]
                + (day.reflection.map { [$0] } ?? [])).joined(separator: " ")
            if Guard.namesAHealthTopic(text) {
                XCTAssertTrue(day.review.containsHealthInterpretation, "day \(day.day) names a health topic and is not flagged")
            }
        }
        // Every day in a week the schedule marks as health content is flagged here too.
        for definition in content.days where definition.review.containsHealthInterpretation {
            XCTAssertEqual(ProgrammeDayCopyDraft.writing(forDay: definition.day)?.review.containsHealthInterpretation, true,
                           "day \(definition.day)")
        }
    }

    // ── Pinned totals ──

    func testTotalsArePinnedSoLaterEditsAreDeliberate() {
        XCTAssertEqual(written.count, 90)
        XCTAssertEqual(written.filter { $0.review.containsHealthInterpretation }.count, 70)
        XCTAssertEqual(written.filter { !$0.relatedContent.isEmpty }.count, 45)
        XCTAssertEqual(content.allSurfaces.count, 3 + 13 * 4 + 90 * 3 + 27)
    }
}
