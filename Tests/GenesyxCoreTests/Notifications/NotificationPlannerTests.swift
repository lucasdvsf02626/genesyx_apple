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
                          reminderHour: Int = 19) -> NotificationSnapshot {
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
            reminderHour: reminderHour)
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
}
