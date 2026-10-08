import XCTest
import GenesyxCore
@testable import Genesyx

/// The day reader, the related list and the Programme Guide, as pure functions of the context.
@MainActor
final class ProgrammeReaderTests: XCTestCase {

    private let today = CalendarDate(2026, 10, 6)
    private typealias Reader = ProgrammeDayReaderPresentation

    private func fullLog() -> DailyLog {
        DailyLog(mood: .good, energy: .normal, symptoms: ["Fatigue"], sleepMinutes: 450,
                 supplements: ["Folate", "Vitamin D"], waterMl: 4_000, foodGroups: ["vegetables", "fruit"])
    }

    // MARK: - The page

    func testDay23ShowsTheWrittenWhyAndTheDaysOwnReflection() throws {
        let page = try XCTUnwrap(Reader.page(forDay: 23))
        let writing = try XCTUnwrap(ProgrammeDayCopyDraft.writing(forDay: 23))
        XCTAssertEqual(page.why, writing.whyThisMatters)
        XCTAssertEqual(page.reflection, writing.reflection)
        XCTAssertEqual(page.related, writing.relatedContent)
    }

    func testEveryDayFallsBackToTheDefinitionWhereNothingIsWritten() throws {
        for day in 1...90 {
            let page = try XCTUnwrap(Reader.page(forDay: day), "day \(day)")
            let definition = try XCTUnwrap(ProgrammeContent.draft.day(day))
            let writing = ProgrammeDayCopyDraft.writing(forDay: day)
            XCTAssertEqual(page.reflection, writing?.reflection ?? definition.optionalReflection, "day \(day)")
            XCTAssertEqual(page.related, writing?.relatedContent ?? definition.relatedContent, "day \(day)")
            XCTAssertEqual(page.why, writing?.whyThisMatters, "day \(day)")
        }
        XCTAssertNil(Reader.page(forDay: 0))
        XCTAssertNil(Reader.page(forDay: 91))
    }

    func testTheTextOfAPageIsCoresCharacterForCharacter() throws {
        for day in [1, 23, 45, 90] {
            let page = try XCTUnwrap(Reader.page(forDay: day))
            let core = try XCTUnwrap(ProgrammeContent.draft.presentation(ofDay: day, lessons: ProgrammeContent.draftLessons))
            XCTAssertEqual(page.title, core.definition.title)
            XCTAssertEqual(page.focus, core.definition.focus)
            XCTAssertEqual(page.introduction, core.definition.introduction)
            XCTAssertEqual(page.lessonParagraphs, core.lesson?.paragraphs ?? [])
            XCTAssertTrue(page.label.hasSuffix(FertilityKitCopy.minutesToRead(core.estimatedReadMinutes)))
        }
    }

    func testALessonProviderWithNoTextStillGivesACompleteDay() throws {
        for day in 1...90 {
            let page = try XCTUnwrap(Reader.page(forDay: day, lessons: nil), "day \(day)")
            XCTAssertEqual(page.lessonParagraphs, [], "day \(day)")
            XCTAssertFalse(page.title.isEmpty)
            XCTAssertFalse(page.focus.isEmpty)
            XCTAssertFalse(page.introduction.isEmpty)
            XCTAssertTrue(page.label.hasSuffix(FertilityKitCopy.minutesToRead(1)), "no lesson reads as one minute")
        }
    }

    func testTheLabelNamesTheDayItsWeekAndTheReadingTime() throws {
        let page = try XCTUnwrap(Reader.page(forDay: 23))
        let minutes = try XCTUnwrap(ProgrammeContent.draft.presentation(
            ofDay: 23, lessons: ProgrammeContent.draftLessons)).estimatedReadMinutes
        XCTAssertEqual(page.label, "Day 23 of 90 \u{00B7} Week 4 of 13 \u{00B7} \(minutes) min read")
        for day in [85, 90] {
            let late = try XCTUnwrap(Reader.page(forDay: day))
            XCTAssertTrue(late.label.contains("Week 13 of 13"), "day \(day): \(late.label)")
        }
    }

    // MARK: - Which day is shown

    func testTheShownDayIsClampedToTheLatestReadableDay() {
        XCTAssertEqual(Reader.shownDay(nil, latest: 23), 23)
        XCTAssertEqual(Reader.shownDay(10, latest: 23), 10)
        XCTAssertEqual(Reader.shownDay(40, latest: 23), 23)
        XCTAssertEqual(Reader.shownDay(0, latest: 23), 1)
        XCTAssertEqual(Reader.shownDay(200, latest: 90), 90)
    }

    func testTheLatestDayFollowsThePosition() {
        XCTAssertEqual(KitFixture.context(today: today, day: 23).readableDay, 23)
        XCTAssertEqual(KitFixture.context(today: today, day: 90).readableDay, 90)
        XCTAssertEqual(KitFixture.context(today: today, day: 91).readableDay, 90, "day 90 is the latest once completed")
        XCTAssertEqual(KitFixture.context(today: today, day: 140).readableDay, 90)
        XCTAssertNil(KitFixture.context(today: today).readableDay)
        XCTAssertNil(KitFixture.context(today: today, startsIn: 3).readableDay)
        XCTAssertNil(KitFixture.context(today: today, state: ProgrammeState(startedOn: today.minusDays(5), stoppedOn: today.minusDays(1))).readableDay)
        XCTAssertEqual(Reader.shownDay(nil, latest: 90), 90)
        XCTAssertNil(Reader.page(forDay: Reader.shownDay(95, latest: 90) + 1), "week 13 never offers a seventh day")
    }

    // MARK: - Progress

    func testTodaysProgressIsTheHomesOwnLines() throws {
        let kit = KitFixture.context(today: today, day: 23, logs: [today: fullLog()])
        let plan = try XCTUnwrap(kit.dayPlan(forDay: 23))
        XCTAssertEqual(Reader.progressLines(for: plan, today: today),
                       FertilityKitCopy.todayProgressLines(ProgrammeConsistency.today(plan)))
        XCTAssertFalse(Reader.progressLines(for: plan, today: today).contains { $0.contains("%") }, "today is never a percentage")
    }

    func testAFullyMissedDayReadsNothingRecordedAndStillDoesAfterItsLessonIsRead() throws {
        let kit = KitFixture.context(today: today, day: 23)
        let plan = try XCTUnwrap(kit.dayPlan(forDay: 20))
        XCTAssertTrue(Reader.nothingRecorded(plan))
        XCTAssertEqual(Reader.progressLines(for: plan, today: today), [ProgrammeReviewCopy.nothingRecorded])

        let lessonID = try XCTUnwrap(Reader.page(forDay: 20)).lessonID
        let opened = KitFixture.context(today: today, day: 23,
                                        completions: ProgrammeCompletions(lessonsRead: [lessonID]))
        let planAfter = try XCTUnwrap(opened.dayPlan(forDay: 20))
        XCTAssertTrue(planAfter.tasks.contains { $0.completionSource == .explicitRecord }, "the lesson is credited")
        XCTAssertTrue(Reader.nothingRecorded(planAfter))
        XCTAssertEqual(Reader.progressLines(for: planAfter, today: today), [ProgrammeReviewCopy.nothingRecorded])
    }

    func testAPastDayWithOnlyFoodGroupsRecordedHasNoProgressLine() throws {
        let log = DailyLog(foodGroups: ["vegetables", "fruit"])
        let kit = KitFixture.context(today: today, day: 23, logs: [today.minusDays(3): log])
        let plan = try XCTUnwrap(kit.dayPlan(forDay: 20))
        XCTAssertFalse(Reader.nothingRecorded(plan))
        XCTAssertEqual(Reader.progressLines(for: plan, today: today), [])
    }

    func testAPastDayWithFiveCountedActivitiesAndCreditShowsAPercentageAndItsCounts() throws {
        // Day 23 counts five daily activities once her cycle settings exist; it is two days back.
        let settings = CycleSettings(lastPeriodDate: today.minusDays(10), cycleLength: 28, periodLength: 5)
        let kit = KitFixture.context(today: today, day: 25, logs: [today.minusDays(2): fullLog()], cycleSettings: settings)
        let plan = try XCTUnwrap(kit.dayPlan(forDay: 23))
        XCTAssertGreaterThanOrEqual(ProgrammeConsistency.day(plan).counted, ProgrammeConsistency.minimumCountedForPercentage)
        let figure = ProgrammeConsistency.day(plan)
        let percentage = try XCTUnwrap(figure.percentage)
        XCTAssertGreaterThan(percentage, 0)
        XCTAssertEqual(Reader.progressLines(for: plan, today: today),
                       [ProgrammeReviewCopy.percentage(percentage),
                        ProgrammeReviewCopy.activitiesCompleted(figure.completed, of: figure.counted,
                                                                partlyCompleted: figure.partlyCompleted)])
    }

    // MARK: - The main button

    func testTheMainButtonIsHiddenWhereItHasNowhereToGo() {
        let scanning = KitFixture.context(today: today, day: 23, scan: true)
        let plain = KitFixture.context(today: today, day: 23, scan: false)
        XCTAssertEqual(Reader.mainButton(for: .lhTest, in: scanning)?.label, "Open ovulation tests")
        XCTAssertNil(Reader.mainButton(for: .lhTest, in: plain))
        XCTAssertNil(Reader.mainButton(for: .programmeLesson, in: scanning), "she is already on the lesson")
        XCTAssertEqual(Reader.mainButton(for: .nutrition, in: scanning)?.route, .kit(.kitDietPlan))
        XCTAssertEqual(Reader.mainButton(for: .dailyLog, in: scanning)?.route, .dailyLog(today))
        XCTAssertNil(Reader.mainButton(for: .weeklyReview, in: KitFixture.context(today: today)), "not started")
    }

    // MARK: - Related reading

    func testTheRelatedListOmitsEverySlugLearnWouldRefuse() {
        let withheld: Set<String> = ["understanding-ovulation-tests", "fertility-supplements-explained", "when-to-ask-for-support"]
        // Every article, published or not, so no result depends on the date the test runs.
        let article: (String) -> LearnArticle? = { slug in
            withheld.contains(slug) ? nil : LearnLibrary.allArticles.first { $0.slug == slug }
        }
        let kit = KitFixture.context(today: today, day: 23)
        let kept = LearnLibrary.allArticles.first { !withheld.contains($0.slug) }!
        let references: [ProgrammeContentReference] = [
            .learnArticle(slug: "understanding-ovulation-tests"), .learnArticle(slug: kept.slug),
            .learnArticle(slug: "fertility-supplements-explained"), .learnArticle(slug: "when-to-ask-for-support")]
        let rows = ProgrammeRelatedPresentation.rows(references, in: kit, article: article)
        XCTAssertEqual(rows.map(\.identifier), ["kit.related.\(kept.slug)"])
        XCTAssertEqual(rows.first?.title, kept.title)
        XCTAssertEqual(rows.first?.route, .learnArticle(kept.slug))

        let none = ProgrammeRelatedPresentation.rows(
            [.learnArticle(slug: "understanding-ovulation-tests"), .learnArticle(slug: "when-to-ask-for-support")],
            in: kit, article: article)
        XCTAssertEqual(none, [], "no row, so the caller draws no heading")
        XCTAssertEqual(ProgrammeRelatedPresentation.rows([], in: kit, article: article), [])
    }

    // MARK: - The guide

    func testTheGuideListsThirtySectionsWithScanningAndTwentyNineWithout() {
        let scanning = ProgrammeGuidePresentation.sections(in: KitFixture.context(today: today, scan: true))
        let plain = ProgrammeGuidePresentation.sections(in: KitFixture.context(today: today, scan: false))
        XCTAssertEqual(scanning.count, 30)
        XCTAssertEqual(plain.count, 29)
        XCTAssertTrue(scanning.contains { $0.slug == "scanning-an-ovulation-test" })
        XCTAssertFalse(plain.contains { $0.slug == "scanning-an-ovulation-test" })
        XCTAssertEqual(scanning.map(\.title), ProgrammeGuideDraft.sections.map(\.title), "in the guide's own order")
    }

    func testAGuideSectionKeepsItsTextAndLosesAButtonWithNowhereToGo() throws {
        let section = try XCTUnwrap(ProgrammeGuideDraft.section(slug: "lh-testing"))
        let scanning = KitFixture.context(today: today, scan: true)
        let plain = KitFixture.context(today: today, scan: false)
        XCTAssertEqual(ProgrammeGuideSectionPresentation.button(for: section, in: scanning)?.label, "Open ovulation tests")
        XCTAssertNil(ProgrammeGuideSectionPresentation.button(for: section, in: plain))
        XCTAssertEqual(section.paragraphs.count, 5, "the text stays")
    }

    func testTheOverrideSlugsRouteAsTheDesignSays() throws {
        let kit = KitFixture.context(today: today, scan: true)
        func route(_ slug: String) throws -> FertilityKitRoute? {
            ProgrammeGuideSectionPresentation.button(for: try XCTUnwrap(ProgrammeGuideDraft.section(slug: slug)), in: kit)?.route
        }
        XCTAssertEqual(try route("your-fertility-kit"), .kit(.fertilityKit))
        XCTAssertEqual(try route("pregnancy-tests"), .kit(.fertilityKit))
        XCTAssertEqual(try route("understanding-test-history"), .kit(.kitPicture))
        XCTAssertEqual(try route("nutrition"), .dailyLog(today))
    }

    func testTheGuideBorrowsTheWordingOfTheScanScreensWithoutRewritingIt() throws {
        let lh = try XCTUnwrap(ProgrammeGuideDraft.section(slug: "lh-testing"))
        let ph = try XCTUnwrap(ProgrammeGuideDraft.section(slug: "vaginal-ph"))
        let hcg = try XCTUnwrap(ProgrammeGuideDraft.section(slug: "pregnancy-tests"))
        XCTAssertTrue(lh.paragraphs.contains(LhScanCopy.resultNote))
        XCTAssertTrue(ph.paragraphs.contains(PhCopy.accuracyCaveat))
        XCTAssertTrue(ph.paragraphs.contains(PhCopy.elevatedSignpost))
        XCTAssertTrue(ph.paragraphs.contains(PhCopy.disclaimer))
        XCTAssertTrue(hcg.paragraphs.contains(HcgScanCopy.aboutNote))
        XCTAssertTrue(hcg.paragraphs.contains(HcgScanCopy.resultNote))
    }

    // MARK: - Reading

    func testAProgrammeThatHasNotStartedRecordsNoLessonAsRead() throws {
        let container = KitFixture.container()
        let lessonID = try XCTUnwrap(Reader.page(forDay: 1)).lessonID
        XCTAssertFalse(container.programme.markLessonRead(lessonID))
        XCTAssertEqual(container.programme.completions.lessonsRead, [])
    }

    func testReadingALessonOfAStartedProgrammeIsRecordedOnce() throws {
        let container = KitFixture.container()
        container.programme.isAccessActive = { true }
        container.programme.start(today: today)
        let lessonID = try XCTUnwrap(Reader.page(forDay: 1)).lessonID
        XCTAssertTrue(container.programme.markLessonRead(lessonID))
        XCTAssertTrue(container.programme.markLessonRead(lessonID))
        XCTAssertEqual(container.programme.completions.lessonsRead, [lessonID])
    }
}
