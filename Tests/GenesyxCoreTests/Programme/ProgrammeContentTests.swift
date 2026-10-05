import XCTest
@testable import GenesyxCore

/// The content schema and the built-in draft: structure, the guarded registry and review status.
final class ProgrammeContentTests: XCTestCase {

    private let content = ProgrammeContent.draft

    // ── Structure ──

    func testThirteenWeeksAndNinetyDays() {
        XCTAssertEqual(content.weeks.map(\.number), Array(1...13))
        XCTAssertEqual(content.days.map(\.day), Array(1...90))
        XCTAssertNil(content.day(0))
        XCTAssertNil(content.day(91))
    }

    func testTheWeekThemesAreTheOwnersInOrder() {
        XCTAssertEqual(content.weeks.map(\.themeTitle), [
            "Start & Baseline", "Understand Your Cycle", "Nutrition Foundations", "Hydration & Sleep",
            "Your Body Signals", "Understanding Fertility", "Understand Your Tests", "Build Consistency",
            "Discover Your Patterns", "Your Fertility Goal", "Strengthen Your Routine",
            "Understand Your Insights", "Review, Personalise & Continue",
        ])
        XCTAssertEqual(ProgrammePhase.allCases.map { content.phaseTitles[$0] },
                       ["Build the Foundation", "Discover Your Patterns", "Personalise & Sustain"])
    }

    func testEveryDayResolvesCompletely() {
        var lessonIDs = Set<String>()
        for day in content.days {
            XCTAssertEqual(day.week, ProgrammeCalendar.week(forDay: day.day))
            XCTAssertEqual(day.phase, ProgrammeCalendar.phase(forDay: day.day))
            XCTAssertEqual(day.kind, content.dayKind(forDay: day.day))
            for text in [day.title, day.focus, day.introduction, day.lesson.id] {
                XCTAssertFalse(text.trimmingCharacters(in: .whitespaces).isEmpty, "day \(day.day)")
            }
            XCTAssertTrue(lessonIDs.insert(day.lesson.id).inserted, "lesson id repeated on day \(day.day)")
            XCTAssertFalse(day.todayActions.isEmpty)
            XCTAssertGreaterThanOrEqual(day.estimatedReadMinutes, 1)
            XCTAssertEqual(day.notificationCategoryKey, "programme")
            XCTAssertEqual(day.review.status, .draft)
            XCTAssertEqual(day.lesson.review.status, .draft)
            XCTAssertEqual(day.safety.disclaimerRequired, day.safety.containsHealthInterpretation)
        }
        XCTAssertEqual(content.day(23)?.lesson.id, "programme-day-023")
        XCTAssertEqual(content.day(7)?.lesson.id, "programme-day-007")
    }

    func testWeeksCoverSevenDaysExceptThirteenAndPhasesCoverThirty() {
        for week in content.weeks {
            let days = content.days.filter { $0.week == week.number }.map(\.day)
            XCTAssertEqual(days, Array(week.dayRange))
            XCTAssertEqual(days.count, week.number == 13 ? 6 : 7)
        }
        XCTAssertEqual(content.days.filter { $0.week == 13 }.map(\.day), Array(85...90))
        for phase in ProgrammePhase.allCases {
            XCTAssertEqual(content.days.filter { $0.phase == phase }.count, 30)
        }
    }

    func testTheWeeklyDayKindPattern() {
        XCTAssertEqual((1...7).map { content.dayKind(forDay: $0) },
                       [.shortLesson, .actionDay, .trackerFocus, .nutritionFocus, .shortLesson, .reflection, .weeklyReview])
        // Weeks 6 and 7 swap the fifth day for test guidance.
        XCTAssertEqual(content.dayKind(forDay: 40), .testGuidance)
        XCTAssertEqual(content.dayKind(forDay: 47), .testGuidance)
        XCTAssertEqual(content.dayKind(forDay: 54), .shortLesson)
        // The last day of each phase is a progress review.
        XCTAssertEqual(content.days.filter { $0.kind == .progressReview }.map(\.day), [30, 60, 90])
        // Every kind is used.
        XCTAssertEqual(Set(content.days.map(\.kind)), Set(ProgrammeDayKind.allCases))
    }

    func testCallsToActionAreTypedAndFollowTheKind() {
        for day in content.days {
            switch day.kind {
            case .shortLesson: XCTAssertEqual(day.callToAction, .programmeLesson)
            case .actionDay, .reflection: XCTAssertEqual(day.callToAction, .dailyLog)
            case .nutritionFocus: XCTAssertEqual(day.callToAction, .nutrition)
            case .testGuidance: XCTAssertEqual(day.callToAction, .fertilityKitGuide)
            case .weeklyReview: XCTAssertEqual(day.callToAction, .weeklyReview)
            case .progressReview: XCTAssertEqual(day.callToAction, .programmeProgress)
            case .trackerFocus: XCTAssertEqual(day.callToAction, day.relatedFeature.destination)
            }
            // A day never sends her to the ovulation-test screen, which a Release build lacks.
            XCTAssertNotEqual(day.callToAction, .lhTest)
        }
    }

    func testReflectionPromptsAndNutritionFocusAppearOnlyWhereTheyApply() {
        for day in content.days {
            let reflective = [.reflection, .weeklyReview, .progressReview].contains(day.kind)
            XCTAssertEqual(day.optionalReflection != nil, reflective, "day \(day.day)")
            XCTAssertEqual(day.nutritionFocus != nil, day.kind == .nutritionFocus, "day \(day.day)")
        }
    }

    // ── Nutrition focus ──

    func testEveryWeekHasANutritionFocusNamingOnlyRealFoodGroups() {
        XCTAssertEqual(content.weeks.map(\.nutritionFocus.title), [
            "Your current routine", "Notice variety", "Balanced plate", "Hydration",
            "Fruit and vegetable variety", "Protein variety", "Fibre-rich choices", "Oils and fats",
            "Meal regularity", "Practical preparation", "Sustainable choices",
            "Understand your nutrition pattern", "Long-term routine",
        ])
        for week in content.weeks {
            XCTAssertFalse(week.nutritionFocus.detail.isEmpty)
            XCTAssertEqual(Set(week.nutritionFocus.foodGroups).count, week.nutritionFocus.foodGroups.count)
            for group in week.nutritionFocus.foodGroups {
                XCTAssertTrue(FoodGroup.allCases.contains(group))
            }
        }
        XCTAssertEqual(FoodGroup.allCases.count, 6)
    }

    // ── Related content ──

    /// Related Learn content is named by slugs the app really has. The Learn library sits in the
    /// app layer, so this reads its source; skipped where the app sources are not present.
    func testRelatedLearnSlugsExistInTheApp() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let learn = root.appendingPathComponent("App/Genesyx/UI/Learn")
        guard let files = try? FileManager.default.contentsOfDirectory(at: learn, includingPropertiesForKeys: nil) else {
            throw XCTSkip("App sources not present")
        }
        let source = files.filter { $0.pathExtension == "swift" }
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined()
        var checked = 0
        for week in content.weeks {
            XCTAssertFalse(week.relatedContent.isEmpty, "week \(week.number)")
            for reference in week.relatedContent {
                guard case .learnArticle(let slug) = reference else { continue }
                XCTAssertTrue(source.contains("\"\(slug)\""), "no Learn article with slug \(slug)")
                XCTAssertNotEqual(slug, "shettles-method")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 13)
    }

    // ── No placeholders ──

    private struct FixedLessons: ProgrammeLessonProviding {
        let paragraphs: [String]
        func body(forLessonID id: String) -> ProgrammeLessonBody? { ProgrammeLessonBody(paragraphs: paragraphs) }
    }

    func testADayWithNoLessonTextIsACompleteShortDay() throws {
        for day in 1...90 {
            let shown = try XCTUnwrap(content.presentation(ofDay: day))
            XCTAssertNil(shown.lesson)
            XCTAssertEqual(shown.estimatedReadMinutes, 1)
            XCTAssertFalse(shown.definition.title.isEmpty)
            XCTAssertFalse(shown.definition.focus.isEmpty)
            XCTAssertFalse(shown.definition.introduction.isEmpty)
        }
        XCTAssertNil(content.presentation(ofDay: 91))
    }

    func testALessonCannotBeEmptyAndBlankTextIsTheSameAsNoText() throws {
        XCTAssertNil(ProgrammeLessonBody(paragraphs: []))
        XCTAssertNil(ProgrammeLessonBody(paragraphs: ["", "  \n"]))
        XCTAssertEqual(ProgrammeLessonBody(paragraphs: [" One. ", "", "Two."])?.paragraphs, ["One.", "Two."])

        let blank = try XCTUnwrap(content.presentation(ofDay: 5, lessons: FixedLessons(paragraphs: [" "])))
        XCTAssertNil(blank.lesson)
        XCTAssertEqual(blank.estimatedReadMinutes, 1)

        let written = try XCTUnwrap(content.presentation(ofDay: 5, lessons: FixedLessons(paragraphs: ["Text."])))
        XCTAssertEqual(written.lesson?.paragraphs, ["Text."])
        XCTAssertEqual(written.estimatedReadMinutes, written.definition.estimatedReadMinutes)
    }

    func testNoSurfaceIsAPlaceholder() {
        let placeholders = ["coming soon", "placeholder", "tbc", "tbd", "todo", "lorem", "to follow", "to be written", "draft"]
        for s in content.allSurfaces {
            for term in placeholders {
                XCTAssertFalse(s.lowercased().contains(term), "placeholder wording \"\(term)\" in: \(s)")
            }
        }
    }

    func testWrittenDayCopyReplacesTheGeneratedDefaultAndIsGuarded() {
        let draft = ProgrammeContent.draft
        let written = ProgrammeDayCopy(title: "Welcome", focus: "Meet your kit.", introduction: "Here is how it works.")
        let revised = ProgrammeContent(version: "test", weeks: draft.weeks, phaseTitles: draft.phaseTitles,
                                       kindCopy: draft.kindCopy, kindReflections: draft.kindReflections,
                                       kindReadMinutes: draft.kindReadMinutes, testGuidanceWeeks: draft.testGuidanceWeeks,
                                       dayCopy: [1: written])
        XCTAssertEqual(revised.day(1)?.title, "Welcome")
        XCTAssertEqual(revised.day(2)?.title, "Start & Baseline: Action day")
        XCTAssertTrue(revised.allSurfaces.contains("Here is how it works."))
    }

    // ── Review status ──

    func testReviewStatusRawValuesArePinned() {
        XCTAssertEqual(ProgrammeReviewStatus.allCases.map(\.rawValue),
                       ["draft", "editorial_reviewed", "clinical_reviewed", "approved"])
    }

    func testEveryContentItemIsListedAndStartsAsDraft() {
        let items = content.reviewItems()
        XCTAssertEqual(items.count, 13 + 13 + 90 + 90)
        XCTAssertEqual(Set(items.map(\.id)).count, items.count, "review ids must be unique")
        for kind in ProgrammeReviewItem.Kind.allCases {
            XCTAssertEqual(items.filter { $0.kind == kind }.count, kind == .week || kind == .nutritionFocus ? 13 : 90)
        }
        XCTAssertEqual(content.reviewItems(with: .draft).count, items.count)
        for status in [ProgrammeReviewStatus.editorialReviewed, .clinicalReviewed, .approved] {
            XCTAssertTrue(content.reviewItems(with: status).isEmpty)
        }
    }

    func testItemsNeedingClinicalReviewAreThoseThatInterpretHealth() {
        let needing = content.itemsNeedingClinicalReview()
        XCTAssertFalse(needing.isEmpty)
        XCTAssertTrue(needing.allSatisfy { $0.review.containsHealthInterpretation })
        // Every nutrition focus, and the weeks on cycle, nutrition, sleep, signals, tests and insights.
        XCTAssertEqual(needing.filter { $0.kind == .nutritionFocus }.count, 13)
        XCTAssertEqual(needing.filter { $0.kind == .week }.map(\.id),
                       ["week-02", "week-03", "week-04", "week-05", "week-06", "week-07", "week-09", "week-10", "week-12"])
        XCTAssertTrue(needing.contains { $0.id == "day-040" })
        XCTAssertFalse(needing.contains { $0.id == "day-001" })
    }

    func testAStatusThatMovesOnIsListedUnderItsNewStatus() {
        let draft = ProgrammeContent.draft
        let revised = ProgrammeContent(version: "test", weeks: draft.weeks, phaseTitles: draft.phaseTitles,
                                       kindCopy: draft.kindCopy, kindReflections: draft.kindReflections,
                                       kindReadMinutes: draft.kindReadMinutes, testGuidanceWeeks: draft.testGuidanceWeeks,
                                       dayStatuses: [40: .clinicalReviewed], lessonStatuses: [40: .approved])
        XCTAssertEqual(revised.reviewItems(with: .clinicalReviewed).map(\.id), ["day-040"])
        XCTAssertEqual(revised.reviewItems(with: .approved).map(\.id), ["programme-day-040"])
        XCTAssertFalse(revised.itemsNeedingClinicalReview().contains { $0.id == "day-040" || $0.id == "programme-day-040" })
    }

    // ── Banned-phrase guard ──

    /// The union of the lists the other copy guards hold (notifications, water challenge, consent,
    /// pH, scan, LH, pregnancy test, insights, house style) plus the programme's own. Three terms
    /// from those lists are left out because the owner's own week themes use them: "fertility"
    /// (the nutrition-row list), "regularity" (the Insights screen) and the whole word "week" (the
    /// pregnancy-test screens).
    private let bannedAnywhere = [
        "unlock", "guarantee", "diagnos", "cure", "treat", "infertil", "you are pregnant", "get pregnant fast", "empower",
        "thrush", "infection", "candida", "vaginosis", "prescrib", "leafy greens", "whole grains", "mineral water",
        "you are ovulating", "you ovulated", "you will ovulate", "ovulation confirmed", "confirms ovulation",
        "confirmed", "peak fertility", "most fertile", "best time", "conceive", "conception", "pregnan",
        "intercourse", "have sex", "baby", "gender", "shettles", "sex selection", "boy or girl", "alkaline diet",
        "balance your ph", "sway the sex", "choose the sex", "detox", "flush toxins",
        "congratulat", "due date", "miscarr", "unfortunately", "sorry", "positive", "negative", "expecting", "celebrat",
        "you broke", "you failed", "you missed", "don't lose", "streak is over", "missed", "failed", "should have",
        "behind", "don't forget", "hormone", "optimis", "your journey", "take control of", "boost",
    ]
    private let bannedWords = ["bv", "sti", "stis", "boy", "girl", "hcg"]

    private func containsWord(_ term: String, in text: String) -> Bool {
        text.range(of: "\\b\(NSRegularExpression.escapedPattern(for: term))\\b",
                   options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func violations(in surfaces: [String]) -> [String] {
        var found: [String] = []
        for s in surfaces {
            let lower = s.lowercased()
            for term in bannedAnywhere where lower.contains(term) { found.append("\"\(term)\" in: \(s)") }
            for term in bannedWords where containsWord(term, in: s) { found.append("\"\(term)\" in: \(s)") }
            if s.contains("\u{2014}") { found.append("em dash in: \(s)") }
            if lower.contains("analyz") || lower.contains("personaliz") { found.append("US spelling in: \(s)") }
            if s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { found.append("empty string registered") }
        }
        return found
    }

    func testProgrammeCopyHasNoBannedTermsAndFollowsHouseStyle() {
        // 3 phase titles, 4 strings per week, 3 per day and a prompt on the reflective days.
        XCTAssertGreaterThanOrEqual(content.allSurfaces.count, 3 + 13 * 4 + 90 * 3, "the registry must not shrink")
        XCTAssertEqual(violations(in: content.allSurfaces), [])
    }

    /// The guard has to be able to fail, or the test above proves nothing.
    func testTheGuardCatchesWhatItShould() {
        XCTAssertEqual(violations(in: ["Activate My Kit", "Still testing your routine"]), [])
        for bad in ["Unlock your programme", "We guarantee results", "This can diagnose a problem", "A cure for it",
                    "Treatment options", "Signs of infertility", "You are pregnant", "Get pregnant fast",
                    "An empowering read", "Ovulation confirmed", "This may be an STI", "More likely a boy",
                    "A week \u{2014} and counting", "You missed a day", "Boost your chances"] {
            XCTAssertFalse(violations(in: [bad]).isEmpty, "the guard let through: \(bad)")
        }
    }

    func testEveryWeekAndDayStringIsInTheRegistry() {
        let surfaces = Set(content.allSurfaces)
        for week in content.weeks {
            for s in [week.themeTitle, week.purpose, week.nutritionFocus.title, week.nutritionFocus.detail] {
                XCTAssertTrue(surfaces.contains(s), s)
            }
        }
        for day in content.days {
            for s in [day.title, day.focus, day.introduction] + (day.optionalReflection.map { [$0] } ?? []) {
                XCTAssertTrue(surfaces.contains(s), s)
            }
        }
        for phase in ProgrammePhase.allCases { XCTAssertTrue(surfaces.contains(content.phaseTitles[phase] ?? "")) }
    }
}
