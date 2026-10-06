import XCTest
@testable import GenesyxCore

/// The 90-Day Programme's reminders. They extend `NotificationPlanner`; there is no second system.
///
/// Two things are pinned here. Without a programme the plan is exactly what it was before the
/// programme existed, sentence for sentence. With one, the planner answers every question before
/// it speaks: access, started, day 1 to 90, something still open, not told already, category on,
/// the day free, room in the week.
///
/// The programme speaks in two ways. The review line is a weekly nudge: one of the week's four,
/// behind the fertile nudge and ahead of the evergreen ones. The line about today is that day's
/// one daily message, in the evening check-in's place, on a day no weekly nudge owns.
final class NotificationPlannerProgrammeTests: XCTestCase {

    private let library = [
        LearnCandidate(slug: "ph-trend", title: "Reading your pH trend", readingTime: "4 min read", tags: ["ph"], read: false),
        LearnCandidate(slug: "hydration", title: "Hydration and your cycle", readingTime: "3 min read", tags: ["hydration"], read: false),
        LearnCandidate(slug: "fatigue", title: "When energy dips", readingTime: "5 min read", tags: ["fatigue"], read: false),
    ]

    /// The same builder `NotificationPlannerTests` uses, with the programme added last.
    private func snapshot(daily: Int = 0, best: Int = 0, weekDays: Int = 0, weekly: Int = 0,
                          daysSinceLastPh: Int? = 1, phCount: Int = 6,
                          daysSinceLastLog: Int? = 0,
                          topSymptom: (String, Int)? = nil,
                          learn: [LearnCandidate]? = nil,
                          sent: [NotificationSlot: Int] = [:],
                          loggedToday: Bool = false, waterToday: Int = 0,
                          reminderHour: Int = 19,
                          fertileInDays: Int? = nil, todayWeekday: Int = 1,
                          muted: Set<NotificationCategory> = [],
                          programme: ProgrammeReminderFacts? = nil) -> NotificationSnapshot {
        NotificationSnapshot(
            streak: StreakState(dailyHydration: daily, weeklyStreak: weekly,
                                daysLoggedThisWeek: weekDays, bestDailyStreak: best,
                                milestones: [], lapsedCelebrations: [], weekDots: []),
            daysSinceLastPh: daysSinceLastPh,
            phReadingsLast30Days: phCount,
            daysSinceLastLog: daysSinceLastLog,
            topSymptom: topSymptom.map { (name: $0.0, count: $0.1) },
            learnCandidates: learn ?? library,
            daysSinceSent: sent,
            hasMeaningfulLogToday: loggedToday, waterTodayMl: waterToday,
            reminderHour: reminderHour,
            daysUntilFertileWindow: fertileInDays, todayWeekday: todayWeekday,
            mutedCategories: muted,
            programme: programme)
    }

    /// Access held, programme running, four counted activities and none done, seven in the
    /// morning and nothing delivered yet today, unless a test says otherwise. Day 18 is in week 3.
    private func facts(access: Bool = true, started: Bool = true, day: Int = 18,
                       activities: Int = 4, done: Int = 0,
                       testOpen: Bool = false, review: Int? = nil,
                       hour: Int = 7, notifiedToday: Bool = false) -> ProgrammeReminderFacts {
        ProgrammeReminderFacts(hasAccess: access, started: started, day: day,
                               week: ProgrammeCalendar.week(forDay: day),
                               activitiesToday: activities, activitiesDone: done,
                               ovulationTestOpen: testOpen, reviewReadyWeek: review,
                               hourNow: hour, notifiedToday: notifiedToday)
    }

    /// The same snapshot, with a programme, and with any further categories switched off.
    private func adding(_ programme: ProgrammeReminderFacts, to s: NotificationSnapshot,
                        muting: Set<NotificationCategory> = []) -> NotificationSnapshot {
        NotificationSnapshot(
            streak: s.streak, daysSinceLastPh: s.daysSinceLastPh,
            phReadingsLast30Days: s.phReadingsLast30Days, daysSinceLastLog: s.daysSinceLastLog,
            topSymptom: s.topSymptom, learnCandidates: s.learnCandidates, daysSinceSent: s.daysSinceSent,
            hasMeaningfulLogToday: s.hasMeaningfulLogToday, waterTodayMl: s.waterTodayMl,
            waterGoalMl: s.waterGoalMl, reminderHour: s.reminderHour,
            daysUntilFertileWindow: s.daysUntilFertileWindow, todayWeekday: s.todayWeekday,
            mutedCategories: s.mutedCategories.union(muting), programme: programme)
    }

    private func plan(_ s: NotificationSnapshot) -> NotificationPlan { NotificationPlanner.plan(s) }

    /// The programme's lines in a plan. Never more than one.
    private func programmeLines(_ p: NotificationPlan) -> [PlannedNotification] {
        p.notifications.filter { $0.slot.category == .programme }
    }

    /// The nudges that count against the weekly budget of four: everything but the check-in and
    /// the programme's line about today, which is said in the check-in's place.
    private func budgeted(_ p: NotificationPlan) -> [PlannedNotification] {
        p.weekly.filter { $0.slot != .programme }
    }

    /// The programme line planned for these facts on an otherwise ordinary Monday.
    private func line(_ programme: ProgrammeReminderFacts) -> PlannedNotification? {
        programmeLines(plan(snapshot(programme: programme))).first
    }

    /// One line per notification, every field, then the days the check-in rests.
    private func describe(_ plan: NotificationPlan) -> [String] {
        plan.notifications.map { n in
            let weekday = n.weekday.map(String.init) ?? "-"
            let offset = n.dayOffset.map(String.init) ?? "-"
            return "\(n.slot.rawValue) | weekday \(weekday) | hour \(n.hour) | offset \(offset) | "
                + "target \(n.target.rawValue) | slug \(n.learnSlug ?? "-") | \(n.title) | \(n.body)"
        } + ["rest days \(plan.hydrationRestDays.sorted())"]
    }

    /// Thirty of the states `NotificationPlannerTests` plans from, by name.
    private func existingFixtures() -> [(name: String, snapshot: NotificationSnapshot)] {
        let allRead = library.map {
            LearnCandidate(slug: $0.slug, title: $0.title, readingTime: $0.readingTime, tags: $0.tags, read: true)
        }
        let withADrop = [
            LearnCandidate(slug: "ph-trend", title: "Reading your pH trend", readingTime: "4 min", tags: ["ph"], read: false),
            LearnCandidate(slug: "first-weeks", title: "Your first two weeks", readingTime: "2 min", tags: [], read: false, isNew: true),
        ]
        return [
            ("defaults", snapshot()),
            ("thin data, insights just sent",
             snapshot(daily: 3, weekDays: 2, daysSinceLastPh: 1, phCount: 1, daysSinceLastLog: 0, sent: [.insights: 2])),
            ("library all read", snapshot(learn: allRead)),
            ("a new article", snapshot(daysSinceLastPh: 2, phCount: 1, learn: withADrop)),
            ("everything due",
             snapshot(daily: 0, weekDays: 6, weekly: 2, daysSinceLastPh: 30, phCount: 6,
                      daysSinceLastLog: 5, topSymptom: ("Fatigue", 5))),
            ("everything due, window tomorrow",
             snapshot(daily: 0, weekDays: 6, weekly: 2, daysSinceLastPh: 30, phCount: 6,
                      daysSinceLastLog: 5, topSymptom: ("Fatigue", 5), fertileInDays: 1)),
            ("everything due, window today on the pH Monday",
             snapshot(daily: 0, weekDays: 6, weekly: 2, daysSinceLastPh: 30, phCount: 6,
                      daysSinceLastLog: 5, topSymptom: ("Fatigue", 5), fertileInDays: 0, todayWeekday: 1)),
            ("everything due, pH muted",
             snapshot(daily: 0, weekDays: 6, weekly: 2, daysSinceLastPh: 30, phCount: 6,
                      daysSinceLastLog: 5, topSymptom: ("Fatigue", 5), fertileInDays: 1, muted: [.ph])),
            ("everything due, everything muted",
             snapshot(daily: 0, weekDays: 6, weekly: 2, daysSinceLastPh: 30, phCount: 6,
                      daysSinceLastLog: 5, topSymptom: ("Fatigue", 5), fertileInDays: 1,
                      muted: Set(NotificationCategory.allCases))),
            ("pH due", snapshot(daysSinceLastPh: 30)),
            ("pH due, pH muted", snapshot(daysSinceLastPh: 30, muted: [.ph])),
            ("pH due, check-in muted", snapshot(daysSinceLastPh: 30, muted: [.checkIn])),
            ("pH eleven days ago", snapshot(daysSinceLastPh: 11, phCount: 6)),
            ("first pH reading", snapshot(daysSinceLastPh: nil, phCount: 0)),
            ("window in a week, on a Tuesday", snapshot(fertileInDays: 7, todayWeekday: 2)),
            ("window today, on a Tuesday", snapshot(fertileInDays: 0, todayWeekday: 2)),
            ("window in three days", snapshot(fertileInDays: 3, todayWeekday: 1)),
            ("window wraps the week", snapshot(fertileInDays: 2, todayWeekday: 7)),
            ("window today, cycle muted", snapshot(fertileInDays: 0, muted: [.cycle])),
            ("window today, told three days ago", snapshot(sent: [.fertile: 3], fertileInDays: 0)),
            ("broken streak", snapshot(daily: 0, best: 12)),
            ("two silent weeks", snapshot(daysSinceLastLog: 20)),
            ("two silent weeks, logging muted", snapshot(daysSinceLastLog: 20, muted: [.logging])),
            ("silent, already reached out", snapshot(daysSinceLastLog: 30, sent: [.track: 3])),
            ("nothing logged today", snapshot(daysSinceLastLog: 5, loggedToday: false)),
            ("logged, water short", snapshot(loggedToday: true, waterToday: 500)),
            ("day complete", snapshot(loggedToday: true, waterToday: 2400)),
            ("steady week", snapshot(weekDays: 5, daysSinceLastPh: 1, phCount: 0)),
            ("symptom pattern", snapshot(weekDays: 2, daysSinceLastPh: 1, phCount: 0, topSymptom: ("Cramps", 4))),
            ("fatigue points at an article",
             snapshot(daily: 5, daysSinceLastPh: 1, phCount: 9, topSymptom: ("Fatigue", 4))),
        ]
    }

    // MARK: - No programme: nothing moves

    /// The contract Android mirrors. Every field of every notification, and the days the check-in
    /// rests, against what the planner returned before it knew the programme existed.
    func testWithNoProgrammeEveryRecordedPlanIsUnchanged() {
        let fixtures = existingFixtures()
        XCTAssertEqual(Set(fixtures.map(\.name)).count, Self.recordedBeforeTheProgramme.count)

        for fixture in fixtures {
            XCTAssertNil(fixture.snapshot.programme)
            XCTAssertEqual(describe(plan(fixture.snapshot)), Self.recordedBeforeTheProgramme[fixture.name],
                           fixture.name)
        }
    }

    /// A programme with nothing to say is the same as no programme, in every one of those states.
    /// Each of these would speak if its one failing answer were a yes.
    func testAProgrammeWithNothingToSayLeavesEveryRecordedPlanUnchanged() {
        let silent: [(name: String, programme: ProgrammeReminderFacts)] = [
            ("no access", facts(access: false, testOpen: true, review: 2)),
            ("not started", facts(started: false, testOpen: true, review: 2)),
            ("before day 1", facts(day: 0, testOpen: true)),
            ("day 91", facts(day: 91, testOpen: true, review: 12)),
            ("every activity done", facts(activities: 4, done: 4)),
            ("nothing counted today", facts(activities: 0, done: 0)),
        ]

        for fixture in existingFixtures() {
            for quiet in silent {
                XCTAssertEqual(describe(plan(adding(quiet.programme, to: fixture.snapshot))),
                               Self.recordedBeforeTheProgramme[fixture.name],
                               "\(quiet.name), in: \(fixture.name)")
            }
        }
    }

    // MARK: - Access, started, day 1 to 90

    func testWithoutAccessNothingIsSaid() {
        XCTAssertNil(line(facts(access: false)))
        XCTAssertNil(line(facts(access: false, done: 2, testOpen: true, review: 2)))
    }

    /// Holding access starts nothing. Until she chooses day 1 there is no day to speak about.
    func testBeforeTheProgrammeStartsNothingIsSaid() {
        XCTAssertNil(line(facts(started: false)))
        XCTAssertNil(line(facts(started: false, done: 2, testOpen: true, review: 2)))
    }

    /// Day 90 is the last programme day. From day 91 the programme is complete and goes quiet,
    /// whatever else the snapshot claims.
    func testACompletedProgrammeSaysNothing() {
        XCTAssertNotNil(line(facts(day: 1)))
        XCTAssertNotNil(line(facts(day: 90)))

        for day in [91, 92, 120, 400] {
            XCTAssertNil(line(facts(day: day)), "day \(day)")
            XCTAssertNil(line(facts(day: day, done: 2, testOpen: true, review: 12)), "day \(day)")
        }
        XCTAssertNil(line(facts(day: 0)), "a day before the start is not a programme day")
    }

    // MARK: - Something still open

    /// A reminder for something she has finished is the one that teaches her to stop reading them.
    func testWhenEveryActivityIsDoneNothingIsSaid() {
        XCTAssertNil(line(facts(activities: 4, done: 4)))
        XCTAssertNil(line(facts(activities: 1, done: 1)))
        XCTAssertEqual(plan(snapshot(programme: facts(activities: 4, done: 4))), plan(snapshot()))
    }

    func testADayWithNothingCountedSaysNothing() {
        XCTAssertNil(line(facts(activities: 0, done: 0)))
    }

    /// The flag says a test is open and the counts say nothing is. Two answers that disagree are
    /// not a yes.
    func testAnOpenTestFlagCannotOutvoteADayThatIsDone() {
        XCTAssertNil(line(facts(activities: 4, done: 4, testOpen: true)))
    }

    // MARK: - The morning line

    func testOpenActivitiesGetTheMorningLineWithHerNumbers() {
        let nudge = line(facts(day: 18, activities: 4, done: 0))

        XCTAssertEqual(nudge?.slot, .programme)
        XCTAssertEqual(nudge?.title, "Your Programme")
        XCTAssertEqual(nudge?.body, "Day 18 of your Genesyx Programme. You have 4 Programme activities today.")
        XCTAssertEqual(nudge?.hour, NotificationPlanner.programmeHour)
        XCTAssertEqual(nudge?.dayOffset, 0, "it is about today, so it is pinned to today")
        XCTAssertEqual(nudge?.weekday, 1)
        XCTAssertEqual(nudge?.target, .home)
        XCTAssertNil(nudge?.learnSlug)
    }

    func testASingleActivityIsNotCalledActivities() {
        XCTAssertEqual(line(facts(day: 2, activities: 1, done: 0))?.body,
                       "Day 2 of your Genesyx Programme. You have 1 Programme activity today.")
    }

    // MARK: - The evening line

    /// Some done, some not: the line moves to the hour she chose and counts what she has done.
    func testPartialProgressGetsTheEveningLine() {
        let nudge = programmeLines(plan(snapshot(reminderHour: 20, programme: facts(activities: 5, done: 4)))).first

        XCTAssertEqual(nudge?.slot, .programme)
        XCTAssertEqual(nudge?.body, "You've completed 4 of today's 5 Programme activities.")
        XCTAssertEqual(nudge?.hour, 20, "the hour she chose for the evening check-in")
        XCTAssertEqual(nudge?.dayOffset, 0)
    }

    /// The evening line is for a day she has begun. A day nothing is done in gets the morning line.
    func testTheEveningLineNeedsSomethingDone() {
        XCTAssertFalse(line(facts(activities: 5, done: 0))!.body.contains("completed"))
        XCTAssertTrue(line(facts(activities: 5, done: 1))!.body.contains("completed"))
        XCTAssertNil(line(facts(activities: 5, done: 5)))
    }

    // MARK: - The testing line

    private let testingLine = "Today's Programme has an activity that is specific to today. Tap to see it."

    func testTheTestingLineIsOnlyForADayAnOvulationTestIsOpen() {
        XCTAssertNotEqual(line(facts(testOpen: false))?.body, testingLine)
        XCTAssertNotEqual(line(facts(done: 2, testOpen: false))?.body, testingLine)

        XCTAssertEqual(line(facts(testOpen: true))?.body, testingLine)
        XCTAssertEqual(line(facts(done: 2, testOpen: true))?.body, testingLine)
    }

    /// It takes the place of that day's line, at that line's hour. It is not a second message.
    func testTheTestingLineReplacesTheDaysLine() {
        let untouched = plan(snapshot(programme: facts(testOpen: true)))
        XCTAssertEqual(programmeLines(untouched).map(\.slot), [.programme])
        XCTAssertEqual(programmeLines(untouched).first?.hour, NotificationPlanner.programmeHour)

        let begun = plan(snapshot(programme: facts(done: 2, testOpen: true)))
        XCTAssertEqual(programmeLines(begun).map(\.slot), [.programme])
        XCTAssertEqual(programmeLines(begun).first?.hour, 19)
    }

    /// The testing line is timed by her cycle, so the Cycle switch silences it even though it is
    /// filed under the programme. She gets the day's ordinary line, which she would have had anyway.
    func testWithCycleNotesSwitchedOffTheTestingLineIsNotSent() {
        let untouched = plan(snapshot(muted: [.cycle], programme: facts(testOpen: true)))
        XCTAssertEqual(programmeLines(untouched).first?.body,
                       "Day 18 of your Genesyx Programme. You have 4 Programme activities today.")

        let begun = plan(snapshot(muted: [.cycle], programme: facts(done: 2, testOpen: true)))
        XCTAssertEqual(programmeLines(begun).first?.body,
                       "You've completed 2 of today's 4 Programme activities.")

        // The window opens today and she has switched its note off: nothing in the plan says so.
        let windowDay = plan(snapshot(fertileInDays: 0, todayWeekday: 2, muted: [.cycle],
                                      programme: facts(testOpen: true)))
        XCTAssertFalse(windowDay.notifications.contains { $0.body == testingLine })
        XCTAssertEqual(programmeLines(windowDay).count, 1)
    }

    /// A lock screen is read by whoever is holding the phone. No programme line names her cycle or
    /// a test, the testing line included: the same words the fertile nudge keeps off it.
    func testNoProgrammeLinePutsHerCycleOrTheNameOfATestOnALockScreen() {
        let copy = NotificationPlanner.programmeCopy()
        XCTAssertTrue(copy.contains(testingLine), "the testing line has to be among the lines read")

        for sentence in copy {
            let shown = sentence.lowercased()
            for word in ["fertile", "ovulation", "ovulating", "conceive", "conception", "sex", "cycle", "test"] {
                XCTAssertFalse(shown.contains(word), "'\(word)' should not reach a lock screen: \(sentence)")
            }
        }
    }

    // MARK: - The weekly review line

    /// Day 43 opens week 7, which is the day the week 6 review becomes ready.
    func testAReviewThatHasBecomeReadyIsAnnounced() {
        let nudge = line(facts(day: 43, review: 6))

        XCTAssertEqual(nudge?.slot, .programmeReview)
        XCTAssertEqual(nudge?.body, "Your Week 6 Programme Review is ready.")
        XCTAssertEqual(nudge?.hour, 19, "the hour she chose")
        XCTAssertEqual(nudge?.dayOffset, 0)
    }

    /// Once. Each pair is a programme day in week 7 and the days since the line fired on day 43.
    /// The memory counts calendar days, so day 44 is 1 and day 49 is 6. A count in whole 24 hours
    /// would be the same or one less, and the line is not repeated for that either.
    func testAReviewIsAnnouncedOnceAndNotRepeated() {
        for (day, since) in [(43, 0), (44, 0), (44, 1), (46, 2), (46, 3), (49, 5), (49, 6)] {
            let lines = programmeLines(plan(snapshot(sent: [.programmeReview: since],
                                                     programme: facts(day: day, review: 6))))
            XCTAssertFalse(lines.contains { $0.slot == .programmeReview },
                           "day \(day), \(since) days after it was sent")
        }
    }

    /// Having been told, she gets the day's own line back rather than silence. Day 44 is the day
    /// after the review was told. On the day itself she has been notified, and nothing follows it.
    func testOnceTheReviewIsToldTheDaysLineReturns() {
        let nudge = programmeLines(plan(snapshot(sent: [.programmeReview: 1],
                                                 programme: facts(day: 44, review: 6)))).first

        XCTAssertEqual(nudge?.slot, .programme)
        XCTAssertEqual(nudge?.body, "Day 44 of your Genesyx Programme. You have 4 Programme activities today.")
    }

    /// Last week's line must not hold this week's back. Day 50 is seven calendar days after a line
    /// on day 43; six is what a count in whole 24 hours would give that morning.
    func testNextWeeksReviewIsNotHeldBackByThisWeeks() {
        for since in [6, 7] {
            let nudge = programmeLines(plan(snapshot(sent: [.programmeReview: since],
                                                     programme: facts(day: 50, review: 7)))).first
            XCTAssertEqual(nudge?.body, "Your Week 7 Programme Review is ready.", "\(since) days on")
        }
    }

    /// The review is the weekly line, so on its day it is the programme's one line.
    func testTheReviewTakesTheDayFromTheDaysLine() {
        let lines = programmeLines(plan(snapshot(programme: facts(day: 43, done: 2, testOpen: true, review: 6))))

        XCTAssertEqual(lines.map(\.slot), [.programmeReview])
    }

    /// Only a week that has ended has a review. Day 43 is in week 7.
    func testAReviewOfAWeekStillRunningIsNotAnnounced() {
        XCTAssertEqual(line(facts(day: 43, review: 7))?.slot, .programme)
        XCTAssertEqual(line(facts(day: 43, review: 9))?.slot, .programme)
        XCTAssertEqual(line(facts(day: 43, review: 0))?.slot, .programme, "and there is no week 0")
    }

    /// The week is passed in beside the day, and the two can disagree. A week that says the review
    /// is ready while the day says its week is still running is not a yes, however long ago a
    /// review line was last sent. Day 18 is in week 3, and day 10 in week 2. Nor is the other way
    /// round: day 43 opens week 7, and a week passed as 6 says week 6 is still running.
    func testAWeekThatDisagreesWithTheDayAnnouncesNoReview() {
        for (day, week, review) in [(18, 13, 12), (10, 5, 3), (43, 6, 6)] {
            let disagreeing = ProgrammeReminderFacts(hasAccess: true, started: true, day: day, week: week,
                                                    activitiesToday: 4, activitiesDone: 4,
                                                    reviewReadyWeek: review, hourNow: 7)
            let memories: [[NotificationSlot: Int]] = [[:], [.programmeReview: 0], [.programmeReview: 1],
                                                       [.programmeReview: 3], [.programmeReview: 60]]
            for sent in memories {
                XCTAssertTrue(programmeLines(plan(snapshot(sent: sent, programme: disagreeing))).isEmpty,
                              "day \(day), week \(week), review \(review), sent \(sent)")
            }
        }
    }

    /// The sent memory for the review counts calendar days. Week 6's line reached her late, on the
    /// last evening of week 7. The next day opens week 8 and week 7's review is ready: a line sent
    /// one calendar day ago was sent before this review existed, so this one is still to be told.
    /// A line sent today is this one.
    func testAReviewToldTheEveningBeforeDoesNotHoldBackTheNext() {
        let nextMorning = programmeLines(plan(snapshot(sent: [.programmeReview: 1],
                                                       programme: facts(day: 50, review: 7)))).first
        XCTAssertEqual(nextMorning?.body, "Your Week 7 Programme Review is ready.")

        let toldToday = programmeLines(plan(snapshot(sent: [.programmeReview: 0],
                                                     programme: facts(day: 50, review: 7))))
        XCTAssertFalse(toldToday.contains { $0.slot == .programmeReview })
    }

    // MARK: - Something that cannot be

    /// The engine cannot produce these, and the planner does not print them if something else does.
    func testCountsThatCannotBeAreNotSpoken() {
        for (activities, done) in [(0, -1), (4, -1), (-2, -3), (4, 5), (0, 0)] {
            XCTAssertNil(line(facts(activities: activities, done: done)), "\(done) of \(activities)")
            XCTAssertNil(line(facts(activities: activities, done: done, testOpen: true)), "\(done) of \(activities)")
        }
    }

    // MARK: - Told already today

    /// The morning line fired at nine and she has since done one of four, or the review reached her
    /// at eight and the day's line would be due at nine. Whatever it was, she has had today's one
    /// message, and the programme adds no second.
    func testOnceSheHasBeenNotifiedTodayTheProgrammeSaysNothingMore() {
        for programme in [facts(notifiedToday: true), facts(done: 1, notifiedToday: true),
                          facts(testOpen: true, notifiedToday: true),
                          facts(day: 43, review: 6, notifiedToday: true)] {
            XCTAssertTrue(programmeLines(plan(snapshot(programme: programme))).isEmpty)
        }

        // The reminder hour is eight: the review line fired then, and nine has not come yet.
        let afterTheReview = plan(snapshot(sent: [.programmeReview: 0], reminderHour: 8,
                                           programme: facts(day: 43, review: 6, hour: 8, notifiedToday: true)))
        XCTAssertTrue(programmeLines(afterTheReview).isEmpty)
    }

    /// It need not have been a programme line. The fertile nudge fired at eight on the morning the
    /// window opened, or the insights nudge on its Wednesday; each has left the plan, so nothing in
    /// the plan holds the day any more, and it is still taken.
    func testANudgeThatHasAlreadyFiredTodayStillTakesTheDayFromTheProgramme() {
        let afterFertile = plan(snapshot(sent: [.fertile: 0], fertileInDays: 0, todayWeekday: 2,
                                         programme: facts(hour: 8, notifiedToday: true)))
        XCTAssertNil(afterFertile.weekly.first { $0.slot == .fertile }, "told, so it is not planned again")
        XCTAssertTrue(programmeLines(afterFertile).isEmpty)
        XCTAssertEqual(afterFertile.hydration?.dayOffset, 1)

        let afterInsights = plan(snapshot(sent: [.insights: 0], todayWeekday: NotificationPlanner.insightsWeekday,
                                          programme: facts(hour: 8, notifiedToday: true)))
        XCTAssertNil(afterInsights.weekly.first { $0.slot == .insights })
        XCTAssertTrue(programmeLines(afterInsights).isEmpty)
        XCTAssertEqual(afterInsights.hydration?.dayOffset, 1)
    }

    /// "Today" is the calendar's, and the sent memory cannot say it: a line that fired yesterday
    /// evening is under 24 hours old this morning. It does not cost her today's line.
    func testALineFromYesterdayEveningDoesNotCostTodays() {
        for slot in [NotificationSlot.programme, .hydration, .insights] {
            XCTAssertNotNil(programmeLines(plan(snapshot(sent: [slot: 0], todayWeekday: 2, programme: facts()))).first,
                            "\(slot) fired within 24 hours, on another day")
        }
    }

    /// The other half of one a day. Tuesday, reminder at eight in the evening: the morning line
    /// fired at nine, she tapped it, and the app planned again. The line has left the plan and
    /// with it the day's rest, so without this the check-in would follow the same evening.
    func testAfterSheHasBeenNotifiedTodayTheCheckInIsTomorrows() {
        let atSeven = plan(snapshot(reminderHour: 20, todayWeekday: 2, programme: facts()))
        XCTAssertEqual(programmeLines(atSeven).first?.hour, NotificationPlanner.programmeHour)
        XCTAssertTrue(atSeven.hydrationRestDays.contains(2))

        let afterNine = plan(snapshot(sent: [.programme: 0], reminderHour: 20, todayWeekday: 2,
                                      programme: facts(hour: 9, notifiedToday: true)))
        XCTAssertTrue(programmeLines(afterNine).isEmpty)
        XCTAssertFalse(afterNine.hydrationRestDays.contains(2), "nothing in the plan holds today")
        XCTAssertEqual(afterNine.hydration?.dayOffset, 1, "and tonight is still quiet")
        XCTAssertEqual(afterNine.hydration?.title, "A quick log tonight?")

        // She has logged and is short of water: tonight's glass of water would be a second message
        // too, and tomorrow she has logged nothing yet, so tomorrow's is the invitation.
        let waterShort = plan(snapshot(loggedToday: true, waterToday: 500,
                                       programme: facts(done: 4, notifiedToday: true)))
        XCTAssertEqual(waterShort.hydration?.dayOffset, 1)
        XCTAssertEqual(waterShort.hydration?.title, "A quick log tonight?")
    }

    /// Only someone the programme may speak to is treated this way. No access, not started, past
    /// day 90 or the category switched off: the plan is the one from before the programme, in every
    /// recorded state, whatever has fired today.
    func testWithoutAProgrammeThatMaySpeakHavingBeenNotifiedTodayMovesNothing() {
        let quiet: [(name: String, programme: ProgrammeReminderFacts, muting: Set<NotificationCategory>)] = [
            ("no access", facts(access: false, notifiedToday: true), []),
            ("not started", facts(started: false, notifiedToday: true), []),
            ("day 91", facts(day: 91, notifiedToday: true), []),
            ("switched off", facts(notifiedToday: true), [.programme]),
            ("switched off, hour gone", facts(done: 2, review: 2, hour: 23, notifiedToday: true), [.programme]),
        ]

        for fixture in existingFixtures() {
            for silent in quiet {
                XCTAssertEqual(describe(plan(adding(silent.programme, to: fixture.snapshot, muting: silent.muting))),
                               Self.recordedBeforeTheProgramme[fixture.name],
                               "\(silent.name), in: \(fixture.name)")
            }
        }
    }

    // MARK: - An hour that has gone

    /// She first opens the app at ten with nothing done. Nine o'clock has gone, and a line that
    /// cannot be delivered is not planned: it would hold today against the check-in and deliver
    /// nothing, and the woman with everything still to do would hear nothing at all. The plan is
    /// the one she would have had without the programme, check-in tonight included.
    func testALineWhoseHourHasGoneIsNotPlannedAndDoesNotRestTheCheckIn() {
        XCTAssertEqual(programmeLines(plan(snapshot(todayWeekday: 2, programme: facts(hour: 8)))).first?.hour, 9)

        for hour in [9, 10, 18, 23] {
            let late = plan(snapshot(todayWeekday: 2, programme: facts(hour: hour)))

            XCTAssertTrue(programmeLines(late).isEmpty, "at \(hour)")
            XCTAssertFalse(late.hydrationRestDays.contains(2), "at \(hour)")
            XCTAssertNil(late.hydration?.dayOffset, "at \(hour): the check-in is still tonight's")
            XCTAssertEqual(late, plan(snapshot(todayWeekday: 2)), "at \(hour)")
        }
    }

    /// The evening line and the review are due at the hour she chose, and go the same way once it
    /// has gone.
    func testTheEveningLineAndTheReviewAreNotPlannedAfterHerHour() {
        XCTAssertEqual(line(facts(done: 2, hour: 18))?.hour, 19)
        XCTAssertNil(line(facts(done: 2, hour: 19)))
        XCTAssertNil(line(facts(done: 2, hour: 22)))

        XCTAssertEqual(line(facts(day: 43, review: 6, hour: 18))?.slot, .programmeReview)
        XCTAssertNil(line(facts(day: 43, review: 6, hour: 19)))

        // Between nine and her hour the morning line has gone and the review has not.
        XCTAssertEqual(line(facts(day: 43, review: 6, hour: 12))?.slot, .programmeReview)
    }

    // MARK: - Category

    func testSwitchingTheProgrammeCategoryOffSilencesEveryProgrammeLine() {
        for programme in [facts(), facts(done: 2), facts(testOpen: true), facts(day: 43, review: 6)] {
            XCTAssertEqual(programmeLines(plan(snapshot(programme: programme))).count, 1)

            let muted = plan(snapshot(muted: [.programme], programme: programme))
            XCTAssertTrue(programmeLines(muted).isEmpty)
            XCTAssertEqual(muted, plan(snapshot()), "silenced means absent: no day claimed, no slot used")
        }
    }

    /// The other switches are not the programme's. Muting the check-in leaves the programme line.
    func testAnotherCategorySwitchedOffDoesNotSilenceTheProgramme() {
        let p = plan(snapshot(muted: [.checkIn, .insights], programme: facts()))

        XCTAssertNil(p.hydration)
        XCTAssertEqual(programmeLines(p).count, 1)
    }

    func testTheProgrammeCategoryHasANameAndBothSlotsBelongToIt() {
        XCTAssertEqual(NotificationCategory.programme.rawValue, "programme")
        XCTAssertEqual(NotificationCategory.programme.title, "Programme reminders")
        XCTAssertEqual(NotificationSlot.programme.category, .programme)
        XCTAssertEqual(NotificationSlot.programmeReview.category, .programme)
    }

    // MARK: - One a day

    /// The fertile nudge goes first, as it always has. On the morning it lands, the day is taken and
    /// the programme says nothing: the plan is the one she would have had without a programme.
    func testOnADayTheFertileNudgeLandsTheProgrammeSaysNothing() {
        for programme in [facts(), facts(done: 2), facts(testOpen: true), facts(day: 43, review: 6)] {
            let p = plan(snapshot(fertileInDays: 0, todayWeekday: 2, programme: programme))

            XCTAssertNotNil(p.weekly.first { $0.slot == .fertile })
            XCTAssertTrue(programmeLines(p).isEmpty)
            XCTAssertEqual(p, plan(snapshot(fertileInDays: 0, todayWeekday: 2)))
        }
    }

    /// Seven days from today is today's weekday and a different date. A window that far out has
    /// not taken today.
    func testAWindowAWeekOutDoesNotCostTodaysProgrammeLine() {
        let p = plan(snapshot(fertileInDays: 7, todayWeekday: 2, programme: facts()))

        XCTAssertEqual(p.weekly.first { $0.slot == .fertile }?.dayOffset, 7)
        XCTAssertEqual(programmeLines(p).first?.dayOffset, 0)
    }

    /// The documented priority among the weekly nudges: fertile, then the programme's review, then
    /// the evergreen four. A pH reading is due, today is the pH nudge's Monday and a review has
    /// become ready, so the two want the same day. The review is the programme's place in the
    /// week, and the pH nudge gives the day up as it would to the fertile nudge.
    func testAnEvergreenNudgeOnTheSameDayGivesWayToTheReview() {
        let monday = NotificationPlanner.phWeekday
        let without = plan(snapshot(daysSinceLastPh: 30, todayWeekday: monday))
        XCTAssertNotNil(without.weekly.first { $0.slot == .ph })

        let with = plan(snapshot(daysSinceLastPh: 30, todayWeekday: monday, programme: facts(day: 43, review: 6)))
        let weekdays = with.weekly.compactMap(\.weekday)

        XCTAssertEqual(programmeLines(with).map(\.slot), [.programmeReview])
        XCTAssertEqual(programmeLines(with).first?.weekday, monday)
        XCTAssertNil(with.weekly.first { $0.slot == .ph }, "the pH nudge gives the day up")
        XCTAssertNotNil(with.weekly.first { $0.slot == .insights }, "the others keep their own days")
        XCTAssertNotNil(with.weekly.first { $0.slot == .learn })
        XCTAssertEqual(Set(weekdays).count, weekdays.count, "two nudges on one morning is two too many")
    }

    /// The line about today is not a weekly nudge and takes no morning from one. On the pH nudge's
    /// Monday the pH nudge keeps its day and the programme says nothing, exactly as the evening
    /// check-in rests that day: the plan is the one she would have had without the programme.
    func testTheDaysLineGivesWayOnADayAWeeklyNudgeOwns() {
        let monday = NotificationPlanner.phWeekday
        let without = plan(snapshot(daysSinceLastPh: 30, todayWeekday: monday))

        for programme in [facts(), facts(done: 2), facts(testOpen: true)] {
            let with = plan(snapshot(daysSinceLastPh: 30, todayWeekday: monday, programme: programme))

            XCTAssertNotNil(with.weekly.first { $0.slot == .ph })
            XCTAssertTrue(programmeLines(with).isEmpty)
            XCTAssertEqual(with, without)
        }

        // The day after, no weekly nudge owns the day and the line is planned.
        XCTAssertEqual(programmeLines(plan(snapshot(daysSinceLastPh: 30, todayWeekday: monday + 1,
                                                    programme: facts()))).map(\.slot), [.programme])
    }

    /// The evening check-in stands down on the programme's day exactly as it does for every other
    /// nudge. Tuesday is chosen because no evergreen nudge owns it.
    func testTheEveningCheckInRestsOnTheDayAProgrammeLineLands() {
        XCTAssertFalse(plan(snapshot(todayWeekday: 2)).hydrationRestDays.contains(2))

        for programme in [facts(), facts(done: 2), facts(day: 43, review: 6)] {
            XCTAssertTrue(plan(snapshot(todayWeekday: 2, programme: programme)).hydrationRestDays.contains(2))
        }
    }

    /// Whatever is true at once, the programme adds one line at most, and no day carries two.
    func testNeverTwoProgrammeLinesAndNeverTwoNudgesOnOneDay() {
        let speaking = [facts(), facts(done: 2), facts(testOpen: true), facts(done: 3, testOpen: true),
                        facts(day: 43, review: 6), facts(day: 43, done: 2, testOpen: true, review: 6)]

        for fixture in existingFixtures() {
            for programme in speaking {
                let p = plan(adding(programme, to: fixture.snapshot))
                // A nudge a week out shares a weekday with today and nothing else.
                let days = p.weekly.filter { $0.dayOffset != 7 }.compactMap(\.weekday)

                XCTAssertLessThanOrEqual(programmeLines(p).count, 1, fixture.name)
                XCTAssertEqual(Set(days).count, days.count, fixture.name)
                XCTAssertLessThanOrEqual(budgeted(p).count, NotificationPlanner.weeklyBudget, fixture.name)
            }
        }
    }

    // MARK: - Four a week

    /// The budget is not raised. Tuesday, the window opening on Thursday, all four evergreen nudges
    /// due and a review ready: six things for four places. The review takes a place inside the
    /// four, behind the fertile nudge and ahead of the evergreen ones, so it is the last of those
    /// that gives way. Only the fertile nudge is ever ahead of it, which is why the budget cannot
    /// run out before its turn.
    func testTheReviewIsInsideTheWeeklyBudgetNotOnTopOfIt() {
        let everythingDue = snapshot(daily: 0, weekDays: 6, weekly: 2, daysSinceLastPh: 30, phCount: 6,
                                     daysSinceLastLog: 5, topSymptom: ("Fatigue", 5),
                                     fertileInDays: 2, todayWeekday: 2)

        let without = plan(everythingDue)
        XCTAssertEqual(without.weekly.map(\.slot), [.fertile, .ph, .insights, .track])

        let with = plan(adding(facts(day: 43, review: 6), to: everythingDue))
        XCTAssertEqual(with.weekly.map(\.slot), [.fertile, .programmeReview, .ph, .insights])
        XCTAssertEqual(with.weekly.count, NotificationPlanner.weeklyBudget)
        XCTAssertEqual(NotificationPlanner.weeklyBudget, 4)
    }

    /// The line about today is outside the four because it is not one of them: it is today's daily
    /// message, in the check-in's place. In the same crowded week it costs no weekly nudge its
    /// place, and the check-in rests today for it.
    func testTheDaysLineTakesNoPlaceInTheWeeklyBudget() {
        let everythingDue = snapshot(daily: 0, weekDays: 6, weekly: 2, daysSinceLastPh: 30, phCount: 6,
                                     daysSinceLastLog: 5, topSymptom: ("Fatigue", 5),
                                     fertileInDays: 2, todayWeekday: 2)
        let without = plan(everythingDue)
        let with = plan(adding(facts(), to: everythingDue))

        XCTAssertEqual(budgeted(with), without.weekly, "the week's four are the four she had")
        XCTAssertEqual(programmeLines(with).map(\.slot), [.programme])
        XCTAssertEqual(with.hydration, without.hydration)
        XCTAssertEqual(with.hydrationRestDays, without.hydrationRestDays.union([2]))
    }

    // MARK: - A fortnight of plans

    /// What reaches her when the plans of fourteen days follow one another, as "Mon 20 slot".
    ///
    /// A port of what `NotificationService.replan` does with a plan. Every request is one-shot. A
    /// replan cancels the lot and queues the new plan: a date-pinned nudge whose hour has gone is
    /// dropped, a weekday nudge waits for that weekday, and the check-in takes the first evening
    /// that is not a rest day. She opens the app at `opening` each day, and again whenever
    /// something is delivered because she taps it, and every opening replans. The sent memory is
    /// whole 24 hours, and whole calendar days for the review.
    ///
    /// The fortnight starts on a Monday that is programme day 43, so a review becomes ready on
    /// each Monday. Her window opens on the first Wednesday, everything evergreen is due, her
    /// reminder is at eight in the evening, and she has four programme activities a day and does
    /// none of them: the most the planner can ever have to say.
    private func fortnight(opening: Int, programme hasProgramme: Bool) -> [String] {
        var pending: [NotificationSlot: Int] = [:]   // the hour each fires, counted from the first midnight
        var sent: [NotificationSlot: Int] = [:]
        var heard: [(day: Int, hour: Int, slot: NotificationSlot)] = []
        func weekday(_ day: Int) -> Int { day % 7 + 1 }

        for now in 0..<(14 * 24) {
            let day = now / 24, hour = now % 24
            let fired = pending.filter { $0.value == now }.keys.sorted { $0.rawValue < $1.rawValue }
            for slot in fired {
                heard.append((day, hour, slot))
                sent[slot] = now
                pending[slot] = nil
            }
            guard hour == opening || !fired.isEmpty else { continue }

            // She is in the app, a moment after the hour.
            let since = Dictionary(uniqueKeysWithValues: sent.map { slot, at in
                (slot, slot == .programmeReview ? day - at / 24 : (now - at) / 24)
            })
            let week = ProgrammeCalendar.week(forDay: 43 + day)
            let programme = ProgrammeReminderFacts(
                hasAccess: true, started: true, day: 43 + day, week: week,
                activitiesToday: 4, activitiesDone: 0, reviewReadyWeek: week - 1,
                hourNow: hour, notifiedToday: heard.contains { $0.day == day })
            let plan = NotificationPlanner.plan(snapshot(
                daily: 0, weekDays: 6, weekly: 2, daysSinceLastPh: 30, phCount: 6, daysSinceLastLog: 5,
                topSymptom: ("Fatigue", 5), sent: since, reminderHour: 20,
                fertileInDays: day <= 2 ? 2 - day : nil, todayWeekday: weekday(day),
                programme: hasProgramme ? programme : nil))

            pending = [:]
            for nudge in plan.weekly {
                var at = (day + (nudge.dayOffset ?? 0)) * 24 + nudge.hour
                if nudge.dayOffset == nil {
                    while weekday(at / 24) != nudge.weekday || at <= now { at += 24 }
                }
                if at > now { pending[nudge.slot] = at }
            }
            if let checkIn = plan.hydration {
                var at = day * 24 + checkIn.hour
                if (checkIn.dayOffset ?? 0) > 0 || at <= now { at += 24 }
                while plan.hydrationRestDays.contains(weekday(at / 24)) { at += 24 }
                pending[.hydration] = at
            }
        }

        let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return heard.map { "\($0.day / 7 + 1): \(names[$0.day % 7]) \($0.hour) \($0.slot.rawValue)" }
    }

    /// One plan cannot break the budget or the cap: the rules above hold inside it. A week is made
    /// of many plans, each made after the last one's nudges have fired and left it, so the week is
    /// what has to be counted. She opens the app at seven and taps everything.
    func testOverAFortnightOfReplansAWeekHoldsFourAndADayHoldsOne() {
        let heard = fortnight(opening: 7, programme: true)

        XCTAssertEqual(heard, [
            "1: Mon 20 programmeReview", "1: Tue 9 programme", "1: Wed 8 fertile", "1: Thu 9 programme",
            "1: Fri 12 track", "1: Sat 9 programme", "1: Sun 9 learn",
            "2: Mon 20 programmeReview", "2: Tue 9 programme", "2: Wed 8 insights", "2: Thu 9 programme",
            "2: Fri 9 programme", "2: Sat 9 programme", "2: Sun 9 learn",
        ])

        assertAWeekHoldsFourAndADayHoldsOne(heard)
        for week in ["1:", "2:"] {
            XCTAssertEqual(heard.filter { $0.hasPrefix(week) && $0.hasSuffix(" programmeReview") }.count, 1,
                           "week \(week)")
        }

        // And it is no more than she heard before the programme, when the same fortnight held a
        // check-in on each free evening.
        XCTAssertLessThanOrEqual(heard.count, fortnight(opening: 7, programme: false).count)
    }

    /// No day carries two messages, and no week more than four of the budgeted kind (everything
    /// but the check-in and the line said in its place) or more than one review.
    private func assertAWeekHoldsFourAndADayHoldsOne(_ heard: [String], _ when: String = "",
                                                     file: StaticString = #filePath, line: UInt = #line) {
        let days = heard.map { $0.split(separator: " ").prefix(2).joined(separator: " ") }
        XCTAssertEqual(Set(days).count, days.count, "two messages on one day \(when)", file: file, line: line)

        for week in ["1:", "2:"] {
            let inWeek = heard.filter { $0.hasPrefix(week) }
            let budgeted = inWeek.filter { !$0.hasSuffix(" hydration") && !$0.hasSuffix(" programme") }
            XCTAssertLessThanOrEqual(budgeted.count, NotificationPlanner.weeklyBudget, "week \(week) \(when)",
                                     file: file, line: line)
            XCTAssertLessThanOrEqual(inWeek.filter { $0.hasSuffix(" programmeReview") }.count, 1,
                                     "week \(week) \(when)", file: file, line: line)
        }
    }

    /// She opens the app at ten, after the morning line's hour, and does nothing. Each day's line
    /// is gone before it can be planned, so the day stays free and the evening check-in still
    /// reaches her on it. The woman with everything still to do is not the one who hears nothing.
    ///
    /// The second Monday differs from the first. Sunday's plan could not know of a review that was
    /// not ready yet, so it queued the pH nudge for Monday at nine, and that has fired before she
    /// opens the app. She has had Monday's one message, so the review is told on Tuesday evening
    /// in the check-in's place: a day late, and still once.
    func testSomeoneWhoOpensTheAppAfterNineStillHearsTheCheckIn() {
        let heard = fortnight(opening: 10, programme: true)

        XCTAssertEqual(heard, [
            "1: Mon 20 programmeReview", "1: Tue 20 hydration", "1: Wed 8 fertile", "1: Thu 20 hydration",
            "1: Fri 12 track", "1: Sat 20 hydration", "1: Sun 9 learn",
            "2: Mon 9 ph", "2: Tue 20 programmeReview", "2: Wed 8 insights", "2: Thu 20 hydration",
            "2: Fri 20 hydration", "2: Sat 20 hydration", "2: Sun 9 learn",
        ])
        assertAWeekHoldsFourAndADayHoldsOne(heard)
        XCTAssertFalse(heard.contains { $0.hasSuffix(" programme") }, "nine has gone each time she opens")
        XCTAssertEqual(heard.filter { $0.hasSuffix(" hydration") }.count, 6)
    }

    /// Whenever in the day she opens the app, the week and the day hold, and she hears no more
    /// than she did before the programme.
    func testWhateverHourSheOpensTheAppAWeekHoldsFourAndADayHoldsOne() {
        for opening in 0..<24 {
            let heard = fortnight(opening: opening, programme: true)

            assertAWeekHoldsFourAndADayHoldsOne(heard, "opening at \(opening)")
            XCTAssertLessThanOrEqual(heard.count, fortnight(opening: opening, programme: false).count,
                                     "opening at \(opening)")
        }
    }

    // MARK: - She goes quiet, we go quiet

    /// Two silent weeks end the programme's reminders with all the others.
    func testAfterTwoSilentWeeksTheProgrammeSaysNothingEither() {
        let handBack = plan(snapshot(daysSinceLastLog: 20, programme: facts(done: 2, review: 2)))
        XCTAssertEqual(handBack.notifications.map(\.slot), [.track])

        let afterIt = plan(snapshot(daysSinceLastLog: 30, sent: [.track: 3], programme: facts()))
        XCTAssertTrue(afterIt.notifications.isEmpty)
    }

    // MARK: - The numbers are hers

    /// Every number in a line is one from the snapshot, in the order the sentence gives them, and
    /// there is no other number in it.
    func testTheNumbersInEveryLineAreTheOnesInTheSnapshot() {
        func numbers(_ text: String) -> [Int] {
            text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        }

        for day in [1, 18, 90] {
            for total in [1, 2, 6] {
                let morning = line(facts(day: day, activities: total, done: 0))
                XCTAssertEqual(numbers(morning!.body), [day, total])
                XCTAssertEqual(numbers(morning!.title), [])

                for done in 1..<max(total, 1) {
                    let evening = line(facts(day: day, activities: total, done: done))
                    XCTAssertEqual(numbers(evening!.body), [done, total])
                }
            }
        }
        for week in 1...12 {
            let review = line(facts(day: week * 7 + 1, review: week))
            XCTAssertEqual(numbers(review!.body), [week])
        }
        XCTAssertEqual(numbers(testingLine), [], "the testing line carries no number at all")
    }

    // MARK: - Content safety

    /// The programme lines are part of the surface the existing scans walk, and are held to a
    /// longer list of their own: nothing about access being opened up, nothing about a result or an
    /// outcome, nothing that looks back at what she did not do, no promise about conceiving, no
    /// medical conclusion, no health term, and none of the words the programme's own screens ban.
    func testNoProgrammeLineCarriesABannedWordGuiltOrAnEmDash() {
        let copy = NotificationPlanner.programmeCopy()
        let everything = NotificationPlanner.allPossibleCopy()

        // Registered: the scans in `NotificationPlannerTests` and in the app read these too.
        for sentence in copy {
            XCTAssertTrue(everything.contains(sentence), "not in allPossibleCopy: \(sentence)")
        }
        // And the scan is only worth something if every kind of line is in it.
        for kind in ["Programme activity today", "Programme activities today", "You've completed",
                     "an activity that is specific to today", "Programme Review is ready"] {
            XCTAssertTrue(copy.contains { $0.contains(kind) }, "no '\(kind)' line in the scanned copy")
        }

        let banned = ["alkaline diet", "balance your ph", "boy or girl", "sex selection", "gender sway",
                      "sway the sex", "choose the sex", "detox", "flush toxins"]
        let guilt = ["you broke", "you failed", "you missed", "don't lose", "streak is over",
                     "don't forget", "streak"]
        let programme = ["unlock", "pregnan", "positive", "negative", "failed", "missed", "behind",
                         "guarantee", "result", "symptom",
                         "empower", "conceiv", "conception", "baby", "boost", "diagnos", "cure", "treat",
                         "infertil", "confirmed", "ovulating", "ovulated", "fertil", "hormone",
                         "congratulat", "should have", "your journey", "take control of", "optimis"]
        // Short enough to sit inside ordinary words, so these are matched as whole words.
        let abbreviations = ["lh", "hcg"]

        for sentence in copy {
            let lowered = sentence.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
            for phrase in banned + guilt + programme {
                XCTAssertFalse(lowered.contains(phrase), "'\(phrase)' in: \(sentence)")
            }
            let words = lowered.split(whereSeparator: { !$0.isLetter }).map(String.init)
            for abbreviation in abbreviations {
                XCTAssertFalse(words.contains(abbreviation), "'\(abbreviation)' in: \(sentence)")
            }
            XCTAssertFalse(sentence.contains("\u{2014}"), "em dash in: \(sentence)")
            XCTAssertFalse(sentence.contains("\u{2013}"), "en dash in: \(sentence)")
        }
    }

    /// The scan above reads fixed examples. This reads what the planner writes for a spread of
    /// real states, so a branch the examples miss cannot carry a sentence the scan never saw.
    func testEveryLineThePlannerWritesIsOneTheScanHasRead() {
        func shape(_ text: String) -> String {
            text.replacingOccurrences(of: "[0-9]+", with: "#", options: .regularExpression)
        }
        let scanned = Set(NotificationPlanner.programmeCopy().map(shape))

        for day in [1, 18, 43, 90] {
            for (total, done) in [(1, 0), (4, 0), (5, 1), (5, 4), (12, 11)] {
                for testOpen in [false, true] {
                    let reviews: [Int?] = [nil, ProgrammeCalendar.week(forDay: day) - 1]
                    for review in reviews {
                        guard let nudge = line(facts(day: day, activities: total, done: done,
                                                     testOpen: testOpen, review: review)) else { continue }
                        XCTAssertTrue(scanned.contains(shape(nudge.title)), nudge.title)
                        XCTAssertTrue(scanned.contains(shape(nudge.body)), nudge.body)
                    }
                }
            }
        }
    }
}

// MARK: - What the planner returned before the programme

private extension NotificationPlannerProgrammeTests {

    /// Recorded from the planner as it stood before it had a programme field, by running
    /// `describe` over `existingFixtures()`. Nothing here is to be edited to make a test pass:
    /// a difference is a change to the rules Android mirrors.
    static let recordedBeforeTheProgramme: [String: [String]] = [
        "defaults": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | Your pH trend has a shape | 6 readings this month is enough to see a line. Take a look.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug hydration | A read for your week | 'Hydration and your cycle' \u{2014} a 3 min read.",
            "rest days [3, 7]",
        ],
        "thin data, insights just sent": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug ph-trend | A read for your week | 'Reading your pH trend' \u{2014} a 4 min read.",
            "rest days [7]",
        ],
        "library all read": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | Your pH trend has a shape | 6 readings this month is enough to see a line. Take a look.",
            "rest days [3]",
        ],
        "a new article": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug first-weeks | New this week | 'Your first two weeks' \u{2014} a 2 min.",
            "rest days [7]",
        ],
        "everything due": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "ph | weekday 1 | hour 9 | offset - | target 2 | slug - | Keep the trend honest | Your last reading was 30 days ago. You've got 6 this month \u{2014} one more keeps the line true.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | A steady week | You've logged 6 of 7 days. That's what consistency looks like \u{2014} see what it's showing.",
            "track | weekday 5 | hour 12 | offset - | target 1 | slug - | Still here | Thirty seconds is all a log takes. Pick it up whenever you're ready.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug fatigue | A read for your week | 'When energy dips' \u{2014} a 5 min read.",
            "rest days [1, 3, 5, 7]",
        ],
        "everything due, window tomorrow": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "fertile | weekday 2 | hour 8 | offset 1 | target 1 | slug - | A note about your cycle | Your predicted window opens today. Tap to see where you are.",
            "ph | weekday 1 | hour 9 | offset - | target 2 | slug - | Keep the trend honest | Your last reading was 30 days ago. You've got 6 this month \u{2014} one more keeps the line true.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | A steady week | You've logged 6 of 7 days. That's what consistency looks like \u{2014} see what it's showing.",
            "track | weekday 5 | hour 12 | offset - | target 1 | slug - | Still here | Thirty seconds is all a log takes. Pick it up whenever you're ready.",
            "rest days [1, 2, 3, 5]",
        ],
        "everything due, window today on the pH Monday": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "fertile | weekday 1 | hour 8 | offset 0 | target 1 | slug - | A note about your cycle | Your predicted window opens today. Tap to see where you are.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | A steady week | You've logged 6 of 7 days. That's what consistency looks like \u{2014} see what it's showing.",
            "track | weekday 5 | hour 12 | offset - | target 1 | slug - | Still here | Thirty seconds is all a log takes. Pick it up whenever you're ready.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug fatigue | A read for your week | 'When energy dips' \u{2014} a 5 min read.",
            "rest days [1, 3, 5, 7]",
        ],
        "everything due, pH muted": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "fertile | weekday 2 | hour 8 | offset 1 | target 1 | slug - | A note about your cycle | Your predicted window opens today. Tap to see where you are.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | A steady week | You've logged 6 of 7 days. That's what consistency looks like \u{2014} see what it's showing.",
            "track | weekday 5 | hour 12 | offset - | target 1 | slug - | Still here | Thirty seconds is all a log takes. Pick it up whenever you're ready.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug fatigue | A read for your week | 'When energy dips' \u{2014} a 5 min read.",
            "rest days [2, 3, 5, 7]",
        ],
        "everything due, everything muted": [
            "rest days []",
        ],
        "pH due": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "ph | weekday 1 | hour 9 | offset - | target 2 | slug - | Keep the trend honest | Your last reading was 30 days ago. You've got 6 this month \u{2014} one more keeps the line true.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | Your pH trend has a shape | 6 readings this month is enough to see a line. Take a look.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug hydration | A read for your week | 'Hydration and your cycle' \u{2014} a 3 min read.",
            "rest days [1, 3, 7]",
        ],
        "pH due, pH muted": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | Your pH trend has a shape | 6 readings this month is enough to see a line. Take a look.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug hydration | A read for your week | 'Hydration and your cycle' \u{2014} a 3 min read.",
            "rest days [3, 7]",
        ],
        "pH due, check-in muted": [
            "ph | weekday 1 | hour 9 | offset - | target 2 | slug - | Keep the trend honest | Your last reading was 30 days ago. You've got 6 this month \u{2014} one more keeps the line true.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | Your pH trend has a shape | 6 readings this month is enough to see a line. Take a look.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug hydration | A read for your week | 'Hydration and your cycle' \u{2014} a 3 min read.",
            "rest days [1, 3, 7]",
        ],
        "pH eleven days ago": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "ph | weekday 1 | hour 9 | offset - | target 2 | slug - | Keep the trend honest | Your last reading was 11 days ago. You've got 6 this month \u{2014} one more keeps the line true.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | Your pH trend has a shape | 6 readings this month is enough to see a line. Take a look.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug hydration | A read for your week | 'Hydration and your cycle' \u{2014} a 3 min read.",
            "rest days [1, 3, 7]",
        ],
        "first pH reading": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "ph | weekday 1 | hour 9 | offset - | target 2 | slug - | Your first pH reading | One reading is where the trend starts. It takes a minute.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug ph-trend | A read for your week | 'Reading your pH trend' \u{2014} a 4 min read.",
            "rest days [1, 7]",
        ],
        "window in a week, on a Tuesday": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "fertile | weekday 2 | hour 8 | offset 7 | target 1 | slug - | A note about your cycle | Your predicted window opens today. Tap to see where you are.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | Your pH trend has a shape | 6 readings this month is enough to see a line. Take a look.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug hydration | A read for your week | 'Hydration and your cycle' \u{2014} a 3 min read.",
            "rest days [3, 7]",
        ],
        "window today, on a Tuesday": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "fertile | weekday 2 | hour 8 | offset 0 | target 1 | slug - | A note about your cycle | Your predicted window opens today. Tap to see where you are.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | Your pH trend has a shape | 6 readings this month is enough to see a line. Take a look.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug hydration | A read for your week | 'Hydration and your cycle' \u{2014} a 3 min read.",
            "rest days [2, 3, 7]",
        ],
        "window in three days": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "fertile | weekday 4 | hour 8 | offset 3 | target 1 | slug - | A note about your cycle | Your predicted window opens today. Tap to see where you are.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | Your pH trend has a shape | 6 readings this month is enough to see a line. Take a look.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug hydration | A read for your week | 'Hydration and your cycle' \u{2014} a 3 min read.",
            "rest days [3, 4, 7]",
        ],
        "window wraps the week": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "fertile | weekday 2 | hour 8 | offset 2 | target 1 | slug - | A note about your cycle | Your predicted window opens today. Tap to see where you are.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | Your pH trend has a shape | 6 readings this month is enough to see a line. Take a look.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug hydration | A read for your week | 'Hydration and your cycle' \u{2014} a 3 min read.",
            "rest days [2, 3, 7]",
        ],
        "window today, cycle muted": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | Your pH trend has a shape | 6 readings this month is enough to see a line. Take a look.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug hydration | A read for your week | 'Hydration and your cycle' \u{2014} a 3 min read.",
            "rest days [3, 7]",
        ],
        "window today, told three days ago": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | Your pH trend has a shape | 6 readings this month is enough to see a line. Take a look.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug hydration | A read for your week | 'Hydration and your cycle' \u{2014} a 3 min read.",
            "rest days [3, 7]",
        ],
        "broken streak": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | Your pH trend has a shape | 6 readings this month is enough to see a line. Take a look.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug hydration | A read for your week | 'Hydration and your cycle' \u{2014} a 3 min read.",
            "rest days [3, 7]",
        ],
        "two silent weeks": [
            "track | weekday 5 | hour 12 | offset - | target 0 | slug - | Whenever you're ready | Your data is where you left it. Pick up any time \u{2014} a single log is enough to start again.",
            "rest days [5]",
        ],
        "two silent weeks, logging muted": [
            "rest days []",
        ],
        "silent, already reached out": [
            "rest days []",
        ],
        "nothing logged today": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | Your pH trend has a shape | 6 readings this month is enough to see a line. Take a look.",
            "track | weekday 5 | hour 12 | offset - | target 1 | slug - | Still here | Thirty seconds is all a log takes. Pick it up whenever you're ready.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug hydration | A read for your week | 'Hydration and your cycle' \u{2014} a 3 min read.",
            "rest days [3, 5, 7]",
        ],
        "logged, water short": [
            "hydration | weekday - | hour 19 | offset - | target 3 | slug - | One more glass? | A little water before the day winds down.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | Your pH trend has a shape | 6 readings this month is enough to see a line. Take a look.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug hydration | A read for your week | 'Hydration and your cycle' \u{2014} a 3 min read.",
            "rest days [3, 7]",
        ],
        "day complete": [
            "hydration | weekday - | hour 19 | offset 1 | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | Your pH trend has a shape | 6 readings this month is enough to see a line. Take a look.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug hydration | A read for your week | 'Hydration and your cycle' \u{2014} a 3 min read.",
            "rest days [3, 7]",
        ],
        "steady week": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | A steady week | You've logged 5 of 7 days. That's what consistency looks like \u{2014} see what it's showing.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug ph-trend | A read for your week | 'Reading your pH trend' \u{2014} a 4 min read.",
            "rest days [3, 7]",
        ],
        "symptom pattern": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | A pattern worth seeing | Cramps has come up 4 times this month. Your heatmap shows when.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug ph-trend | A read for your week | 'Reading your pH trend' \u{2014} a 4 min read.",
            "rest days [3, 7]",
        ],
        "fatigue points at an article": [
            "hydration | weekday - | hour 19 | offset - | target 0 | slug - | A quick log tonight? | A moment to note how today went \u{2014} it's how the picture builds.",
            "insights | weekday 3 | hour 8 | offset - | target 4 | slug - | Your pH trend has a shape | 9 readings this month is enough to see a line. Take a look.",
            "learn | weekday 7 | hour 9 | offset - | target 5 | slug fatigue | A read for your week | 'When energy dips' \u{2014} a 5 min read.",
            "rest days [3, 7]",
        ],
    ]
}
