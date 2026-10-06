import Foundation

// WS2b — the notification planner.
//
// Everything the app can ever say to her is decided here, from her own data, and nowhere else.
// Pure and synchronous: the service feeds it a snapshot and schedules whatever comes back, so
// every sentence she could ever receive is reachable from a unit test — including the
// content-safety scan.
//
// Four invariants, each one a test:
//   1. No filler      — a slot with nothing true to say sends nothing. Silence is a valid plan.
//   2. One a day      — the daily hydration nudge stands down on any day a weekly nudge lands.
//   3. Never guilt    — no notification names what she lost. Not a streak, not a missed day.
//   4. She goes quiet, we go quiet — after two silent weeks, one hand back, then nothing.

// MARK: - Inputs

/// A Learn article, reduced to what the planner needs to choose between them.
public struct LearnCandidate: Equatable, Sendable {
    public let slug: String
    public let title: String
    public let readingTime: String
    /// Lowercased topic tags, matched against what she's actually logging.
    public let tags: [String]
    public let read: Bool
    /// Arrived in an update she has just installed — this week's drop, rather than a corner of the
    /// library she has had all along.
    public let isNew: Bool

    public init(slug: String, title: String, readingTime: String, tags: [String], read: Bool,
                isNew: Bool = false) {
        self.slug = slug
        self.title = title
        self.readingTime = readingTime
        self.tags = tags
        self.read = read
        self.isNew = isNew
    }
}

/// The 90-Day Programme, reduced to what the planner needs to decide whether to speak about it.
///
/// Counts and flags only, filled by the app from today's programme plan, its clock and its record
/// of what has fired. Which activities they are, and anything she recorded in them, never reaches
/// the planner, so it cannot reach a lock screen either.
public struct ProgrammeReminderFacts: Equatable, Sendable {
    /// She holds Programme Access.
    public let hasAccess: Bool
    /// The programme is running: she chose a start date, it has arrived, and she has not left.
    /// Access alone starts nothing.
    public let started: Bool
    /// Today's programme day: 1 on the start date, above 90 once the programme is complete.
    public let day: Int
    /// Today's programme week, 1 to 13.
    public let week: Int
    /// Activities counted today, and how many of those are fully done.
    public let activitiesToday: Int
    public let activitiesDone: Int
    /// An ovulation test is one of today's counted activities and is still open. A yes or a no:
    /// no result exists at this point, and none is ever passed.
    public let ovulationTestOpen: Bool
    /// The programme week whose review has become ready and has not been opened. nil when none.
    public let reviewReadyWeek: Int?
    /// The hour it is now, 0 to 23. The planner has no clock of its own, and needs this to know
    /// that a line for an hour already gone can no longer be delivered today.
    public let hourNow: Int
    /// One of the planned notifications has already reached her today: today by the calendar, not
    /// within the last 24 hours. The sent memory counts whole days, so it cannot answer this.
    /// Supplement alarms and milestones are outside the plan and do not count.
    public let notifiedToday: Bool

    public init(hasAccess: Bool, started: Bool, day: Int, week: Int,
                activitiesToday: Int, activitiesDone: Int,
                ovulationTestOpen: Bool = false, reviewReadyWeek: Int? = nil,
                hourNow: Int = 0, notifiedToday: Bool = false) {
        self.hasAccess = hasAccess
        self.started = started
        self.day = day
        self.week = week
        self.activitiesToday = activitiesToday
        self.activitiesDone = activitiesDone
        self.ovulationTestOpen = ovulationTestOpen
        self.reviewReadyWeek = reviewReadyWeek
        self.hourNow = hourNow
        self.notifiedToday = notifiedToday
    }
}

/// Everything the planner knows about her. Assembled by the app from the repositories.
public struct NotificationSnapshot {
    public let streak: StreakState
    /// nil when she has never logged a pH reading.
    public let daysSinceLastPh: Int?
    public let phReadingsLast30Days: Int
    /// nil when she has never logged anything at all.
    public let daysSinceLastLog: Int?
    /// Her most-logged symptom in the last four weeks, and how often — drives Learn + Insights.
    public let topSymptom: (name: String, count: Int)?
    public let learnCandidates: [LearnCandidate]
    /// Days since each slot last fired. Absent = never fired.
    public let daysSinceSent: [NotificationSlot: Int]
    /// Whether today already has a meaningful log (drives the evening check-in's first branch).
    public let hasMeaningfulLogToday: Bool
    /// Water logged so far today, and the goal — the evening nudge's second branch compares these.
    public let waterTodayMl: Int
    public let waterGoalMl: Int
    /// Hour (0–23) she's chosen for the daily evening check-in.
    public let reminderHour: Int
    /// Days until her next predicted fertile window opens (0 = today). nil when no cycle is set.
    public let daysUntilFertileWindow: Int?
    /// ISO weekday of today (1 = Mon … 7 = Sun). The planner has no calendar of its own, and needs
    /// this to turn a day *offset* into the weekday the other nudges are keyed on.
    public let todayWeekday: Int
    /// Categories she has switched off. Empty means everything is on, so a category added in a
    /// later build arrives on rather than silently off for everyone who upgraded.
    public let mutedCategories: Set<NotificationCategory>
    /// The 90-Day Programme today. nil for everyone without it, and with nil the plan is exactly
    /// what it was before the programme existed.
    public let programme: ProgrammeReminderFacts?

    public init(
        streak: StreakState,
        daysSinceLastPh: Int?,
        phReadingsLast30Days: Int,
        daysSinceLastLog: Int?,
        topSymptom: (name: String, count: Int)?,
        learnCandidates: [LearnCandidate],
        daysSinceSent: [NotificationSlot: Int],
        hasMeaningfulLogToday: Bool = false,
        waterTodayMl: Int = 0,
        waterGoalMl: Int = TrackingEngine.defaultWaterGoalMl,
        reminderHour: Int = NotificationPlanner.hydrationHour,
        daysUntilFertileWindow: Int? = nil,
        todayWeekday: Int = 1,
        mutedCategories: Set<NotificationCategory> = [],
        programme: ProgrammeReminderFacts? = nil
    ) {
        self.streak = streak
        self.daysSinceLastPh = daysSinceLastPh
        self.phReadingsLast30Days = phReadingsLast30Days
        self.daysSinceLastLog = daysSinceLastLog
        self.topSymptom = topSymptom
        self.learnCandidates = learnCandidates
        self.daysSinceSent = daysSinceSent
        self.hasMeaningfulLogToday = hasMeaningfulLogToday
        self.waterTodayMl = waterTodayMl
        self.waterGoalMl = waterGoalMl
        self.reminderHour = reminderHour
        self.daysUntilFertileWindow = daysUntilFertileWindow
        self.todayWeekday = todayWeekday
        self.mutedCategories = mutedCategories
        self.programme = programme
    }
}

// MARK: - Outputs

public enum NotificationSlot: String, CaseIterable, Sendable {
    case hydration, ph, learn, insights, track, fertile
    /// The 90-Day Programme: the day's line, and the weekly review line. Two slots because they are
    /// two kinds of nudge: the review is one of the week's four and keeps a sent memory, and the
    /// day's line is that day's own message.
    case programme, programmeReview
}

/// Where a tap lands. Raw values match the app's tab order.
public enum NotificationTarget: Int, Sendable {
    case home = 0, track = 1, ph = 2, nutrition = 3, insights = 4, learn = 5, profile = 6
}

public struct PlannedNotification: Equatable, Sendable {
    public let slot: NotificationSlot
    public let title: String
    public let body: String
    public let target: NotificationTarget
    /// Set only for the Learn nudge.
    public let learnSlug: String?
    /// ISO weekday (1 = Mon … 7 = Sun). nil for the daily hydration nudge.
    public let weekday: Int?
    public let hour: Int
    /// Days from today, for a nudge tied to a specific date rather than a recurring weekday.
    /// The weekly nudges leave this nil and are scheduled by weekday alone; the fertile-window
    /// nudge sets it, because "the next Tuesday" and "the Tuesday her window opens" are only the
    /// same date until the hour has passed.
    public let dayOffset: Int?

    public init(slot: NotificationSlot, title: String, body: String, target: NotificationTarget,
                learnSlug: String? = nil, weekday: Int?, hour: Int, dayOffset: Int? = nil) {
        self.slot = slot
        self.title = title
        self.body = body
        self.target = target
        self.learnSlug = learnSlug
        self.weekday = weekday
        self.hour = hour
        self.dayOffset = dayOffset
    }
}

/// The whole week's plan.
public struct NotificationPlan: Equatable, Sendable {
    public let notifications: [PlannedNotification]

    /// The daily hydration nudge, if it's on this week.
    public var hydration: PlannedNotification? { notifications.first { $0.slot == .hydration } }
    /// Everything but the check-in: the weekly nudges, at most four (invariant 2 gives each its own
    /// day), and with the programme its line about today, on a day none of them owns.
    public var weekly: [PlannedNotification] { notifications.filter { $0.slot != .hydration } }
    /// Weekdays hydration must stand down on, because a weekly nudge already lands there.
    ///
    /// A nudge a full week out is excluded, and that exclusion is the whole subtlety: seven days
    /// from today is today's own weekday, so the fertile nudge at the far edge of its horizon used
    /// to claim tonight and push the evening check-in to tomorrow for something that fires next
    /// week. Weekdays are a fair proxy for the four evergreen nudges, which genuinely recur; the
    /// fertile nudge is one date, and at offset 7 the weekday alias is simply wrong.
    public var hydrationRestDays: Set<Int> {
        Set(weekly.filter { $0.dayOffset != 7 }.compactMap(\.weekday))
    }
}

// MARK: - The planner

public enum NotificationPlanner {

    /// At most four weekly nudges — one per day, each on its own morning. She'll keep four things
    /// she cares about; she'll switch off seven.
    public static let weeklyBudget = 4

    /// Silence after this many days with no log of any kind.
    static let dormantAfterDays = 14
    /// A gap this long earns one gentle nudge back.
    static let trackNudgeAfterDays = 3
    /// A pH reading is "due" once it's this old.
    static let phDueAfterDays = 7
    /// Enough readings for the trend to mean something (mirrors the Insights guard).
    static let phTrendReadyCount = 4

    static let phWeekday = 1,        phHour = 9        // Monday 09:00
    static let insightsWeekday = 3,  insightsHour = 8  // Wednesday 08:00
    static let trackWeekday = 5,     trackHour = 12    // Friday 12:00
    static let learnWeekday = 7,     learnHour = 9     // Sunday 09:00
    public static let hydrationHour = 10               // daily 10:00
    static let fertileHour = 8                         // morning her window opens

    /// Only plan the fertile nudge a week out. Beyond that the estimate has had no chance to move
    /// with a corrected period date, and the next replan will pick it up anyway.
    static let fertileHorizonDays = 7
    /// A window opens once a cycle, so anything under a fortnight is the same opening being
    /// re-planned — not a new one.
    static let fertileRepeatGuardDays = 14

    /// The programme's morning line. Its other lines use the hour she chose.
    static let programmeHour = 9

    public static func plan(_ snapshot: NotificationSnapshot) -> NotificationPlan {
        // Muting is applied here rather than to the finished plan, and that placement is the point:
        // a nudge dropped afterwards would still have consumed its share of the weekly budget and
        // still have claimed its morning, so hydration would stand down for a message she switched
        // off. Silenced means absent, not invisible.
        func allowed(_ notification: PlannedNotification?) -> PlannedNotification? {
            guard let notification,
                  !snapshot.mutedCategories.contains(notification.slot.category) else { return nil }
            return notification
        }

        // Invariant 4 — she's gone. One hand back at most, then nothing. An app that keeps
        // nagging someone who left is how it gets deleted.
        if let gap = snapshot.daysSinceLastLog, gap >= dormantAfterDays {
            let alreadyReachedOut = (snapshot.daysSinceSent[.track] ?? .max) < dormantAfterDays
            let handBack = alreadyReachedOut ? nil : allowed(dormantNudge())
            return NotificationPlan(notifications: [handBack].compactMap { $0 })
        }

        // Invariant 1 — each of these returns nil when it has nothing true to say.
        //
        // The fertile nudge goes first and the evergreen ones give way to it. It is the only nudge
        // pinned to a date she cannot be told about later: "your window opens today" is worthless
        // on Thursday. Everything else keeps just as well for a week.
        let fertileNudge = allowed(fertile(snapshot))
        // The programme's weekly line, the review, comes second: inside the same budget of four and
        // the same one-a-day rule, never on top of either. It is pinned to today, so it stands down
        // when the fertile nudge lands today. Both are dates, so the offsets are compared: a window
        // seven days out shares today's weekday and nothing else. An evergreen nudge on its weekday
        // gives way to it, as it does to the fertile nudge. Without the programme this is nil, and
        // nothing below differs from what it was.
        let reviewNudge = fertileNudge?.dayOffset == 0 ? nil : allowed(programmeReview(snapshot))
        let evergreen = [ph(snapshot), insights(snapshot), track(snapshot), learn(snapshot)]
            .compactMap(allowed)
            .filter { $0.weekday != fertileNudge?.weekday }   // invariant 2 — one a day
            .filter { $0.weekday != reviewNudge?.weekday }
        let weekly = Array(([fertileNudge, reviewNudge].compactMap { $0 } + evergreen).prefix(weeklyBudget))

        // The programme's line about today is not a fifth weekly nudge. It is that day's one daily
        // message, said in the evening check-in's place: planned only on a day none of the weekly
        // nudges owns, which are the days the check-in itself would speak, and the check-in rests
        // that day as it does for every nudge here. So it takes no place in the budget of four and
        // costs no weekly nudge its morning, and a week with the programme holds what a week
        // without it holds: at most four weekly nudges, and at most one message on any day.
        let ownedDays = NotificationPlan(notifications: weekly).hydrationRestDays
        let dayLine = ownedDays.contains(snapshot.todayWeekday) ? nil : allowed(programme(snapshot))

        let evening = allowed(hydration(snapshot)).map { [$0] } ?? []
        return NotificationPlan(notifications: evening + weekly + [dayLine].compactMap { $0 })
    }

    // MARK: Fertile window — the one nudge that cannot wait a week

    /// Fires on the morning her predicted fertile window opens.
    ///
    /// Deliberately discreet: a lock screen is read by whoever is holding the phone, so the words
    /// that reach it stay vague and the specifics ("days 9–15", the conception framing) stay inside
    /// the app, where she has already chosen to look.
    static func fertile(_ snapshot: NotificationSnapshot) -> PlannedNotification? {
        guard let days = snapshot.daysUntilFertileWindow,
              (0...fertileHorizonDays).contains(days) else { return nil }
        guard (snapshot.daysSinceSent[.fertile] ?? .max) >= fertileRepeatGuardDays else { return nil }

        return PlannedNotification(
            slot: .fertile,
            title: "A note about your cycle",
            // Present tense, always: this is scheduled for the morning the window opens, so it is
            // read on that day. Counting down from plan time ("in 3 days") would arrive stale.
            body: "Your predicted window opens today. Tap to see where you are.",
            target: .track,
            weekday: weekday(snapshot.todayWeekday, plus: days),
            hour: fertileHour,
            dayOffset: days
        )
    }

    /// ISO weekday `offset` days after `weekday`.
    static func weekday(_ weekday: Int, plus offset: Int) -> Int {
        ((weekday - 1 + offset) % 7) + 1
    }

    // MARK: Programme: a weekly review line, and one line about today while it is still true

    /// The programme, when it may speak at all: she holds access, it is running, today is day 1 to
    /// 90, and she has not switched its reminders off. nil otherwise, and with nil every rule in
    /// the planner is the rule from before the programme existed. The switch is asked here as well
    /// as in `plan`, because the check-in needs the same answer.
    static func activeProgramme(_ snapshot: NotificationSnapshot) -> ProgrammeReminderFacts? {
        guard let facts = snapshot.programme, facts.hasAccess, facts.started,
              (1...ProgrammeCalendar.totalDays).contains(facts.day),
              !snapshot.mutedCategories.contains(.programme) else { return nil }
        return facts
    }

    /// A programme line, pinned to today as the fertile nudge is pinned to its date: tomorrow has
    /// its own counts. nil once she has been notified today, so one a day holds across the replans
    /// of a day and not only inside one plan. nil once its hour has gone, so a line that can no
    /// longer be delivered does not take the day from the check-in.
    static func programmeLine(_ slot: NotificationSlot, _ body: String, hour: Int,
                              _ facts: ProgrammeReminderFacts,
                              _ snapshot: NotificationSnapshot) -> PlannedNotification? {
        guard !facts.notifiedToday, hour > facts.hourNow else { return nil }
        return PlannedNotification(slot: slot, title: "Your Programme", body: body, target: .home,
                                   weekday: snapshot.todayWeekday, hour: hour, dayOffset: 0)
    }

    /// The programme's weekly line: a review that has become ready, told once for each review.
    ///
    /// The sent memory for this slot has to count calendar days. A line that fired last night and
    /// one that fired this morning are both under 24 hours old, and only the second was sent on
    /// the day this review became ready. Counted in 24 hours, a review can be taken for the one
    /// before it and go unannounced.
    static func programmeReview(_ snapshot: NotificationSnapshot) -> PlannedNotification? {
        // Only a week that has ended has a review, whatever the flag says.
        guard let facts = activeProgramme(snapshot),
              let week = facts.reviewReadyWeek, week >= 1, week < facts.week else { return nil }
        // Whole days this review has been ready, 0 on the day after its week ends. Below 0 the day
        // says the week is still running, and a day and a week that disagree are not a yes. A
        // review line sent within those days was this one. Counted from the programme day rather
        // than a fixed gap, so next week's review is not held back by this week's.
        let readyFor = facts.day - week * ProgrammeCalendar.daysPerWeek - 1
        guard readyFor >= 0, (snapshot.daysSinceSent[.programmeReview] ?? .max) > readyFor else { return nil }
        // At the hour she chose, as the check-in is.
        return programmeLine(.programmeReview, "Your Week \(week) Programme Review is ready.",
                             hour: snapshot.reminderHour, facts, snapshot)
    }

    /// The programme's line about today. nil for everyone without the programme.
    ///
    /// Every question is answered before a word is written, and any "no" is silence:
    ///   • does she hold access, has the programme started, is today day 1 to 90, and is the
    ///     category on? (`activeProgramme`)
    ///   • is something relevant still open today? A finished activity is never mentioned.
    ///   • has she been notified already today, and can the line still be delivered?
    ///     (`programmeLine`)
    ///   • is today free? Answered in `plan`: it speaks only on a day no weekly nudge owns.
    ///
    /// One line: the morning line while nothing is done, the evening line once some but not all are
    /// done, and the testing line in place of either while an ovulation test is open.
    ///
    /// Counts only. No line says what she recorded, and none looks back at a day that is over.
    static func programme(_ snapshot: NotificationSnapshot) -> PlannedNotification? {
        guard let facts = activeProgramme(snapshot) else { return nil }
        let total = facts.activitiesToday, done = facts.activitiesDone
        guard done >= 0, done < total else { return nil }

        let body: String
        // The testing line is timed by her cycle, so it is one of the notes she switches off with
        // the Cycle category, and it names neither her cycle nor a test: a lock screen is read by
        // whoever is holding the phone. Which activity it is stays inside the app.
        if facts.ovulationTestOpen, !snapshot.mutedCategories.contains(.cycle) {
            body = "Today's Programme has an activity that is specific to today. Tap to see it."
        } else if done > 0 {
            body = "You've completed \(done) of today's \(total) Programme activities."
        } else {
            body = "Day \(facts.day) of your Genesyx Programme. You have \(total) Programme \(total == 1 ? "activity" : "activities") today."
        }
        return programmeLine(.programme, body, hour: done > 0 ? snapshot.reminderHour : programmeHour,
                             facts, snapshot)
    }

    // MARK: Evening check-in — one nudge at the hour she chose, in present-tense, guilt-free words

    /// The daily evening reminder (mirrors the Android reminder). Two branches, both inviting and
    /// present-tense — never a word about a streak or a day she lost (invariant 3):
    ///   • nothing meaningful logged today → a warm invitation to log
    ///   • logged, but water short of goal → a gentle nudge toward one more glass
    ///   • the day's already complete       → the same invitation, but for tomorrow
    static func hydration(_ snapshot: NotificationSnapshot) -> PlannedNotification? {
        func invitation(dayOffset: Int? = nil) -> PlannedNotification {
            PlannedNotification(
                slot: .hydration,
                title: "A quick log tonight?",
                body: "A moment to note how today went — it's how the picture builds.",
                target: .home, weekday: nil, hour: snapshot.reminderHour, dayOffset: dayOffset)
        }

        // With the programme, a nudge that has fired today has left the plan, and today no longer
        // looks taken. She has had today's one message, so the next invitation is tomorrow's.
        // Without the programme this is never asked, and tonight is decided as it always was.
        if activeProgramme(snapshot)?.notifiedToday == true { return invitation(dayOffset: 1) }
        if !snapshot.hasMeaningfulLogToday { return invitation() }
        if snapshot.waterTodayMl < snapshot.waterGoalMl {
            return PlannedNotification(
                slot: .hydration,
                title: "One more glass?",
                body: "A little water before the day winds down.",
                target: .nutrition, weekday: nil, hour: snapshot.reminderHour)
        }
        // She has finished the day, so tonight really has nothing to say — but this used to return
        // nil, and nil left the queue empty. Requests are one-shot and only rebuilt when the app is
        // opened, so the woman who logged everything was the one the app stopped speaking to: she
        // completes her day, has no reason to open the app again, and never hears from it again.
        // Tomorrow's invitation is still true when it lands, because she cannot log tomorrow
        // without opening the app, and opening it re-plans.
        return invitation(dayOffset: 1)
    }

    // MARK: pH — only when a reading is actually due

    static func ph(_ snapshot: NotificationSnapshot) -> PlannedNotification? {
        let title: String
        let body: String

        switch snapshot.daysSinceLastPh {
        case nil:
            title = "Your first pH reading"
            body = "One reading is where the trend starts. It takes a minute."
        case .some(let days) where days >= phDueAfterDays:
            if snapshot.phReadingsLast30Days >= phTrendReadyCount {
                title = "Keep the trend honest"
                body = "Your last reading was \(days) days ago. You've got \(snapshot.phReadingsLast30Days) this month — one more keeps the line true."
            } else {
                title = "Time for a reading"
                body = "Your last one was \(days) days ago. A few more and your trend starts to mean something."
            }
        default:
            return nil   // logged recently — nothing true to say
        }

        return PlannedNotification(slot: .ph, title: title, body: body,
                                   target: .ph, weekday: phWeekday, hour: phHour)
    }

    // MARK: Insights — only when her data has crossed into saying something new

    static func insights(_ snapshot: NotificationSnapshot) -> PlannedNotification? {
        guard (snapshot.daysSinceSent[.insights] ?? .max) >= 7 else { return nil }

        let streak = snapshot.streak
        let title: String
        let body: String

        if streak.daysLoggedThisWeek >= TrackingEngine.defaultWeeklyMinDays {
            title = "A steady week"
            body = "You've logged \(streak.daysLoggedThisWeek) of 7 days. That's what consistency looks like — see what it's showing."
        } else if snapshot.phReadingsLast30Days >= phTrendReadyCount {
            title = "Your pH trend has a shape"
            body = "\(snapshot.phReadingsLast30Days) readings this month is enough to see a line. Take a look."
        } else if let symptom = snapshot.topSymptom, symptom.count >= 3 {
            title = "A pattern worth seeing"
            body = "\(symptom.name) has come up \(symptom.count) times this month. Your heatmap shows when."
        } else {
            return nil   // thin data is thin — we don't invent a reason to buzz her
        }

        return PlannedNotification(slot: .insights, title: title, body: body,
                                   target: .insights, weekday: insightsWeekday, hour: insightsHour)
    }

    // MARK: Track — one gentle hand back after a real gap

    static func track(_ snapshot: NotificationSnapshot) -> PlannedNotification? {
        guard let gap = snapshot.daysSinceLastLog, gap >= trackNudgeAfterDays else { return nil }
        guard (snapshot.daysSinceSent[.track] ?? .max) >= 7 else { return nil }

        return PlannedNotification(
            slot: .track,
            title: "Still here",
            body: "Thirty seconds is all a log takes. Pick it up whenever you're ready.",
            target: .track, weekday: trackWeekday, hour: trackHour
        )
    }

    // MARK: Learn — the article her own data points at

    static func learn(_ snapshot: NotificationSnapshot) -> PlannedNotification? {
        guard let best = nextRead(from: snapshot.learnCandidates, interests: interestTags(snapshot))
        else { return nil }   // she's read the library — say nothing

        return PlannedNotification(
            slot: .learn,
            title: learnHeadline(best),
            body: "'\(best.title)' — a \(best.readingTime).",
            target: .learn, learnSlug: best.slug, weekday: learnWeekday, hour: learnHour
        )
    }

    /// The one article to point her at next, or nil once she's read them all.
    ///
    /// Shared by the Sunday nudge and the Home dashboard card so the two can never name different
    /// articles at the same moment. The card passes no interests: ranking by relevance needs the
    /// whole `NotificationSnapshot`, and Home would have to rebuild it — the ordering that actually
    /// matters (a new drop first, then a stable pick) is the part both surfaces share.
    public static func nextRead(from candidates: [LearnCandidate],
                                interests: [String] = []) -> LearnCandidate? {
        let unread = candidates.filter { !$0.read }
        guard !unread.isEmpty else { return nil }

        // A piece that has just arrived is the week's drop, and it outranks relevance: the library
        // she has had all along will still be there next Sunday. Within either pool the pick is
        // still what her own logging points at, and slug breaks ties so it doesn't move between
        // launches.
        let dropped = unread.filter(\.isNew)
        let pool = dropped.isEmpty ? unread : dropped

        return pool.max { a, b in
            (relevance(a, to: interests), b.slug) < (relevance(b, to: interests), a.slug)
        }
    }

    /// What to call the pick. `isNew` doubles as "this was the drop pool", because `nextRead` only
    /// ever reaches the whole-library pool when nothing new is unread.
    public static func learnHeadline(_ candidate: LearnCandidate) -> String {
        candidate.isNew ? "New this week" : "A read for your week"
    }

    /// What her data suggests she'd want to read about, most-wanted first.
    static func interestTags(_ snapshot: NotificationSnapshot) -> [String] {
        var tags: [String] = []
        if let symptom = snapshot.topSymptom, symptom.count >= 2 { tags.append(symptom.name.lowercased()) }
        if snapshot.phReadingsLast30Days < phTrendReadyCount { tags.append("ph") }
        if snapshot.streak.dailyHydration == 0 { tags.append("hydration") }
        if snapshot.streak.weeklyStreak >= 1 { tags.append("cycle") }
        return tags
    }

    /// Earlier interests count for more, so her strongest signal wins.
    static func relevance(_ candidate: LearnCandidate, to interests: [String]) -> Int {
        interests.enumerated().reduce(0) { score, entry in
            candidate.tags.contains(entry.element) ? score + (interests.count - entry.offset) : score
        }
    }

    // MARK: Dormant

    static func dormantNudge() -> PlannedNotification {
        PlannedNotification(
            slot: .track,
            title: "Whenever you're ready",
            body: "Your data is where you left it. Pick up any time — a single log is enough to start again.",
            target: .home, weekday: trackWeekday, hour: trackHour
        )
    }

    // MARK: Content safety

    /// Every sentence the planner can produce, across every state — the surface the banned-phrase
    /// and guilt scans walk. If you add a copy tier, add its state here.
    public static func allPossibleCopy() -> [String] {
        let library = [
            LearnCandidate(slug: "a", title: "Reading your pH trend", readingTime: "4 min read", tags: ["ph"], read: false),
            LearnCandidate(slug: "b", title: "Hydration and your cycle", readingTime: "3 min read", tags: ["hydration"], read: false),
        ]
        let libraryWithADrop = [
            LearnCandidate(slug: "a", title: "Reading your pH trend", readingTime: "4 min read", tags: ["ph"], read: false),
            LearnCandidate(slug: "c", title: "Your first two weeks", readingTime: "2 min read", tags: ["cycle"], read: false, isNew: true),
        ]
        func snapshot(daily: Int, best: Int, weekDays: Int, weekly: Int,
                      ph: Int?, phCount: Int, log: Int?, symptom: (String, Int)?,
                      loggedToday: Bool = false, waterToday: Int = 0,
                      fertileInDays: Int? = nil, newDrop: Bool = false) -> NotificationSnapshot {
            NotificationSnapshot(
                streak: StreakState(dailyHydration: daily, weeklyStreak: weekly,
                                    daysLoggedThisWeek: weekDays, bestDailyStreak: best,
                                    milestones: [], lapsedCelebrations: [], weekDots: []),
                daysSinceLastPh: ph, phReadingsLast30Days: phCount, daysSinceLastLog: log,
                topSymptom: symptom.map { (name: $0.0, count: $0.1) },
                learnCandidates: newDrop ? libraryWithADrop : library, daysSinceSent: [:],
                hasMeaningfulLogToday: loggedToday, waterTodayMl: waterToday,
                daysUntilFertileWindow: fertileInDays)
        }

        let states = [
            // Evening branch A — nothing logged today.
            snapshot(daily: 0, best: 0, weekDays: 0, weekly: 0, ph: nil, phCount: 0, log: nil, symptom: nil),
            snapshot(daily: 0, best: 9, weekDays: 2, weekly: 1, ph: 30, phCount: 1, log: 4, symptom: ("Fatigue", 5)),
            // Evening branch B — logged, but water short of goal.
            snapshot(daily: 1, best: 1, weekDays: 1, weekly: 0, ph: 8, phCount: 2, log: 0, symptom: nil,
                     loggedToday: true, waterToday: 500),
            snapshot(daily: 6, best: 6, weekDays: 5, weekly: 1, ph: 9, phCount: 6, log: 0, symptom: ("Cramps", 3)),
            snapshot(daily: 13, best: 13, weekDays: 6, weekly: 2, ph: 2, phCount: 6, log: 0, symptom: nil),
            snapshot(daily: 22, best: 22, weekDays: 7, weekly: 4, ph: 1, phCount: 9, log: 0, symptom: nil),
            // Fertile window — opening today, and opening later in the week.
            snapshot(daily: 3, best: 3, weekDays: 3, weekly: 1, ph: 2, phCount: 5, log: 0, symptom: nil,
                     fertileInDays: 0),
            snapshot(daily: 3, best: 3, weekDays: 3, weekly: 1, ph: 2, phCount: 5, log: 0, symptom: nil,
                     fertileInDays: 4),
            // An article that arrived in this update — the Sunday read announces itself differently.
            snapshot(daily: 3, best: 3, weekDays: 3, weekly: 1, ph: 2, phCount: 5, log: 0, symptom: nil,
                     newDrop: true),
        ]

        var copy = states.flatMap { plan($0).notifications.flatMap { [$0.title, $0.body] } }
        copy += [dormantNudge().title, dormantNudge().body]
        copy += programmeCopy()
        return copy
    }

    /// Every programme sentence, in every state. Part of `allPossibleCopy`, and listed on its own
    /// because the programme lines are held to a longer banned list than the rest.
    public static func programmeCopy() -> [String] {
        func snapshot(done: Int, of total: Int, test: Bool = false, review: Int? = nil) -> NotificationSnapshot {
            NotificationSnapshot(
                streak: StreakState(dailyHydration: 0, weeklyStreak: 0, daysLoggedThisWeek: 0,
                                    bestDailyStreak: 0, milestones: [], lapsedCelebrations: [], weekDots: []),
                daysSinceLastPh: nil, phReadingsLast30Days: 0, daysSinceLastLog: nil, topSymptom: nil,
                learnCandidates: [], daysSinceSent: [:],
                programme: ProgrammeReminderFacts(
                    hasAccess: true, started: true, day: 43, week: 7,
                    activitiesToday: total, activitiesDone: done,
                    ovulationTestOpen: test, reviewReadyWeek: review))
        }

        let states = [
            snapshot(done: 0, of: 1),               // morning line, a single activity
            snapshot(done: 0, of: 4),               // morning line
            snapshot(done: 4, of: 5),               // evening line
            snapshot(done: 0, of: 4, test: true),   // testing line
            snapshot(done: 4, of: 4, review: 6),    // weekly review line
        ]
        return states.compactMap { programmeReview($0) ?? programme($0) }.flatMap { [$0.title, $0.body] }
    }
}
