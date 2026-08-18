import XCTest
@testable import Genesyx
import GenesyxCore

/// The app-side half of the notification system: content safety across everything the planner can
/// reach, when the hydration nudge actually fires, and where a tap lands. The planner's own rules
/// are covered by `NotificationPlannerTests` in GenesyxCore.
final class NotificationTests: XCTestCase {

    // MARK: - Content safety

    /// Nothing we send may make a medical claim or imply the app influences an outcome.
    private static let bannedPhrases = [
        "alkaline diet", "balance your ph", "boy or girl", "sex selection", "gender sway",
        "sway the sex", "choose the sex", "detox", "flush toxins",
    ]

    /// Nor may it guilt her. A missed day costs almost nothing — that's the brand contract, and a
    /// "you broke your streak" push would be the fastest way to break it.
    private static let guiltPhrases = ["you broke", "you failed", "you missed", "don't lose", "streak is over"]

    func testNoBannedPhraseInAnySentenceTheAppCanSend() {
        for copy in NotificationContent.allCopyStrings {
            let lowered = copy.lowercased()
            for phrase in Self.bannedPhrases {
                XCTAssertFalse(lowered.contains(phrase), "Banned phrase '\(phrase)' in: \(copy)")
            }
        }
    }

    func testNoGuiltInAnySentenceTheAppCanSend() {
        for copy in NotificationContent.allCopyStrings {
            let lowered = copy.lowercased()
            for phrase in Self.guiltPhrases {
                XCTAssertFalse(lowered.contains(phrase), "Guilt phrase '\(phrase)' in: \(copy)")
            }
        }
    }

    func testEveryMilestoneHasCopyAndAnId() {
        for milestone in Milestone.allCases {
            XCTAssertFalse(NotificationContent.milestoneTitle(milestone).isEmpty)
            XCTAssertFalse(NotificationContent.milestoneBody(milestone).isEmpty)
            XCTAssertTrue(NotificationKind(milestone: milestone).rawValue.hasPrefix("genesyx.milestone."))
        }
    }

    /// Supplement reminders repeat, so their ids are the only way to ever stop them. Unlike every
    /// other notification here the id is built from data rather than an enum case, which is exactly
    /// why it is pinned by a test.
    func testASupplementReminderIdIsDerivedFromItsKey() {
        XCTAssertEqual(NotificationService.supplementRequestId("mag"), "genesyx.supplement.mag")
        XCTAssertEqual(NotificationService.supplementRequestId("essential.F"),
                       "genesyx.supplement.essential.F")
    }

    /// Every category she can mute needs a name she'd recognise on the Profile row.
    func testEveryMutableCategoryHasATitle() {
        for category in NotificationCategory.allCases {
            XCTAssertFalse(category.title.isEmpty, "\(category.rawValue) has no title")
        }
    }

    /// Build 9 scheduled a nutrition and a phase nudge. They're retired, but their IDs must survive
    /// so an upgrading app can still cancel what it already scheduled.
    func testRetiredIdsSurviveSoTheyCanBeCancelled() {
        let ids = NotificationKind.allCases.map(\.rawValue)
        XCTAssertTrue(ids.contains("genesyx.weekly.nutrition"))
        XCTAssertTrue(ids.contains("genesyx.weekly.phase"))
    }

    func testEverySlotHasItsOwnStableId() {
        let ids = NotificationSlot.allCases.map { NotificationKind(slot: $0).rawValue }
        XCTAssertEqual(Set(ids).count, NotificationSlot.allCases.count)
    }

    // MARK: - When the hydration nudge fires

    private func date(_ day: Int, _ hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026; components.month = 7; components.day = day
        components.hour = hour; components.minute = 0
        return Calendar.current.date(from: components)!
    }

    func testHydrationNudgeFiresTodayWhenNothingIsLoggedYet() {
        let fire = NotificationService.nextHydrationFire(now: date(13, 8), hour: 10, loggedToday: false)
        XCTAssertEqual(fire, date(13, 10))
    }

    /// The rule that matters: she logged water, so today's nudge is not sent at all.
    func testHydrationNudgeSkipsTodayOnceWaterIsLogged() {
        let fire = NotificationService.nextHydrationFire(now: date(13, 8), hour: 10, loggedToday: true)
        XCTAssertEqual(fire, date(14, 10), "she's already started — wait for tomorrow")
    }

    /// No evening chase: once 10:00 has passed unanswered, the next one is tomorrow morning.
    func testHydrationNudgeDoesNotChaseHerLaterTheSameDay() {
        let fire = NotificationService.nextHydrationFire(now: date(13, 18), hour: 10, loggedToday: false)
        XCTAssertEqual(fire, date(14, 10))
    }

    /// Invariant 2 — one a day. 2026-07-14 is a Tuesday (ISO 2); hydration steps over it.
    func testHydrationStandsDownOnADayAWeeklyNudgeOwns() {
        let fire = NotificationService.nextHydrationFire(
            now: date(13, 18), hour: 10, loggedToday: false, restDays: [2])

        XCTAssertEqual(fire, date(15, 10), "Tuesday belongs to a weekly nudge — take Wednesday")
    }

    func testIsoWeekdayMapsMondayToOne() {
        XCTAssertEqual(NotificationService.isoWeekday(of: date(13, 9)), 1)   // Mon 13 Jul 2026
        XCTAssertEqual(NotificationService.isoWeekday(of: date(19, 9)), 7)   // Sun 19 Jul 2026
    }

    func testNextOccurrenceFindsTheComingWeekday() {
        let next = NotificationService.nextOccurrence(isoWeekday: 3, hour: 8, now: date(13, 12))
        XCTAssertEqual(next, date(15, 8), "Wednesday 08:00")
    }

    // MARK: - Date-pinned nudges (the fertile window)

    /// The fertile nudge is pinned to a date, not a weekday: "your window opens today" has to land
    /// on that day, and `nextOccurrence` would push a same-day fire a full week out.
    func testFireDateLandsOnTheRequestedDay() {
        XCTAssertEqual(NotificationService.fireDate(daysFromNow: 3, hour: 8, now: date(13, 12)), date(16, 8))
        XCTAssertEqual(NotificationService.fireDate(daysFromNow: 0, hour: 20, now: date(13, 12)), date(13, 20),
                       "later the same day still counts")
    }

    /// Telling her the window opened this morning, this evening, is worth nothing — the app shows
    /// her where she is the moment she opens it.
    func testFireDateRefusesAMomentThatHasPassed() {
        XCTAssertNil(NotificationService.fireDate(daysFromNow: 0, hour: 8, now: date(13, 12)))
    }

    // MARK: - Tap routing

    func testLearnTapCarriesTheArticleSlug() {
        let payload = NotificationRouter.payload(tab: .learn, learnSlug: "first-week")
        XCTAssertEqual(NotificationRouter.destination(from: payload),
                       NotificationRouter.Destination(tab: .learn, learnSlug: "first-week"))
    }

    func testMilestoneTapLandsOnInsights() {
        let destination = NotificationRouter.destination(from: NotificationRouter.payload(tab: .insights))
        XCTAssertEqual(destination?.tab, .insights)
        XCTAssertNil(destination?.learnSlug)
    }

    func testAnUnknownPayloadRoutesNowhere() {
        XCTAssertNil(NotificationRouter.destination(from: ["something": "else"]))
    }

    /// The planner's target and the app's tab are two enums that must not drift apart.
    func testPlannerTargetsMapOntoRealTabs() {
        // Pairwise, not just "resolves to something": inserting a tab shifts every raw value above
        // it, and a bare `NotificationTab(rawValue:) != nil` still passes when a nudge starts
        // landing one tab off.
        let pairs: [(NotificationTarget, NotificationTab)] = [
            (.home, .home), (.track, .track), (.ph, .ph), (.nutrition, .nutrition),
            (.insights, .insights), (.learn, .learn), (.profile, .profile),
        ]
        for (target, tab) in pairs {
            XCTAssertEqual(target.rawValue, tab.rawValue, "\(target) and its tab drifted apart")
        }
    }

    // MARK: - Learn read log

    func testAnArticleSheHasOpenedIsNotOfferedAgain() {
        let slug = "test-\(UUID().uuidString)"
        XCTAssertFalse(LearnReadLog.readSlugs().contains(slug))

        LearnReadLog.markRead(slug)

        XCTAssertTrue(LearnReadLog.readSlugs().contains(slug))
    }

    // MARK: - Which articles are new

    private func isolatedDefaults() -> UserDefaults {
        let suite = "learn-library-\(UUID().uuidString)"
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        return UserDefaults(suiteName: suite)!
    }

    /// Nothing is new to someone who is only just starting. The whole library is recorded on first
    /// run, so she doesn't get sixteen consecutive "new this week" Sundays for articles that shipped
    /// together in the build she installed.
    func testOnFirstRunNothingIsNew() {
        let defaults = isolatedDefaults()

        XCTAssertTrue(LearnLibraryLog.newSlugs(in: ["a", "b", "c"], defaults: defaults).isEmpty)
        XCTAssertTrue(LearnLibraryLog.newSlugs(in: ["a", "b", "c"], defaults: defaults).isEmpty)
    }

    /// An article that shows up in a *later* build is the one worth announcing.
    func testAnArticleThatArrivesInALaterBuildIsNew() {
        let defaults = isolatedDefaults()
        _ = LearnLibraryLog.newSlugs(in: ["a", "b"], defaults: defaults)

        XCTAssertEqual(LearnLibraryLog.newSlugs(in: ["a", "b", "c"], defaults: defaults), ["c"])
    }

    /// It stays new until the nudge naming it has actually fired — a replan before Sunday must not
    /// quietly demote the drop to an ordinary weekly read.
    func testAnArticleStaysNewUntilItHasBeenAnnounced() {
        let defaults = isolatedDefaults()
        _ = LearnLibraryLog.newSlugs(in: ["a"], defaults: defaults)
        XCTAssertEqual(LearnLibraryLog.newSlugs(in: ["a", "b"], defaults: defaults), ["b"])

        LearnLibraryLog.markAnnounced("b", defaults: defaults)

        XCTAssertTrue(LearnLibraryLog.newSlugs(in: ["a", "b"], defaults: defaults).isEmpty)
    }

    // MARK: - The Learn tab badge

    /// Real articles rather than fixtures — the badge counts the shipped library, and a fixture
    /// would only prove the arithmetic.
    private var shipped: [LearnArticle] { LearnLibrary.articles }

    /// A first install badges nothing. Sixteen articles arrived together in the build she just
    /// downloaded; "16 new" is a chore list, not an invitation.
    @MainActor
    func testAFreshInstallBadgesNothing() {
        let progress = LearnProgress(articles: shipped, defaults: isolatedDefaults())

        XCTAssertEqual(progress.unreadNewCount, 0)
    }

    @MainActor
    func testAnArticleAddedInAnUpdateBadgesUntilSheReadsIt() {
        let defaults = isolatedDefaults()
        let added = shipped.last!
        _ = LearnProgress(articles: Array(shipped.dropLast()), defaults: defaults)   // the build before

        let progress = LearnProgress(articles: shipped, defaults: defaults)
        XCTAssertEqual(progress.unreadNewCount, 1)

        progress.markRead(added.slug)
        XCTAssertEqual(progress.unreadNewCount, 0)
    }

    // MARK: - The weekly drop, end to end

    /// One article a week, announced in-app, is three pieces meeting: the date gate makes it
    /// visible, `LearnLibraryLog` notices it is newly visible, and the Home card names it. None of
    /// the three knows about the other two — the gate was added long after the log — so this is the
    /// only place the chain is checked end to end. A break in it is silent precisely because every
    /// piece goes on working perfectly well by itself.
    @MainActor
    func testAWeeklyDropBadgesAndIsOfferedOnTheHomeCard() {
        guard let drop = LearnLibrary.allArticles.compactMap(\.publishedAt).min() else {
            return XCTFail("expected a dated article")
        }
        let defaults = isolatedDefaults()

        // Saturday: she opens the app and sees the library as it stands. Nothing is new.
        let saturday = LearnProgress(articles: LearnLibrary.published(asOf: drop.minusDays(1)),
                                     defaults: defaults)
        XCTAssertEqual(saturday.unreadNewCount, 0)

        // Sunday: the article reveals itself — no update, no network call.
        let sunday = LearnProgress(articles: LearnLibrary.published(asOf: drop), defaults: defaults)
        XCTAssertEqual(sunday.unreadNewCount, 1, "exactly the week's article should badge")
        XCTAssertEqual(sunday.nextRead?.article.slug, "fertile-window")
        XCTAssertEqual(sunday.nextRead?.headline, "New this week",
                       "the Home card must announce the drop as the week's, not as a stock read")

        sunday.markRead("fertile-window")
        XCTAssertEqual(sunday.unreadNewCount, 0, "reading it clears the badge")
    }

    /// The fourth piece of that chain, and the one the test above cannot see: what the Sunday nudge
    /// is allowed to *name*. Asserted against the service's own composition rather than a rebuilt
    /// one, because rebuilding it is exactly how this went unnoticed — `learnCandidates()` was the
    /// single caller passing the raw `learnArticles`, withheld articles and all.
    ///
    /// Two consequences, both silent. The "new" pool is exclusive, so the nudge picked *only* from
    /// unreleased pieces: a push headed "New this week" whose tap resolves through the published-only
    /// `articleBySlug` to nil and lands on "That article isn't available". And `markAnnounced` then
    /// spent that slug, so when the article genuinely revealed weeks later the badge stayed at zero.
    @MainActor
    func testTheSundayNudgeCanOnlyNameAnArticleTheAppCanOpen() {
        let withheld = Set(LearnLibrary.allArticles
            .filter { $0.publishedAt != nil }
            .map(\.slug))
            .subtracting(LearnLibrary.articles.map(\.slug))
        XCTAssertFalse(withheld.isEmpty, "this asserts nothing once every article has been released")

        let store = LocalStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let container = AppContainer(store: store, backend: nil, monitorNetwork: false)
        let candidates = service(for: container).learnCandidates()
        XCTAssertFalse(candidates.isEmpty)

        for candidate in candidates {
            XCTAssertNotNil(LearnLibrary.articleBySlug(candidate.slug),
                            "the nudge may name \(candidate.slug), which the app cannot open")
        }
        XCTAssertTrue(withheld.isDisjoint(with: candidates.map(\.slug)),
                      "a date-withheld article must not be offered before it lands")
    }

    /// The badge is the *persistent* half of the pair. If it tracked `markAnnounced` live it would
    /// vanish the instant the Sunday nudge delivered — she dismisses the banner and the article is
    /// gone from both surfaces at once, with nothing left pointing at it.
    @MainActor
    func testTheSundayNudgeFiringDoesNotTakeTheBadgeWithIt() {
        let defaults = isolatedDefaults()
        let added = shipped.last!
        _ = LearnProgress(articles: Array(shipped.dropLast()), defaults: defaults)
        let progress = LearnProgress(articles: shipped, defaults: defaults)

        LearnLibraryLog.markAnnounced(added.slug, defaults: defaults)

        XCTAssertEqual(progress.unreadNewCount, 1, "only reading it should clear the badge")
    }

    /// What she has read is as personal as what she has logged, and the badge must not greet the
    /// next account with the last one's leftovers.
    @MainActor
    func testSigningOutClearsTheBadgeAndTheReadHistory() {
        let defaults = isolatedDefaults()
        _ = LearnProgress(articles: Array(shipped.dropLast()), defaults: defaults)
        let progress = LearnProgress(articles: shipped, defaults: defaults)
        progress.markRead(shipped.first!.slug)

        progress.clear()

        XCTAssertTrue(progress.readSlugs.isEmpty)
        XCTAssertEqual(progress.unreadNewCount, 0)
    }

    // MARK: - The Home dashboard card

    @MainActor
    func testTheCardNamesAnArticleSheHasNotRead() {
        let progress = LearnProgress(articles: shipped, defaults: isolatedDefaults())

        let next = progress.nextRead
        XCTAssertNotNil(next)
        XCTAssertFalse(progress.readSlugs.contains(next!.article.slug))
    }

    /// It disappears rather than re-offering a library she has finished — the card is the one
    /// surface she cannot dismiss, so it has to know when to stop.
    @MainActor
    func testTheCardDisappearsOnceSheHasReadEverything() {
        let progress = LearnProgress(articles: shipped, defaults: isolatedDefaults())
        for article in shipped { progress.markRead(article.slug) }

        XCTAssertNil(progress.nextRead)
    }

    /// The card and the badge are two views of one fact, so a newly-arrived article must be what
    /// the card leads with — otherwise the badge says "1 new" and the card names something else.
    @MainActor
    func testTheCardLeadsWithTheNewArticleTheBadgeIsCounting() {
        let defaults = isolatedDefaults()
        let added = shipped.last!
        _ = LearnProgress(articles: Array(shipped.dropLast()), defaults: defaults)

        let progress = LearnProgress(articles: shipped, defaults: defaults)

        XCTAssertEqual(progress.nextRead?.article.slug, added.slug)
        XCTAssertEqual(progress.nextRead?.headline, "New this week")
    }

    // MARK: - Milestones without notification permission

    /// Seven consecutive days ending today, logged the way most people log: something real, no
    /// water, no pH.
    @MainActor
    private func containerWithAWeekOfLogging() -> AppContainer {
        let store = LocalStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let container = AppContainer(store: store, backend: nil, monitorNetwork: false)
        // She is a woman who has been using the app for a week, so she has agreed to it being
        // recorded. Without this the Article 9 gate refuses every seeded write and the week of
        // logging this helper is named for does not exist.
        container.consent.grant()
        let today = CalendarDate.today()
        for i in 0..<7 {
            container.dailyLog.upsert(DailyLog(mood: .good, foodGroups: ["vegetables"]),
                                      on: today.addingDays(-i))
        }
        return container
    }

    @MainActor
    private func service(for container: AppContainer) -> NotificationService {
        NotificationService(prefs: container.prefs, dailyLog: container.dailyLog,
                            ph: container.ph, cycle: container.cycle,
                            supplements: container.supplements, store: container.store,
                            session: container.session)
    }

    /// The whole point of the in-app celebration, asserted at the service rather than through the
    /// UI: push is off, so `isActive` is false and nothing will ever be scheduled — and she must
    /// still be congratulated. `GenesyxUITests` covers the other way in, a fresh install that has
    /// never been asked for permission at all.
    ///
    /// `pushEnabled` is the term used to shut the gate because it is the only one a test can
    /// control. The system's own authorization is host state: this suite was written expecting
    /// `notDetermined` and found `authorized`, so anything asserted on that term passes or fails
    /// according to which simulator it lands on.
    @MainActor
    func testAMilestoneIsCelebratedInAppEvenWithPushTurnedOff() async {
        let container = containerWithAWeekOfLogging()
        container.prefs.pushEnabled = false
        let service = service(for: container)

        await service.reconcile()

        XCTAssertFalse(service.isActive, "nothing can be scheduled")
        XCTAssertNotNil(service.celebration,
                        "and that must not cost her the in-app moment")
    }

    // MARK: - She said yes and iOS said no

    /// The path with the most ways to lie to her, and until now the one with no coverage: she asked
    /// for reminders and the system refused. Three separate claims have to stay false — the toggle
    /// reading on, the schedule believing it is live, and anything being sent — and one has to be
    /// true, which is the app admitting the refusal so Profile can offer the way into Settings.
    @MainActor
    func testASystemDenialIsNotAllowedToLookLikeReminders() async {
        let container = containerWithAWeekOfLogging()
        container.session.signIn(email: "maya@example.com", name: "Maya")
        container.prefs.pushEnabled = true
        let service = service(for: container)
        service.readAuthorizationStatus = { .denied }

        await service.reconcile()

        XCTAssertFalse(service.isOn, "the switch must not read on for reminders iOS will not deliver")
        XCTAssertFalse(service.isActive, "and nothing may be scheduled against a refused permission")
        XCTAssertTrue(service.isSystemDenied, "but the refusal has to be visible, or Profile cannot offer Settings")
    }

    /// Denial is a system answer, not a change of mind, so the switch she set stays set. Without
    /// this the app would quietly rewrite her preference on her behalf, and a woman who later
    /// allowed notifications in Settings would find reminders still off with nothing saying why.
    @MainActor
    func testADenialDoesNotRewriteWhatSheAskedFor() async {
        let container = containerWithAWeekOfLogging()
        container.prefs.pushEnabled = true
        let service = service(for: container)
        service.readAuthorizationStatus = { .denied }

        service.setEnabled(true)
        await service.reconcile()

        XCTAssertTrue(container.prefs.pushEnabled, "her request survives the system's refusal")
        XCTAssertFalse(service.isOn, "it just cannot be honoured yet")
    }

    /// Granting it in Settings later has to be enough — no reinstall, no toggling it off and on.
    /// `reconcile` runs on foreground, which is exactly the moment she comes back from Settings.
    @MainActor
    func testAllowingItInSettingsLaterTurnsRemindersOnWithoutHerAskingTwice() async {
        let container = containerWithAWeekOfLogging()
        container.session.signIn(email: "maya@example.com", name: "Maya")
        container.prefs.pushEnabled = true
        let service = service(for: container)
        service.readAuthorizationStatus = { .denied }
        await service.reconcile()
        XCTAssertFalse(service.isOn)

        service.readAuthorizationStatus = { .authorized }
        await service.reconcile()

        XCTAssertTrue(service.isOn, "coming back from Settings must be all it takes")
        XCTAssertFalse(service.isSystemDenied)
    }

    /// The celebration is in-app, so it belongs to her data and not to Apple's permission. A denial
    /// silences the banner; it must not silence the week she actually logged.
    @MainActor
    func testADenialStillLeavesHerTheInAppMilestone() async {
        let container = containerWithAWeekOfLogging()
        container.prefs.pushEnabled = true
        let service = service(for: container)
        service.readAuthorizationStatus = { .denied }

        await service.reconcile()

        XCTAssertNotNil(service.celebration,
                        "a refused permission must not cost her the moment she earned")
    }

    /// A signed-out session cannot keep a schedule, even if she left the toggle on.
    @MainActor
    func testSignOutMakesTheScheduleInactiveAndDropsAHeldDestination() {
        let container = containerWithAWeekOfLogging()
        container.session.signIn(email: "maya@example.com", name: "Maya")
        container.prefs.pushEnabled = true
        let service = service(for: container)
        service.pendingDestination = .init(tab: .home, learnSlug: nil)

        container.session.signOut()

        XCTAssertFalse(service.isActive)
        XCTAssertNil(service.pendingDestination, "logout must drop a held private destination")
    }

    /// Muting is defined here, because the definition is not obvious and both halves of it matter.
    ///
    /// Muted means *none* — someone who turned milestones off did not ask for a quieter
    /// celebration, so the modal goes too, not just the banner. And the flag is still spent, so
    /// switching them back on months later delivers the milestones she passed in silence as
    /// silence, not as a backlog of modals.
    @MainActor
    func testMutingMilestonesRemovesTheModalTooAndStillSpendsTheFlag() async {
        let container = containerWithAWeekOfLogging()
        container.prefs.pushEnabled = false
        container.prefs.mutedNotifications = [.milestones]
        let service = service(for: container)

        await service.reconcile()

        XCTAssertNil(service.celebration, "muted is none, not quieter")
        XCTAssertTrue(container.prefs.celebratedMilestones.contains(Milestone.day7.flagKey),
                      "unmuting must not deliver a backlog of everything she passed")
    }

    // MARK: - Cancelling has to forget, not just cancel

    /// Delivery can't be observed while the app is closed, so a scheduled fire time that has passed
    /// is counted as delivered. That inference is sound only if cancelling forgets the time too.
    ///
    /// It didn't. Switching reminders off, muting a category or revoking permission in Settings all
    /// cancel the pending request and used to leave the fire time remembered — so the next time she
    /// opened the app, a notification that never existed was banked as sent. The fertile, insights
    /// and track nudges each stand down for a fortnight after they last spoke, so each went quiet
    /// for one; and a Sunday Learn drop was marked announced, losing its "New this week" badge
    /// without her ever having been told.
    ///
    /// The key is spelled out rather than reached through the service because that is the thing
    /// being pinned: the record outlives the process, so the fault outlived it too.
    @MainActor
    func testCancellingForgetsTheFireTimesSoNothingCountsAsDelivered() {
        let container = containerWithAWeekOfLogging()
        let service = service(for: container)
        let key = "notification_scheduled_fire"
        let neverFired: [String: Date] = [
            NotificationKind.cycleFertile.rawValue: Date().addingTimeInterval(-3600)
        ]
        container.store.save(neverFired, forKey: key)

        service.cancelAll()

        let remembered = container.store.load([String: Date].self, forKey: key) ?? [:]
        XCTAssertTrue(remembered.isEmpty,
                      "a cancelled notification never fired, so it must not be remembered as sent")
    }
}
