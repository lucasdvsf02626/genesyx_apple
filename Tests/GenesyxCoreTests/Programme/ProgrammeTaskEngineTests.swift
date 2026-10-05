import XCTest
@testable import GenesyxCore

/// The task rules: where each completion comes from, what makes an activity not applicable, and
/// what can never move a status.
final class ProgrammeTaskEngineTests: XCTestCase {

    private typealias F = ProgrammeFixtures

    // ── No plan outside the programme ──

    func testNoPlanWhenNotStartedBeforeTheStartOrAfterDay90() {
        let snapshot = F.snapshotA()
        func plan(_ state: ProgrammeState, _ date: CalendarDate) -> ProgrammeDayPlan? {
            ProgrammeTaskEngine.plan(on: date, state: state, today: date, goal: .understandMyCycle, snapshot: snapshot)
        }
        XCTAssertNil(plan(.notStarted, F.start))
        XCTAssertNil(plan(F.state, F.start.minusDays(1)))
        XCTAssertNil(plan(F.state, F.date(ofDay: 91)))
        XCTAssertEqual(plan(F.state, F.start)?.day, 1)
        XCTAssertEqual(plan(F.state, F.date(ofDay: 90))?.week, 13)
    }

    // ── Derived completion ──

    func testEachTrackerCompletionIsReadFromItsOwnField() {
        let plan = F.plan(F.snapshotA())
        let expected: [(ProgrammeTaskCategory, ProgrammeCompletionSource, ProgrammeTaskStatus)] = [
            (.moodCheckIn, .logMood, .completed), (.energyCheckIn, .logEnergy, .completed),
            (.sleepCheckIn, .logSleepMinutes, .completed), (.hydrationCheckIn, .logWaterMl, .completed),
            (.supplementCheckIn, .logSupplements, .completed), (.nutritionCheckIn, .logFoodGroups, .optional),
            (.cycleCheckIn, .cycleSettings, .optional),
        ]
        for (category, source, status) in expected {
            let task = plan.task(category)
            XCTAssertEqual(task?.completionSource, source, "\(category)")
            XCTAssertEqual(task?.status, status, "\(category)")
            XCTAssertEqual(task?.id, category.rawValue)
        }
        XCTAssertEqual(plan.weekly(.phTest)?.completionSource, .phReading)
        XCTAssertEqual(F.plan(F.snapshotB()).task(.lhTest)?.completionSource, .lhResult)
        // Nothing recorded, nothing claimed.
        XCTAssertTrue(F.plan(F.snapshotC()).tasks.allSatisfy { $0.completionSource == nil || $0.category == .cycleCheckIn })
    }

    func testOpenTodayIsEligibleAndTheSameDayOnceOverIsSkipped() {
        let today = F.plan(day: 23, todayDay: 23, F.snapshotC())
        let later = F.plan(day: 23, todayDay: 24, F.snapshotC())
        for category in [ProgrammeTaskCategory.moodCheckIn, .energyCheckIn, .sleepCheckIn, .hydrationCheckIn, .supplementCheckIn] {
            XCTAssertEqual(today.task(category)?.status, .eligible)
            XCTAssertEqual(later.task(category)?.status, .skipped)
            XCTAssertEqual(later.task(category)?.credit, 0)
        }
    }

    func testAStoredZeroForSleepIsACheckIn() {
        var snapshot = F.snapshotA()
        snapshot.log?.sleepMinutes = 0
        XCTAssertEqual(F.plan(snapshot).task(.sleepCheckIn)?.credit, 1)
        snapshot.log?.sleepMinutes = nil
        XCTAssertEqual(F.plan(snapshot).task(.sleepCheckIn)?.credit, 0)
    }

    // ── Hydration: the one proportional credit ──

    func testHydrationCreditIsProportionalAndCappedAtOne() {
        var snapshot = F.snapshotA()
        for (water, credit) in [(0, 0.0), (600, 0.25), (1200, 0.5), (1500, 0.625), (2400, 1.0), (3600, 1.0)] {
            snapshot.log?.waterMl = water
            XCTAssertEqual(F.plan(snapshot).task(.hydrationCheckIn)?.credit, credit, "\(water) ml")
        }
        snapshot.log?.waterMl = 1000
        snapshot.waterGoalMl = 2000
        XCTAssertEqual(F.plan(snapshot).task(.hydrationCheckIn)?.credit, 0.5)
        XCTAssertEqual(ProgrammeDaySnapshot().waterGoalMl, TrackingEngine.defaultWaterGoalMl)
    }

    // ── Nutrition: done or not done, never how much ──

    func testNutritionCreditIsOneWithOneFoodGroupAndOneWithSix() {
        var snapshot = F.snapshotA()
        for content in [ProgrammeContent.draft, F.content(.nutritionCheckIn, .eligible)] {
            snapshot.log?.foodGroups = []
            XCTAssertEqual(F.plan(snapshot, content: content).task(.nutritionCheckIn)?.credit, 0)
            snapshot.log?.foodGroups = ["fruit"]
            let one = F.plan(snapshot, content: content)
            XCTAssertEqual(one.task(.nutritionCheckIn)?.credit, 1)
            XCTAssertEqual(one.foodGroupsRecorded, 1)
            snapshot.log?.foodGroups = Set(FoodGroup.allCases.map(\.rawValue))
            let six = F.plan(snapshot, content: content)
            XCTAssertEqual(six.task(.nutritionCheckIn)?.credit, 1)
            XCTAssertEqual(six.foodGroupsRecorded, 6)
            XCTAssertEqual(six.foodGroupTotal, 6)
            XCTAssertEqual(one.task(.nutritionCheckIn), six.task(.nutritionCheckIn))
            XCTAssertEqual(ProgrammeConsistency.day(one), ProgrammeConsistency.day(six))
        }
    }

    func testWhereTheScheduleCountsNutritionItCountsOneWholeActivity() {
        var snapshot = F.snapshotA()
        snapshot.log?.foodGroups = ["fruit"]
        let plan = F.plan(snapshot, content: F.content(.nutritionCheckIn, .eligible))
        XCTAssertEqual(plan.task(.nutritionCheckIn)?.status, .completed)
        let figure = ProgrammeConsistency.day(plan)
        XCTAssertEqual(figure.counted, 6)
        XCTAssertEqual(figure.credit, 5.625)
    }

    func testAFoodGroupTokenThisBuildDoesNotKnowIsACheckInButNotOneOfTheSix() {
        var snapshot = F.snapshotA()
        snapshot.log?.foodGroups = ["somethingNewer"]
        let plan = F.plan(snapshot)
        XCTAssertEqual(plan.task(.nutritionCheckIn)?.credit, 1)
        XCTAssertEqual(plan.foodGroupsRecorded, 0)
    }

    // ── Ovulation test ──

    func testLhIsCountedOnlyInsideThePredictedWindowWithTheFeatureAvailable() {
        // Cycle days 9 to 15 are the predicted window for a 28-day cycle.
        for cycleDay in 1...28 {
            var snapshot = F.snapshotB()
            snapshot.cycleSettings = F.settings(day: 23, onCycleDay: cycleDay)
            let task = F.plan(snapshot).task(.lhTest)
            if (9...15).contains(cycleDay) {
                XCTAssertEqual(task?.status, .completed, "cycle day \(cycleDay)")
            } else {
                XCTAssertEqual(task?.status, .notApplicable, "cycle day \(cycleDay)")
                XCTAssertEqual(task?.notApplicableReason, .outsidePredictedFertileWindow)
            }
        }
    }

    func testTheWindowIsTheCycleEnginesOwn() {
        for length in CycleEngine.cycleLengthRange {
            for cycleDay in 1...length {
                var snapshot = F.snapshotB()
                let settings = F.settings(day: 23, onCycleDay: cycleDay, cycleLength: length)
                snapshot.cycleSettings = settings
                let info = CycleEngine.cyclePhase(settings: settings, target: F.date(ofDay: 23))
                XCTAssertEqual(F.plan(snapshot).task(.lhTest)?.isCounted, info.fertileWindow.contains(info.dayOfCycle))
            }
        }
    }

    func testLhIsNotApplicableWithoutTheFeatureOrWithoutCycleSettings() {
        var snapshot = F.snapshotB()
        snapshot.scanFeaturesAvailable = false
        XCTAssertEqual(F.plan(snapshot).task(.lhTest)?.notApplicableReason, .featureUnavailable)
        XCTAssertEqual(F.plan(snapshot).task(.lhTest)?.status, .notApplicable)
        snapshot.scanFeaturesAvailable = true
        snapshot.cycleSettings = nil
        XCTAssertEqual(F.plan(snapshot).task(.lhTest)?.notApplicableReason, .noCycleSettings)
    }

    func testInsideTheWindowWithNoResultTheTestIsOpenThenSkipped() {
        var snapshot = F.snapshotB()
        snapshot.lhResultExistsForDate = false
        XCTAssertEqual(F.plan(day: 23, todayDay: 23, snapshot).task(.lhTest)?.status, .eligible)
        XCTAssertEqual(F.plan(day: 23, todayDay: 24, snapshot).task(.lhTest)?.status, .skipped)
    }

    // ── pH: once per programme week ──

    func testPhIsNeverInTheDayAndCarriesTheWeeksState() {
        let done = F.plan(F.snapshotA())
        XCTAssertEqual(done.task(.phTest)?.status, .notApplicable)
        XCTAssertEqual(done.task(.phTest)?.notApplicableReason, .countedOncePerProgrammeWeek)
        XCTAssertEqual(done.weekly(.phTest)?.status, .completed)
        XCTAssertEqual(done.weeklyTasks.count, 1)

        // Week 4 is days 22 to 28: open until the week is over, then skipped.
        XCTAssertEqual(F.plan(day: 23, todayDay: 28, F.snapshotB()).weekly(.phTest)?.status, .eligible)
        XCTAssertEqual(F.plan(day: 23, todayDay: 29, F.snapshotB()).weekly(.phTest)?.status, .skipped)
        XCTAssertEqual(F.plan(day: 23, todayDay: 29, F.snapshotB()).task(.phTest)?.status, .notApplicable)
    }

    func testPhIsNotApplicableOnlyWhereItCannotBeLoggedAtAll() {
        XCTAssertTrue(ProgrammeDaySnapshot().phLoggingAvailable, "manual pH entry exists in every build")
        var snapshot = F.snapshotB()
        snapshot.phLoggingAvailable = false
        let plan = F.plan(snapshot)
        XCTAssertEqual(plan.task(.phTest)?.notApplicableReason, .featureUnavailable)
        XCTAssertEqual(plan.weekly(.phTest)?.notApplicableReason, .featureUnavailable)
    }

    // ── Supplements follow the onboarding answer ──

    func testSupplementsFollowTheStoredOnboardingAnswer() {
        var snapshot = F.snapshotC()
        for answer in ["yes", "some"] {
            snapshot.supplementsAnswer = answer
            XCTAssertEqual(F.plan(snapshot).task(.supplementCheckIn)?.status, .eligible)
        }
        snapshot.supplementsAnswer = "no"
        XCTAssertEqual(F.plan(snapshot).task(.supplementCheckIn)?.notApplicableReason, .onboardingAnswer)
        for answer in ["guidance", nil, "somethingElse"] {
            snapshot.supplementsAnswer = answer
            XCTAssertEqual(F.plan(snapshot).task(.supplementCheckIn)?.status, .optional)
        }
    }

    // ── Never counted ──

    func testThePregnancyCategoryIsNeverEligibleInAnyDayForAnyGoalOrSchedule() {
        var everything = F.snapshotB()
        everything.completedLessonIDs = Set(ProgrammeContent.draft.days.map(\.lesson.id))
        for content in [ProgrammeContent.draft, F.content(.pregnancyTestRelatedAction, .eligible)] {
            for day in 1...90 {
                for goal in ProgrammeGoalEmphasis.allCases {
                    let plan = F.plan(day: day, goal: goal, everything, content: content)
                    for task in plan.tasks + plan.weeklyTasks where task.category == .pregnancyTestRelatedAction {
                        XCTAssertEqual(task.status, .notApplicable)
                        XCTAssertEqual(task.notApplicableReason, .educationOnly)
                        XCTAssertEqual(task.credit, 0)
                        XCTAssertFalse(task.isCounted)
                    }
                }
            }
        }
        // It is on the schedule in the tests week, so the loop above did look at something.
        XCTAssertNotNil(F.plan(day: 45, F.snapshotA()).task(.pregnancyTestRelatedAction))
        XCTAssertEqual(F.plan(day: 45, F.snapshotA(), content: F.content(.pregnancyTestRelatedAction, .eligible))
            .task(.pregnancyTestRelatedAction)?.destination, .fertilityKitGuide)
    }

    func testSymptomsCycleAndPeriodCanNeverBeCountedWhateverTheScheduleSays() {
        for category in [ProgrammeTaskCategory.symptomCheckIn, .cycleCheckIn, .periodLog] {
            var snapshot = F.snapshotA()
            snapshot.log?.symptoms = ["cramps"]
            snapshot.periodRecordExistsForDate = true
            let task = F.plan(snapshot, content: F.content(category, .eligible)).task(category)
            XCTAssertEqual(task?.status, .optional, "\(category)")
            XCTAssertEqual(task?.credit, 1)
            XCTAssertEqual(task?.isCounted, false)
        }
    }

    func testLessonsAndReviewsAreExplicitOptionalAndNeverCounted() {
        var snapshot = F.snapshotA(day: 28)
        let open = F.plan(day: 28, snapshot)   // day 28 is week 4's weekly review
        XCTAssertEqual(open.task(.programmeLesson)?.status, .optional)
        XCTAssertNil(open.task(.programmeLesson)?.completionSource)
        XCTAssertEqual(open.task(.weeklyReview)?.status, .optional)

        snapshot.completedLessonIDs = ["programme-day-028"]
        snapshot.completedReviewWeeks = [4]
        let done = F.plan(day: 28, snapshot)
        XCTAssertEqual(done.task(.programmeLesson)?.completionSource, .explicitRecord)
        XCTAssertEqual(done.task(.weeklyReview)?.completionSource, .explicitRecord)
        XCTAssertEqual(done.task(.programmeLesson)?.isCounted, false)
        XCTAssertEqual(ProgrammeConsistency.day(open), ProgrammeConsistency.day(done))

        // Another day's lesson, or another week's review, completes nothing here.
        snapshot.completedLessonIDs = ["programme-day-027"]
        snapshot.completedReviewWeeks = [3]
        XCTAssertNil(F.plan(day: 28, snapshot).task(.programmeLesson)?.completionSource)
        XCTAssertNil(F.plan(day: 28, snapshot).task(.weeklyReview)?.completionSource)

        // Test-guidance days carry kit education instead of a lesson; other days have no review.
        XCTAssertNotNil(F.plan(day: 40, F.snapshotA(day: 40)).task(.fertilityKitEducation))
        XCTAssertNil(F.plan(day: 40, F.snapshotA(day: 40)).task(.programmeLesson))
        XCTAssertNil(F.plan(day: 23, F.snapshotA()).task(.weeklyReview))
    }

    func testIntimacyIsNeverATaskAndNeverRead() {
        var with = F.snapshotA()
        var without = F.snapshotA()
        with.log?.sexualActivity = true
        without.log?.sexualActivity = false
        XCTAssertEqual(F.plan(with), F.plan(without))
        // A day whose only entry is that field has nothing recorded as far as the programme goes.
        var only = F.snapshotC()
        only.log = DailyLog(sexualActivity: true)
        XCTAssertEqual(F.plan(day: 23, todayDay: 24, only), F.plan(day: 23, todayDay: 24, F.snapshotC()))
        XCTAssertFalse(ProgrammeTaskCategory.allCases.contains { $0.rawValue.lowercased().contains("intima") })
        XCTAssertEqual(ProgrammeTaskCategory.allCases.count, 15)
    }

    func testWithdrawnConsentMakesEverythingNotApplicable() {
        var snapshot = F.snapshotB()
        snapshot.consentActive = false
        let plan = F.plan(snapshot)
        XCTAssertTrue((plan.tasks + plan.weeklyTasks).allSatisfy { $0.status == .notApplicable })
        XCTAssertNil(ProgrammeConsistency.day(plan).percentage)
    }

    // ── Goal emphasis ──

    func testTheStoredOnboardingStageMapsToAnEmphasis() {
        XCTAssertEqual(QuizContent.questions.first { $0.id == "stage" }?.options.map(\.id),
                       ["exploring", "preparing", "trying", "support"])
        XCTAssertEqual(ProgrammeGoalEmphasis(storedStage: "exploring"), .understandMyCycle)
        XCTAssertEqual(ProgrammeGoalEmphasis(storedStage: "preparing"), .prepareForPregnancy)
        XCTAssertEqual(ProgrammeGoalEmphasis(storedStage: "trying"), .tryingToConceive)
        XCTAssertEqual(ProgrammeGoalEmphasis(storedStage: "support"), .understandMyCycle)
        XCTAssertEqual(ProgrammeGoalEmphasis(storedStage: nil), .understandMyCycle)
        XCTAssertEqual(ProgrammeGoalEmphasis(storedStage: "futureValue"), .understandMyCycle)
        XCTAssertEqual(QuizContent.questions.first { $0.id == "supplements" }?.options.map(\.id),
                       ["yes", "some", "no", "guidance"])
    }

    func testTheGoalChangesTheOrderAndTheOptionalExtrasButNoStatusCreditOrTotal() {
        for snapshot in [F.snapshotA(), F.snapshotB(), F.snapshotC()] {
            let plans = ProgrammeGoalEmphasis.allCases.map { F.plan(goal: $0, snapshot) }
            XCTAssertEqual(plans.map { $0.tasks.first?.category }, [.cycleCheckIn, .nutritionCheckIn, .lhTest])
            XCTAssertNotEqual(plans[0].tasks.map(\.category), plans[1].tasks.map(\.category))

            let figures = plans.map { ProgrammeConsistency.day($0) }
            XCTAssertEqual(figures[0], figures[1])
            XCTAssertEqual(figures[1], figures[2])
            // Every task the three share has the same status and credit under each goal.
            for task in plans[1].tasks {
                XCTAssertEqual(plans[0].task(task.category), task)
                XCTAssertEqual(plans[2].task(task.category), task)
            }
            // The extras are optional ones only.
            let extras = Set(plans[0].tasks.map(\.category)).subtracting(plans[1].tasks.map(\.category))
            XCTAssertEqual(extras, [.cycleCheckIn, .periodLog])
            XCTAssertTrue(plans[0].tasks.filter { extras.contains($0.category) }.allSatisfy { $0.status == .optional })
            XCTAssertEqual(plans.map(\.weeklyTasks).count, 3)
            XCTAssertEqual(plans[0].weeklyTasks, plans[2].weeklyTasks)
        }
    }

    // ── Destinations ──

    func testEveryCategoryHasATypedDestination() {
        let expected: [ProgrammeTaskCategory: ProgrammeDestination] = [
            .cycleCheckIn: .cycle, .periodLog: .cycle, .sleepCheckIn: .dailyLog, .moodCheckIn: .dailyLog,
            .energyCheckIn: .dailyLog, .symptomCheckIn: .dailyLog, .supplementCheckIn: .dailyLog,
            .hydrationCheckIn: .hydration, .nutritionCheckIn: .nutrition, .programmeLesson: .programmeLesson,
            .weeklyReview: .weeklyReview, .lhTest: .lhTest, .phTest: .phTest,
            .pregnancyTestRelatedAction: .fertilityKitGuide, .fertilityKitEducation: .fertilityKitGuide,
        ]
        for category in ProgrammeTaskCategory.allCases {
            XCTAssertEqual(ProgrammeTaskEngine.destination(for: category), expected[category], "\(category)")
        }
    }

    func testOpenCountedTasksIsWhatAReminderNeeds() {
        XCTAssertEqual(F.plan(F.snapshotA()).openCountedTasks, 1)   // water part done
        XCTAssertEqual(F.plan(F.snapshotB()).openCountedTasks, 1)   // supplements
        XCTAssertEqual(F.plan(F.snapshotC()).openCountedTasks, 5)
    }
}
