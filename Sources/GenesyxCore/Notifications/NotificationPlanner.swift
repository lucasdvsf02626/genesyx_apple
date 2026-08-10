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
        mutedCategories: Set<NotificationCategory> = []
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
    }
}

// MARK: - Outputs

public enum NotificationSlot: String, CaseIterable, Sendable {
    case hydration, ph, learn, insights, track, fertile
}

/// Where a tap lands. Raw values match the app's tab order.
public enum NotificationTarget: Int, Sendable {
    case home = 0, track = 1, nutrition = 2, insights = 3, learn = 4, profile = 5
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
    /// The weekly nudges, at most four (invariant 2 gives each its own day).
    public var weekly: [PlannedNotification] { notifications.filter { $0.slot != .hydration } }
    /// Weekdays hydration must stand down on, because a weekly nudge already lands there.
    public var hydrationRestDays: Set<Int> { Set(weekly.compactMap(\.weekday)) }
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
        let evergreen = [ph(snapshot), insights(snapshot), track(snapshot), learn(snapshot)]
            .compactMap(allowed)
            .filter { $0.weekday != fertileNudge?.weekday }   // invariant 2 — one a day
        let weekly = (Array([fertileNudge].compactMap { $0 }) + evergreen).prefix(weeklyBudget)

        let evening = allowed(hydration(snapshot)).map { [$0] } ?? []
        return NotificationPlan(notifications: evening + Array(weekly))
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

    // MARK: Evening check-in — one nudge at the hour she chose, in present-tense, guilt-free words

    /// The daily evening reminder (mirrors the Android reminder). Two branches, both inviting and
    /// present-tense — never a word about a streak or a day she lost (invariant 3):
    ///   • nothing meaningful logged today → a warm invitation to log
    ///   • logged, but water short of goal → a gentle nudge toward one more glass
    ///   • the day's already complete       → nothing at all (invariant 1)
    static func hydration(_ snapshot: NotificationSnapshot) -> PlannedNotification? {
        if !snapshot.hasMeaningfulLogToday {
            return PlannedNotification(
                slot: .hydration,
                title: "A quick log tonight?",
                body: "A moment to note how today went — it's how the picture builds.",
                target: .home, weekday: nil, hour: snapshot.reminderHour)
        }
        if snapshot.waterTodayMl < snapshot.waterGoalMl {
            return PlannedNotification(
                slot: .hydration,
                title: "One more glass?",
                body: "A little water before the day winds down.",
                target: .nutrition, weekday: nil, hour: snapshot.reminderHour)
        }
        return nil   // logged, and hydration's already there — nothing left to say
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
                                   target: .track, weekday: phWeekday, hour: phHour)
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
        let unread = snapshot.learnCandidates.filter { !$0.read }
        guard !unread.isEmpty else { return nil }   // she's read the library — say nothing

        // A piece that has just arrived is the week's drop, and it outranks relevance: the library
        // she has had all along will still be there next Sunday. Within either pool the pick is
        // still what her own logging points at.
        let dropped = unread.filter(\.isNew)
        let pool = dropped.isEmpty ? unread : dropped

        let interests = interestTags(snapshot)
        let best = pool.max { a, b in
            (relevance(a, to: interests), b.slug) < (relevance(b, to: interests), a.slug)
        }!

        return PlannedNotification(
            slot: .learn,
            title: dropped.isEmpty ? "A read for your week" : "New this week",
            body: "'\(best.title)' — a \(best.readingTime).",
            target: .learn, learnSlug: best.slug, weekday: learnWeekday, hour: learnHour
        )
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
        return copy
    }
}
