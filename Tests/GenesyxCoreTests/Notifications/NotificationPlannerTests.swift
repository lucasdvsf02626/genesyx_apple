import XCTest
@testable import GenesyxCore

final class NotificationPlannerTests: XCTestCase {

    private let library = [
        LearnCandidate(slug: "ph-trend", title: "Reading your pH trend", readingTime: "4 min read", tags: ["ph"], read: false),
        LearnCandidate(slug: "hydration", title: "Hydration and your cycle", readingTime: "3 min read", tags: ["hydration"], read: false),
        LearnCandidate(slug: "fatigue", title: "When energy dips", readingTime: "5 min read", tags: ["fatigue"], read: false),
    ]

    private func snapshot(daily: Int = 0, best: Int = 0, weekDays: Int = 0, weekly: Int = 0,
                          daysSinceLastPh: Int? = 1, phCount: Int = 6,
                          daysSinceLastLog: Int? = 0,
                          topSymptom: (String, Int)? = nil,
                          learn: [LearnCandidate]? = nil,
                          sent: [NotificationSlot: Int] = [:],
                          loggedToday: Bool = false, waterToday: Int = 0,
                          reminderHour: Int = 19,
                          fertileInDays: Int? = nil, todayWeekday: Int = 1,
                          muted: Set<NotificationCategory> = []) -> NotificationSnapshot {
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
            mutedCategories: muted)
    }

    private func plan(_ s: NotificationSnapshot) -> NotificationPlan { NotificationPlanner.plan(s) }

    // MARK: - Invariant 1: no filler

    func testASlotWithNothingTrueToSaySendsNothing() {
        // Logged pH yesterday, logged today, thin data, insights sent two days ago.
        let p = plan(snapshot(daily: 3, weekDays: 2, daysSinceLastPh: 1, phCount: 1,
                              daysSinceLastLog: 0, sent: [.insights: 2]))

        XCTAssertNil(p.weekly.first { $0.slot == .ph }, "she logged pH yesterday")
        XCTAssertNil(p.weekly.first { $0.slot == .insights }, "thin data, and just nudged")
        XCTAssertNil(p.weekly.first { $0.slot == .track }, "she logged today")
    }

    func testLearnSaysNothingOnceSheHasReadEverything() {
        let allRead = library.map {
            LearnCandidate(slug: $0.slug, title: $0.title, readingTime: $0.readingTime, tags: $0.tags, read: true)
        }
        XCTAssertNil(plan(snapshot(learn: allRead)).weekly.first { $0.slot == .learn })
    }

    // MARK: - Invariant 2: one a day, four a week

    func testNeverMoreThanFourWeeklyNudges() {
        // Everything is due at once.
        let p = plan(snapshot(daily: 0, weekDays: 6, weekly: 2, daysSinceLastPh: 30, phCount: 6,
                              daysSinceLastLog: 5, topSymptom: ("Fatigue", 5)))

        XCTAssertLessThanOrEqual(p.weekly.count, NotificationPlanner.weeklyBudget)
    }

    func testEveryWeeklyNudgeLandsOnItsOwnDay() {
        let p = plan(snapshot(daily: 0, weekDays: 6, weekly: 2, daysSinceLastPh: 30, phCount: 6,
                              daysSinceLastLog: 5, topSymptom: ("Fatigue", 5)))
        let weekdays = p.weekly.compactMap(\.weekday)

        XCTAssertEqual(Set(weekdays).count, weekdays.count, "two nudges on one morning is two too many")
    }

    /// Hydration is daily, but it stands down on any morning a weekly nudge already lands.
    func testHydrationRestsOnDaysAWeeklyNudgeLands() {
        let p = plan(snapshot(daysSinceLastPh: 30))

        XCTAssertNotNil(p.hydration)
        XCTAssertEqual(p.hydrationRestDays, Set(p.weekly.compactMap(\.weekday)))
    }

    // MARK: - Invariant 3: never guilt

    /// The whole point. A broken streak is never named — she's offered today, not shown the loss.
    func testABrokenStreakIsNeverNamed() {
        let body = plan(snapshot(daily: 0, best: 12)).hydration!.body + plan(snapshot(daily: 0, best: 12)).hydration!.title

        for word in ["broke", "broken", "lost", "missed", "failed", "streak"] {
            XCTAssertFalse(body.lowercased().contains(word), "'\(word)' names what she lost: \(body)")
        }
    }

    func testNoBannedOrGuiltPhraseInAnyReachableSentence() {
        let banned = ["alkaline diet", "balance your ph", "boy or girl", "sex selection", "gender sway",
                      "sway the sex", "choose the sex", "detox", "flush toxins"]
        let guilt = ["you broke", "you failed", "you missed", "don't lose", "streak is over"]

        for sentence in NotificationPlanner.allPossibleCopy() {
            let lowered = sentence.lowercased()
            for phrase in banned + guilt {
                XCTAssertFalse(lowered.contains(phrase), "'\(phrase)' in: \(sentence)")
            }
        }
    }

    // MARK: - Invariant 4: she goes quiet, we go quiet

    func testTwoSilentWeeksEarnsOneHandBack() {
        let p = plan(snapshot(daysSinceLastLog: 20))

        XCTAssertEqual(p.notifications.count, 1)
        XCTAssertEqual(p.notifications.first?.slot, .track)
        XCTAssertNil(p.hydration, "no daily nudging someone who has gone")
    }

    func testAfterThatHandBackWeStopEntirely() {
        let p = plan(snapshot(daysSinceLastLog: 30, sent: [.track: 3]))

        XCTAssertTrue(p.notifications.isEmpty, "she was already reached out to — now leave her alone")
    }

    // MARK: - Switching a category off

    /// Everything due at once, with the window opening on a Tuesday so it collides with nothing.
    private var everythingDue: NotificationSnapshot {
        snapshot(daily: 0, weekDays: 6, weekly: 2, daysSinceLastPh: 30, phCount: 6,
                 daysSinceLastLog: 5, topSymptom: ("Fatigue", 5), fertileInDays: 1)
    }

    func testAMutedCategoryIsNotPlannedAtAll() {
        let p = plan(snapshot(daysSinceLastPh: 30, muted: [.ph]))

        XCTAssertNil(p.weekly.first { $0.slot == .ph }, "a reading is due, but she asked us not to")
    }

    /// The reason muting happens at plan time. A nudge removed afterwards would still have claimed
    /// its morning, and hydration would have stood down for a message she never receives.
    func testMutingGivesTheMorningBackToHydration() {
        let heard = plan(snapshot(daysSinceLastPh: 30))
        XCTAssertTrue(heard.hydrationRestDays.contains(NotificationPlanner.phWeekday))

        let muted = plan(snapshot(daysSinceLastPh: 30, muted: [.ph]))
        XCTAssertFalse(muted.hydrationRestDays.contains(NotificationPlanner.phWeekday))
        XCTAssertNotNil(muted.hydration, "and the daily nudge is still on")
    }

    /// Same reason, for the weekly budget: five things are due and only four fit, so silencing one
    /// should let the one that missed out through rather than leave the week a nudge short.
    func testMutingOneCategoryLetsAnotherUseTheBudget() {
        let heard = plan(everythingDue)
        XCTAssertEqual(heard.weekly.count, NotificationPlanner.weeklyBudget)
        XCTAssertNil(heard.weekly.first { $0.slot == .learn }, "crowded out by the other four")

        let muted = plan(snapshot(daily: 0, weekDays: 6, weekly: 2, daysSinceLastPh: 30, phCount: 6,
                                  daysSinceLastLog: 5, topSymptom: ("Fatigue", 5),
                                  fertileInDays: 1, muted: [.ph]))

        XCTAssertNil(muted.weekly.first { $0.slot == .ph })
        XCTAssertNotNil(muted.weekly.first { $0.slot == .learn }, "the Sunday read takes the free slot")
        XCTAssertEqual(muted.weekly.count, NotificationPlanner.weeklyBudget)
    }

    func testMutingTheCycleCategorySilencesTheFertileNudge() {
        XCTAssertNotNil(plan(snapshot(fertileInDays: 0)).weekly.first { $0.slot == .fertile })
        XCTAssertNil(plan(snapshot(fertileInDays: 0, muted: [.cycle])).weekly.first { $0.slot == .fertile })
    }

    func testMutingTheEveningCheckInLeavesTheWeeklyNudgesAlone() {
        let p = plan(snapshot(daysSinceLastPh: 30, muted: [.checkIn]))

        XCTAssertNil(p.hydration)
        XCTAssertNotNil(p.weekly.first { $0.slot == .ph })
    }

    /// The dormant hand-back is a logging nudge too. Someone who switched those off after two silent
    /// weeks has been about as clear as it is possible to be.
    func testMutingLoggingAlsoSilencesTheHandBackAfterALongGap() {
        XCTAssertEqual(plan(snapshot(daysSinceLastLog: 20)).notifications.count, 1)
        XCTAssertTrue(plan(snapshot(daysSinceLastLog: 20, muted: [.logging])).notifications.isEmpty)
    }

    func testMutingEverythingSendsNothing() {
        let p = plan(snapshot(daily: 0, weekDays: 6, weekly: 2, daysSinceLastPh: 30, phCount: 6,
                              daysSinceLastLog: 5, topSymptom: ("Fatigue", 5), fertileInDays: 1,
                              muted: Set(NotificationCategory.allCases)))

        XCTAssertTrue(p.notifications.isEmpty)
    }

    // MARK: - The evening check-in: two branches, both guilt-free

    /// Nothing logged today → a warm invitation to log, landing on Home.
    func testEveningCheckInInvitesALogWhenNothingIsLogged() {
        let h = plan(snapshot(daysSinceLastLog: 5, loggedToday: false)).hydration
        XCTAssertEqual(h?.title, "A quick log tonight?")
        XCTAssertEqual(h?.target, .home)
        XCTAssertEqual(h?.hour, 19, "it fires at the hour she chose")
    }

    /// Logged today, but water short of goal → a gentle glass-of-water nudge, landing on Nutrition.
    func testEveningCheckInNudgesWaterWhenLoggedButShortOfGoal() {
        let h = plan(snapshot(loggedToday: true, waterToday: 500)).hydration
        XCTAssertEqual(h?.title, "One more glass?")
        XCTAssertEqual(h?.target, .nutrition)
    }

    /// Logged and hydrated → nothing at all (invariant 1: no filler).
    func testEveningCheckInSaysNothingWhenTheDayIsComplete() {
        XCTAssertNil(plan(snapshot(loggedToday: true, waterToday: 2400)).hydration)
    }

    func testPhCopyNamesHowLongItHasActuallyBeen() {
        let ph = plan(snapshot(daysSinceLastPh: 11, phCount: 6)).weekly.first { $0.slot == .ph }

        XCTAssertTrue(ph!.body.contains("11 days ago"))
        XCTAssertTrue(ph!.body.contains("6"), "and how solid the trend already is")
    }

    func testFirstEverPhReadingGetsItsOwnWords() {
        let ph = plan(snapshot(daysSinceLastPh: nil, phCount: 0)).weekly.first { $0.slot == .ph }

        XCTAssertEqual(ph?.title, "Your first pH reading")
    }

    func testInsightsFiresOnlyWhenTheDataSaysSomethingNew() {
        let steady = plan(snapshot(weekDays: 5, daysSinceLastPh: 1, phCount: 0)).weekly.first { $0.slot == .insights }
        XCTAssertTrue(steady!.body.contains("5 of 7 days"))

        let pattern = plan(snapshot(weekDays: 2, daysSinceLastPh: 1, phCount: 0, topSymptom: ("Cramps", 4)))
            .weekly.first { $0.slot == .insights }
        XCTAssertTrue(pattern!.body.contains("Cramps"))
        XCTAssertTrue(pattern!.body.contains("4 times"))
    }

    /// The article is chosen for what she's logging, not by the calendar.
    func testLearnPicksTheArticleHerDataPointsAt() {
        let fatigued = plan(snapshot(daily: 5, daysSinceLastPh: 1, phCount: 9, topSymptom: ("Fatigue", 4)))
        XCTAssertEqual(fatigued.weekly.first { $0.slot == .learn }?.learnSlug, "fatigue")

        let thinPh = plan(snapshot(daily: 5, daysSinceLastPh: 2, phCount: 1))
        XCTAssertEqual(thinPh.weekly.first { $0.slot == .learn }?.learnSlug, "ph-trend")
    }

    func testLearnNeverRepeatsAnArticleSheHasRead() {
        let readPh = [
            LearnCandidate(slug: "ph-trend", title: "Reading your pH trend", readingTime: "4 min", tags: ["ph"], read: true),
            LearnCandidate(slug: "hydration", title: "Hydration and your cycle", readingTime: "3 min", tags: ["hydration"], read: false),
        ]
        let p = plan(snapshot(daysSinceLastPh: 1, phCount: 0, learn: readPh))

        XCTAssertEqual(p.weekly.first { $0.slot == .learn }?.learnSlug, "hydration")
    }

    /// An article that arrived in the update she just installed beats one that has been sitting
    /// there — including one her own logging points at harder. The relevant old piece will still be
    /// unread next Sunday; the drop is only new once.
    func testANewArticleOutranksAMoreRelevantOldOne() {
        let withADrop = [
            LearnCandidate(slug: "ph-trend", title: "Reading your pH trend", readingTime: "4 min", tags: ["ph"], read: false),
            LearnCandidate(slug: "first-weeks", title: "Your first two weeks", readingTime: "2 min", tags: [], read: false, isNew: true),
        ]
        // Thin pH history — without the drop this would pick "ph-trend" (see the test above).
        let p = plan(snapshot(daysSinceLastPh: 2, phCount: 1, learn: withADrop))

        XCTAssertEqual(p.weekly.first { $0.slot == .learn }?.learnSlug, "first-weeks")
    }

    /// Within the new ones it is still her data that decides, not the order they were declared.
    func testAmongSeveralNewArticlesHerDataStillChooses() {
        let twoDrops = [
            LearnCandidate(slug: "hydration", title: "Hydration and your cycle", readingTime: "3 min", tags: ["hydration"], read: false, isNew: true),
            LearnCandidate(slug: "fatigue", title: "When energy dips", readingTime: "5 min", tags: ["fatigue"], read: false, isNew: true),
        ]
        let p = plan(snapshot(daily: 5, daysSinceLastPh: 1, phCount: 9, topSymptom: ("Fatigue", 4), learn: twoDrops))

        XCTAssertEqual(p.weekly.first { $0.slot == .learn }?.learnSlug, "fatigue")
    }

    /// The title tells her which it is. "New this week" on a library she's had for months is the
    /// kind of small lie that teaches her to stop reading the notifications.
    func testTheTitleSaysNewOnlyWhenSomethingActuallyArrived() {
        let drop = [LearnCandidate(slug: "first-weeks", title: "Your first two weeks", readingTime: "2 min", tags: [], read: false, isNew: true)]

        XCTAssertEqual(plan(snapshot(learn: drop)).weekly.first { $0.slot == .learn }?.title, "New this week")
        XCTAssertEqual(plan(snapshot()).weekly.first { $0.slot == .learn }?.title, "A read for your week")
    }

    /// A new article she has already opened is not news. Read wins over new.
    func testANewArticleSheHasAlreadyReadIsNotAnnounced() {
        let readDrop = [
            LearnCandidate(slug: "first-weeks", title: "Your first two weeks", readingTime: "2 min", tags: [], read: true, isNew: true),
            LearnCandidate(slug: "hydration", title: "Hydration and your cycle", readingTime: "3 min", tags: ["hydration"], read: false),
        ]
        let learn = plan(snapshot(learn: readDrop)).weekly.first { $0.slot == .learn }

        XCTAssertEqual(learn?.learnSlug, "hydration")
        XCTAssertEqual(learn?.title, "A read for your week")
    }

    // MARK: - Fertile window

    /// It is scheduled for the day the window opens, not the day the plan was made — so it carries
    /// the offset, and a weekday derived from it.
    func testFertileNudgeIsPinnedToTheMorningTheWindowOpens() {
        let thursday = plan(snapshot(fertileInDays: 3, todayWeekday: 1)).weekly.first { $0.slot == .fertile }

        XCTAssertEqual(thursday?.dayOffset, 3)
        XCTAssertEqual(thursday?.weekday, 4, "Monday + 3 is Thursday")
        XCTAssertEqual(thursday?.hour, NotificationPlanner.fertileHour)

        let wrapped = plan(snapshot(fertileInDays: 2, todayWeekday: 7)).weekly.first { $0.slot == .fertile }
        XCTAssertEqual(wrapped?.weekday, 2, "Sunday + 2 wraps to Tuesday")
    }

    /// Written in the present tense because it is read on the day it fires — a countdown planned
    /// today would arrive stale.
    func testFertileCopyIsPresentTenseWhicheverDayItIsPlanned() {
        let today = plan(snapshot(fertileInDays: 0)).weekly.first { $0.slot == .fertile }
        let inAWeek = plan(snapshot(fertileInDays: 7)).weekly.first { $0.slot == .fertile }

        XCTAssertEqual(today?.body, inAWeek?.body)
        XCTAssertTrue(today!.body.contains("today"))
    }

    /// A lock screen is read by whoever is holding the phone. The specifics stay inside the app.
    func testFertileNudgeKeepsTheSpecificsOffTheLockScreen() {
        let nudge = plan(snapshot(fertileInDays: 0)).weekly.first { $0.slot == .fertile }!
        let shown = (nudge.title + " " + nudge.body).lowercased()

        for word in ["fertile", "ovulation", "ovulating", "conceive", "conception", "sex"] {
            XCTAssertFalse(shown.contains(word), "'\(word)' should not reach a lock screen: \(shown)")
        }
    }

    func testNoFertileNudgeBeyondTheHorizonOrWithoutACycle() {
        XCTAssertNil(plan(snapshot(fertileInDays: 8)).weekly.first { $0.slot == .fertile })
        XCTAssertNil(plan(snapshot(fertileInDays: nil)).weekly.first { $0.slot == .fertile })
    }

    /// A window opens once a cycle. Re-planning must not mean re-telling her.
    func testFertileNudgeIsNotRepeatedWithinTheSameOpening() {
        XCTAssertNil(plan(snapshot(sent: [.fertile: 3], fertileInDays: 0)).weekly.first { $0.slot == .fertile })
        XCTAssertNotNil(plan(snapshot(sent: [.fertile: 20], fertileInDays: 0)).weekly.first { $0.slot == .fertile })
    }

    /// Invariant 2 still holds once a dynamic day joins the fixed ones: the evergreen nudge gives
    /// way, because "your window opens today" cannot be told on Tuesday instead.
    func testFertileNudgeTakesTheMorningFromAnEvergreenNudge() {
        // Everything due at once, with the window opening on the pH nudge's Monday.
        let p = plan(snapshot(daily: 0, weekDays: 6, weekly: 2, daysSinceLastPh: 30, phCount: 6,
                              daysSinceLastLog: 5, topSymptom: ("Fatigue", 5),
                              fertileInDays: 0, todayWeekday: NotificationPlanner.phWeekday))
        let weekdays = p.weekly.compactMap(\.weekday)

        XCTAssertNotNil(p.weekly.first { $0.slot == .fertile })
        XCTAssertNil(p.weekly.first { $0.slot == .ph }, "the pH nudge owned that morning and gives it up")
        XCTAssertEqual(Set(weekdays).count, weekdays.count, "two nudges on one morning is two too many")
        XCTAssertLessThanOrEqual(p.weekly.count, NotificationPlanner.weeklyBudget)
    }
}
