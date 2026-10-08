import XCTest
import GenesyxCore
import SwiftUI
@testable import Genesyx

/// The plain value every Fertility Kit screen reads, the routes worked out from it, the kit's
/// clock and the kit's part of the UI-test seed. Nothing here reads the device's date.
@MainActor
final class FertilityKitContextTests: XCTestCase {

    private let today = CalendarDate(2026, 6, 10)

    // MARK: - The access state

    func testTheAccessStateOverAccessAndPosition() {
        func state(_ access: Bool, day: Int? = nil, startsIn: Int? = nil, state: ProgrammeState? = nil) -> FertilityKitAccessState {
            KitFixture.context(today: today, day: day, startsIn: startsIn, state: state, access: access).accessState
        }
        XCTAssertEqual(state(true), .notStarted)
        XCTAssertEqual(state(true, startsIn: 3), .scheduled(startsOn: today.plusDays(3), daysUntilStart: 3))
        XCTAssertEqual(state(true, day: 1), .active(day: 1, week: 1, phase: .buildTheFoundation))
        XCTAssertEqual(state(true, day: 23), .active(day: 23, week: 4, phase: .buildTheFoundation))
        XCTAssertEqual(state(true, day: 30), .active(day: 30, week: 5, phase: .buildTheFoundation))
        XCTAssertEqual(state(true, day: 31), .active(day: 31, week: 5, phase: .discoverYourPatterns))
        XCTAssertEqual(state(true, day: 90), .active(day: 90, week: 13, phase: .personaliseAndSustain))
        XCTAssertEqual(state(true, day: 91), .completed)
        XCTAssertEqual(state(true, day: 200), .completed)
        let stopped = ProgrammeState(startedOn: today.minusDays(10), stoppedOn: today.minusDays(2))
        XCTAssertEqual(state(true, state: stopped), .stopped)
        // Without access nothing else is asked: a stored start date changes nothing.
        for position in [state(false), state(false, startsIn: 3), state(false, day: 1), state(false, day: 23),
                         state(false, day: 91), state(false, state: stopped)] {
            XCTAssertEqual(position, .noAccess)
        }
        XCTAssertEqual(FertilityKitAccessState.resolve(hasAccess: true, state: .notStarted, today: today), .notStarted)
    }

    func testTheReadableDay() {
        XCTAssertNil(KitFixture.context(today: today).readableDay)
        XCTAssertNil(KitFixture.context(today: today, startsIn: 3).readableDay)
        XCTAssertEqual(KitFixture.context(today: today, day: 1).readableDay, 1)
        XCTAssertEqual(KitFixture.context(today: today, day: 90).readableDay, 90)
        XCTAssertEqual(KitFixture.context(today: today, day: 91).readableDay, 90)
        XCTAssertEqual(KitFixture.context(today: today, day: 200).readableDay, 90)
        let stopped = ProgrammeState(startedOn: today.minusDays(10), stoppedOn: today.minusDays(2))
        XCTAssertNil(KitFixture.context(today: today, state: stopped).readableDay)
    }

    func testTheDefaultContextIsNotHostedAndHoldsNothing() {
        let unhosted = EnvironmentValuesProbe.defaultContext
        XCTAssertFalse(unhosted.isHosted)
        XCTAssertFalse(unhosted.hasAccess)
        XCTAssertEqual(unhosted.accessState, .noAccess)
        XCTAssertEqual(unhosted.planInput.state, .notStarted)
        XCTAssertEqual(unhosted.planInput.today, unhosted.today)
    }

    func testThePlansOfADay() {
        let kit = KitFixture.context(today: today, day: 23)
        XCTAssertEqual(kit.todayPlan()?.day, 23)
        XCTAssertEqual(kit.dayPlan(forDay: 1)?.date, today.minusDays(22))
        XCTAssertNil(kit.dayPlan(forDay: 0))
        XCTAssertNil(kit.dayPlan(forDay: 91))
        XCTAssertEqual(kit.plans().count, 23)
        XCTAssertNil(KitFixture.context(today: today).todayPlan())
        XCTAssertNil(KitFixture.context(today: today).dayPlan(forDay: 1))
        XCTAssertNil(KitFixture.context(today: today, day: 91).todayPlan(), "day 91 is not a programme day")
        XCTAssertEqual(KitFixture.context(today: today, day: 91).plans().count, 90)
    }

    // MARK: - The inputs handed to core

    private func lh(_ daysBefore: Int) -> LhResult {
        LhResult(recordedAt: today.minusDays(daysBefore).toDate(calendar: .autoupdatingCurrent), classification: .low)
    }

    private func ph(_ daysBefore: Int) -> PhReading {
        PhReading(phValue: 4.4, recordedAt: today.minusDays(daysBefore).toDate(calendar: .autoupdatingCurrent))
    }

    func testTheReviewInputEmptiesOvulationTestDatesWithoutScanningAndPassesConsent() {
        let with = KitFixture.context(today: today, day: 10, lhResults: [lh(1), lh(2)]).reviewInput()
        XCTAssertEqual(with.lhResultDates.count, 2)
        XCTAssertTrue(with.consentActive)
        XCTAssertEqual(with.plans.count, 10)
        XCTAssertEqual(with.today, today)
        let without = KitFixture.context(today: today, day: 10, scan: false, lhResults: [lh(1), lh(2)]).reviewInput()
        XCTAssertEqual(without.lhResultDates, [])
        XCTAssertFalse(KitFixture.context(today: today, day: 10, consent: false).reviewInput().consentActive)
        let statement = ProgrammeEvidenceStatement(level: ProgrammeEvidenceLevel.allCases[0], text: "x")
        XCTAssertEqual(KitFixture.context(today: today, day: 10).reviewInput(patterns: [statement]).patterns, [statement])
    }

    func testThePictureInputPassesConsentAndHidesTestsWithoutScanning() {
        let settings = CycleSettings(lastPeriodDate: today.minusDays(8), cycleLength: 28, periodLength: 5)
        func rows(_ kit: FertilityKitContext) -> Set<FertilityPictureRowKind> {
            Set(FertilityPictureLogic.picture(kit.pictureInput()).sections.flatMap(\.rows).map(\.kind))
        }
        let with = KitFixture.context(today: today, day: 10, phReadings: [ph(1)], lhResults: [lh(1)], cycleSettings: settings)
        XCTAssertTrue(with.pictureInput().consentActive, "its default is false and would withhold the picture")
        XCTAssertTrue(with.pictureInput().scanFeaturesAvailable)
        XCTAssertNotNil(with.pictureInput().consistency)
        XCTAssertTrue(rows(with).contains(.latestLhResult))
        XCTAssertTrue(rows(with).contains(.pregnancyTestRecords))

        // The pregnancy test row is a link, there with no result saved at all: it says nothing of her.
        let noResults = KitFixture.context(today: today, day: 10, cycleSettings: settings)
        XCTAssertTrue(rows(noResults).contains(.pregnancyTestRecords))

        let without = KitFixture.context(today: today, day: 10, scan: false, phReadings: [ph(1)], lhResults: [lh(1)],
                                         cycleSettings: settings)
        XCTAssertFalse(without.pictureInput().scanFeaturesAvailable)
        XCTAssertEqual(without.pictureInput().lhResults, [])
        XCTAssertFalse(rows(without).contains(.latestLhResult))
        XCTAssertFalse(rows(without).contains(.pregnancyTestRecords))
        XCTAssertTrue(rows(without).contains(.latestPhReading), "manual pH logging exists in every build")

        XCTAssertNil(KitFixture.context(today: today, cycleSettings: settings).pictureInput().consistency,
                     "no programme, no consistency figure")
        XCTAssertTrue(FertilityPictureLogic.picture(KitFixture.context(today: today, day: 10, consent: false).pictureInput())
            .isWithheldForConsent)
    }

    func testTheNinetyDayPatternsAreAsOfDayNinety() {
        XCTAssertEqual(KitFixture.context(today: today).ninetyDayPatterns(), [], "empty before a start")

        let start = CalendarDate(2026, 1, 1)
        let settings = CycleSettings(lastPeriodDate: start.minusDays(3), cycleLength: 28, periodLength: 5)
        var logs: [CalendarDate: DailyLog] = [:]
        for day in stride(from: 1, through: 90, by: 2) {
            logs[start.plusDays(day - 1)] = DailyLog(mood: .good, energy: .normal, sleepMinutes: 450, waterMl: 2_000)
        }
        let readings = [5, 30, 60, 88].map { PhReading(phValue: 4.4, recordedAt: start.plusDays($0).toDate(calendar: .autoupdatingCurrent)) }
        func patterns(day: Int, logs: [CalendarDate: DailyLog]) -> [ProgrammeEvidenceStatement] {
            KitFixture.context(today: start.plusDays(day - 1), state: ProgrammeState(startedOn: start), logs: logs,
                               phReadings: readings, cycleSettings: settings).ninetyDayPatterns()
        }
        let onDay90 = patterns(day: 90, logs: logs)
        XCTAssertFalse(onDay90.isEmpty, "the fixture has to produce a statement, or the comparison proves nothing")
        XCTAssertEqual(patterns(day: 121, logs: logs), onDay90)
        // A log made thirty days after the programme enters no sentence under the 90-Day Review.
        var later = logs
        later[start.plusDays(119)] = DailyLog(mood: .great, energy: .high, sleepMinutes: 500, waterMl: 2_500)
        XCTAssertEqual(patterns(day: 121, logs: later), onDay90)
        // While the picture, which is about today, does see it.
        let pictureToday = KitFixture.context(today: start.plusDays(120), state: ProgrammeState(startedOn: start), logs: later,
                                              phReadings: readings, cycleSettings: settings).pictureInput()
        XCTAssertEqual(pictureToday.today, start.plusDays(120))
    }

    func testRefusedPeriodStartsAndTheNavigationAreCarried() {
        let refused: Set<CalendarDate> = [today.minusDays(40)]
        XCTAssertEqual(KitFixture.context(today: today, refusedPeriodStarts: refused).refusedPeriodStarts, refused)
        // From a container: what the repository holds, which is nothing while no server refused anything.
        let container = KitFixture.container()
        container.periods.recordStart(today.minusDays(30), today: today)
        XCTAssertEqual(KitFixture.context(from: container, today: today).refusedPeriodStarts, Set(container.periods.refusedStarts))

        var opened: [MoreDestination] = []
        var scans: [ScanDeepLink] = []
        var slugs: [String] = []
        var weeks: [Int] = []
        let kit = KitFixture.context(today: today, navigation: FertilityKitNavigation(
            open: { opened.append($0) }, openScan: { scans.append($0) },
            openGuideSection: { slugs.append($0) }, openWeeklyReview: { weeks.append($0) }))
        kit.open(.kitGuide)
        kit.openScan(.pregnancyTest)
        kit.openGuideSection("sleep")
        kit.openWeeklyReview(3)
        XCTAssertEqual(opened, [.kitGuide])
        XCTAssertEqual(scans, [.pregnancyTest])
        XCTAssertEqual(slugs, ["sleep"])
        XCTAssertEqual(weeks, [3])
    }

    // MARK: - Routes

    /// Every row of the destination table, with and without scanning, before, during and after.
    func testEveryDestinationHasItsRoute() {
        let positions: [(name: String, day: Int?, startsIn: Int?)] =
            [("not started", nil, nil), ("scheduled", nil, 3), ("day 1", 1, nil), ("day 90", 90, nil), ("day 91", 91, nil)]
        for scan in [true, false] {
            for position in positions {
                let kit = KitFixture.context(today: today, day: position.day, startsIn: position.startsIn, scan: scan)
                let started = position.day != nil || position.startsIn != nil
                let readable = position.day != nil
                let completed = position.day == 91
                let expected: [ProgrammeDestination: FertilityKitRoute] = [
                    .cycle: .tab(1),
                    .dailyLog: .dailyLog(today),
                    .hydration: .hydration,
                    .nutrition: .kit(.kitDietPlan),
                    .insights: .tab(4),
                    .programmeLesson: readable ? .kit(.kitToday) : .unavailable,
                    .weeklyReview: started ? .kit(.kitReviews) : .unavailable,
                    .programmeProgress: !started ? .unavailable : completed ? .kit(.kitNinetyDayReview) : .kit(.kitReviews),
                    .lhTest: scan ? .scan(.ovulationTest) : .unavailable,
                    .phTest: .tab(2),
                    .fertilityKitGuide: .kit(.kitGuide),
                ]
                XCTAssertEqual(expected.count, ProgrammeDestination.allCases.count, "every destination has a row")
                for destination in ProgrammeDestination.allCases {
                    XCTAssertEqual(FertilityKitRoutes.route(for: destination, in: kit), expected[destination],
                                   "\(destination) \(position.name) scan \(scan)")
                    XCTAssertEqual(FertilityKitRoutes.route(for: FertilityPictureDestination.programme(destination), in: kit),
                                   expected[destination])
                }
                XCTAssertEqual(FertilityKitRoutes.route(for: FertilityPictureDestination.pregnancyTestScreen, in: kit),
                               .scan(.pregnancyTest))
            }
        }
        let stopped = KitFixture.context(today: today, state: ProgrammeState(startedOn: today.minusDays(10), stoppedOn: today.minusDays(2)))
        XCTAssertEqual(FertilityKitRoutes.route(for: ProgrammeDestination.programmeLesson, in: stopped), .unavailable)
        XCTAssertEqual(FertilityKitRoutes.route(for: ProgrammeDestination.weeklyReview, in: stopped), .kit(.kitReviews))
    }

    /// The lesson task of a test-guidance day names the guide, but the record that completes it
    /// is the day's page, so it goes there. Every other task goes where its destination goes.
    func testTaskRoutes() throws {
        for day in [1, 40, 47] {
            let kit = KitFixture.context(today: today, day: day,
                                         cycleSettings: CycleSettings(lastPeriodDate: today.minusDays(8), cycleLength: 28, periodLength: 5))
            let plan = try XCTUnwrap(kit.todayPlan())
            XCTAssertFalse(plan.tasks.isEmpty)
            for task in plan.tasks + plan.weeklyTasks {
                if task.category == .fertilityKitEducation {
                    XCTAssertEqual(task.destination, .fertilityKitGuide)
                    XCTAssertEqual(FertilityKitRoutes.route(forTask: task, in: kit), .kit(.kitToday), "day \(day)")
                } else {
                    XCTAssertEqual(FertilityKitRoutes.route(forTask: task, in: kit),
                                   FertilityKitRoutes.route(for: task.destination, in: kit), "day \(day) \(task.category)")
                }
            }
            let hasGuidanceLesson = plan.tasks.contains { $0.category == .fertilityKitEducation }
            XCTAssertEqual(hasGuidanceLesson, day != 1, "days 40 and 47 are the test-guidance days")
        }
    }

    func testContentReferenceRoutes() {
        let kit = KitFixture.context(today: today, day: 5)
        XCTAssertEqual(FertilityKitRoutes.route(for: ProgrammeContentReference.learnArticle(slug: "a"), in: kit, isPublished: { _ in true }),
                       .learnArticle("a"))
        XCTAssertEqual(FertilityKitRoutes.route(for: ProgrammeContentReference.learnArticle(slug: "a"), in: kit, isPublished: { _ in false }),
                       .unavailable, "an article Learn would refuse is never offered")
        XCTAssertEqual(FertilityKitRoutes.route(for: ProgrammeContentReference.recipe(id: "r"), in: kit, isPublished: { _ in false }),
                       .kit(.kitDietPlan))
    }

    func testGuideSectionRoutesAndVisibility() throws {
        XCTAssertEqual(ProgrammeGuideDraft.sections.count, 30)
        for scan in [true, false] {
            let kit = KitFixture.context(today: today, day: 5, scan: scan)
            let overrides: [String: FertilityKitRoute] = [
                "your-fertility-kit": .kit(.fertilityKit),
                "pregnancy-tests": .kit(.fertilityKit),
                "understanding-test-history": .kit(.kitPicture),
                "nutrition": .dailyLog(today),
                "lh-testing": scan ? .scan(.ovulationTest) : .unavailable,
                "scanning-an-ovulation-test": scan ? .scan(.ovulationTest) : .unavailable,
                "scanning-a-ph-test": .tab(2),
            ]
            for slug in overrides.keys { XCTAssertNotNil(ProgrammeGuideDraft.section(slug: slug), "no section \(slug)") }
            for section in ProgrammeGuideDraft.sections {
                XCTAssertEqual(FertilityKitRoutes.route(forGuideSection: section, in: kit),
                               overrides[section.slug] ?? FertilityKitRoutes.route(for: section.callToAction.destination, in: kit),
                               section.slug)
                XCTAssertEqual(FertilityKitRoutes.isVisible(section, in: kit),
                               section.slug != "scanning-an-ovulation-test" || scan, section.slug)
            }
            XCTAssertEqual(ProgrammeGuideDraft.sections.filter { FertilityKitRoutes.isVisible($0, in: kit) }.count, scan ? 30 : 29)
        }
        // A pregnancy test section never leads to a results screen.
        let section = try XCTUnwrap(ProgrammeGuideDraft.section(slug: "pregnancy-tests"))
        XCTAssertNotEqual(FertilityKitRoutes.route(forGuideSection: section, in: KitFixture.context(today: today, day: 5)),
                          .scan(.pregnancyTest))
    }

    // MARK: - The clock and the seed

    func testTheClock() {
        let device = CalendarDate(2026, 10, 6)
        let anchor = CalendarDate(2026, 10, 5)
        XCTAssertEqual(FertilityKitClock.resolve(anchorDayNumber: anchor.dayNumber, shift: 0, deviceToday: device), anchor)
        XCTAssertEqual(FertilityKitClock.resolve(anchorDayNumber: anchor.dayNumber, shift: 1, deviceToday: device), device)
        XCTAssertEqual(FertilityKitClock.resolve(anchorDayNumber: nil, shift: 0, deviceToday: device), device)
        XCTAssertEqual(FertilityKitClock.resolve(anchorDayNumber: nil, shift: 1, deviceToday: device), device.plusDays(1))
        // Outside a seeded launch the clock is the device's date, in the plan source's calendar.
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "uiTestSeed"))
        XCTAssertEqual(FertilityKitClock.current(), CalendarDate.today(.autoupdatingCurrent))
    }

    func testTheSeedReadsOnlyNumbersAboveNought() {
        XCTAssertNil(KitUITestSeed.positive(nil))
        XCTAssertNil(KitUITestSeed.positive("soon"))
        XCTAssertNil(KitUITestSeed.positive("0"))
        XCTAssertNil(KitUITestSeed.positive("-22"))
        XCTAssertEqual(KitUITestSeed.positive("23"), 23)

        let anchor = CalendarDate(2026, 10, 6)
        XCTAssertNil(KitUITestSeed().startDate(anchor: anchor))
        XCTAssertEqual(KitUITestSeed(day: 1).startDate(anchor: anchor), anchor)
        XCTAssertEqual(KitUITestSeed(day: 23).startDate(anchor: anchor), anchor.minusDays(22))
        XCTAssertEqual(KitUITestSeed(day: 90).startDate(anchor: anchor), anchor.minusDays(89))
        XCTAssertEqual(KitUITestSeed(day: 91).startDate(anchor: anchor), anchor.minusDays(90))
        XCTAssertEqual(KitUITestSeed(startsIn: 3).startDate(anchor: anchor), anchor.plusDays(3))
        XCTAssertEqual(KitUITestSeed(day: 23, startsIn: 3).startDate(anchor: anchor), anchor.minusDays(22), "the day wins")

        let defaults = UserDefaults(suiteName: "kit.seed.\(UUID().uuidString)")!
        XCTAssertEqual(KitUITestSeed(defaults: defaults), KitUITestSeed())
        defaults.set("YES", forKey: "uiTestKitAccess")
        defaults.set("23", forKey: "uiTestKitDay")
        defaults.set("-3", forKey: "uiTestKitStartsIn")
        defaults.set("4", forKey: "uiTestKitLogs")
        defaults.set("trying", forKey: "uiTestKitGoal")
        defaults.set("no", forKey: "uiTestKitSupplements")
        XCTAssertEqual(KitUITestSeed(defaults: defaults),
                       KitUITestSeed(access: true, day: 23, startsIn: nil, logs: 4, goal: "trying", supplements: "no"))
    }

    func testTheSeedGrantsStartsLogsAndAnswers() {
        let anchor = today
        let container = KitFixture.container()
        KitUITestSeed(access: true, day: 23, logs: 3, goal: "trying", supplements: "yes").apply(to: container, anchor: anchor)
        XCTAssertTrue(container.kitAccess.hasAccess)
        XCTAssertEqual(container.programme.state.startedOn, anchor.minusDays(22))
        XCTAssertEqual(container.prefs.quizAnswers, ["stage": "trying", "supplements": "yes"], "one call: neither answer replaces the other")
        for daysBefore in 1...3 {
            XCTAssertEqual(container.dailyLog.logByDate[anchor.minusDays(daysBefore)]?.foodGroups,
                           ["vegetables", "fruit", "protein", "starchyCarbs"])
        }
        XCTAssertNil(container.dailyLog.logByDate[anchor.minusDays(4)])
        XCTAssertNil(container.dailyLog.logByDate[anchor])
        XCTAssertEqual(KitFixture.context(from: container, today: anchor).accessState,
                       .active(day: 23, week: 4, phase: .buildTheFoundation))

        // A second seeded launch starts from nothing.
        KitUITestSeed(access: true, startsIn: 3).apply(to: container, anchor: anchor)
        XCTAssertEqual(KitFixture.context(from: container, today: anchor).accessState,
                       .scheduled(startsOn: anchor.plusDays(3), daysUntilStart: 3))
        KitUITestSeed(access: true).apply(to: container, anchor: anchor)
        XCTAssertEqual(KitFixture.context(from: container, today: anchor).accessState, .notStarted)
        // A day without access starts nothing: activation never starts day 1, and neither does a seed.
        KitUITestSeed(access: false, day: 5).apply(to: container, anchor: anchor)
        XCTAssertFalse(container.kitAccess.hasAccess)
        XCTAssertNil(container.programme.state.startedOn)
        XCTAssertEqual(KitFixture.context(from: container, today: anchor).accessState, .noAccess)
    }

    /// The figures the journeys J10 and J12 look for, from the same seed a launch runs. A change
    /// to the seed or to the consistency rule turns this red before a journey.
    func testTheJourneyFigures() throws {
        func kit(day: Int) -> FertilityKitContext {
            let container = KitFixture.container()
            KitFixture.baseSeed(on: container, anchor: today)
            KitUITestSeed(access: true, day: day).apply(to: container, anchor: today)
            return KitFixture.context(from: container, today: today)
        }
        // Day 1: mood, energy, sleep, hydration and the ovulation test (cycle day 9 is inside the
        // predicted window) are counted; 750 ml is part of the water goal; no period figure yet.
        let dayOne = kit(day: 1).report()
        XCTAssertEqual(FertilityKitCopy.todayProgressLines(try XCTUnwrap(dayOne.today)),
                       ["0 of 5 activities completed today", "1 activity partly completed"])
        XCTAssertEqual(ProgrammeReviewLogic.lines(for: dayOne.week), [], "period figures stop at yesterday")

        // Day 2: yesterday's four check-ins and this week's pH reading.
        XCTAssertEqual(ProgrammeReviewLogic.lines(for: kit(day: 2).report().week),
                       ["95%", "4 of 5 activities completed, 1 partly completed"])

        // Day 4: one activity is below the minimum for a percentage, the programme is not.
        let dayFour = kit(day: 4).report()
        XCTAssertEqual(ProgrammeReviewLogic.lines(for: try XCTUnwrap(dayFour.categories[.moodCheckIn])),
                       ["2 of 3 activities completed"])
        XCTAssertEqual(ProgrammeReviewLogic.lines(for: dayFour.programme),
                       ["66%", "7 of 13 activities completed, 2 partly completed"])
    }

    // MARK: - Access through the container

    func testSignOutWipesTheAccessCacheAndTheProgramme() {
        let container = KitFixture.container()
        container.kitAccess.seedGrantForUITests()
        XCTAssertEqual(container.programme.start(today: today), .started(today))
        XCTAssertNotNil(container.store.load(ProgrammeAccess.self, forKey: "fertility_kit_access"))
        XCTAssertNotNil(container.store.load(ProgrammeProgressDTO.self, forKey: "programme_progress"))

        container.session.signOut()
        XCTAssertFalse(container.kitAccess.hasAccess)
        XCTAssertEqual(container.programme.state, .notStarted)
        XCTAssertNil(container.store.load(ProgrammeAccess.self, forKey: "fertility_kit_access"))
        XCTAssertNil(container.store.load(ProgrammeProgressDTO.self, forKey: "programme_progress"))
    }

    func testTheSeededGrantSurvivesARefreshAndTheResetRemovesIt() async {
        let container = KitFixture.container()
        container.kitAccess.seedGrantForUITests()
        XCTAssertTrue(container.kitAccess.hasAccess)
        XCTAssertEqual(container.kitAccess.source, .internalQA)
        let verified = await container.kitAccess.refresh()
        XCTAssertEqual(verified, .verified(hasAccess: true), "the stand-in server's ledger holds the grant")
        await container.hydrate()
        XCTAssertTrue(container.kitAccess.hasAccess)

        XCTAssertEqual(container.programme.start(today: today), .started(today))
        container.kitAccess.resetForQA()
        XCTAssertFalse(container.kitAccess.hasAccess)
        let after = await container.kitAccess.refresh()
        XCTAssertEqual(after, .verified(hasAccess: false))
        XCTAssertEqual(container.programme.state.startedOn, today, "the reset is about access only")
    }

    func testASeedWithNobodySignedInGrantsNothing() {
        let container = KitFixture.container()
        container.session.signOut()
        container.kitAccess.seedGrantForUITests()
        XCTAssertFalse(container.kitAccess.hasAccess)
    }
}

/// Reads the environment default without a view.
private enum EnvironmentValuesProbe {
    static var defaultContext: FertilityKitContext { EnvironmentValues().fertilityKit }
}
