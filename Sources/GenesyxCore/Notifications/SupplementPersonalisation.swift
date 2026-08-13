import Foundation

/// What the app knows about how she is actually getting on with the supplements she chose.
///
/// Everything here is already recorded for other reasons — the daily log holds which supplements she
/// ticked, her pH readings are stamped with the time she took them, and her quiz answers are read in
/// three other places. Nothing new is collected to make this work.
public struct SupplementSignals: Equatable, Sendable {
    /// Days in the trailing week (0...7) she logged ANY supplement.
    ///
    /// Deliberately day-level rather than per-supplement, because per-supplement is not computable
    /// today: `DailyLog.supplements` holds display names from a fixed list in `LogView`
    /// (Folic acid, Vitamin D, Iron, Omega-3) while a reminder is keyed `essential.<initial>` or a
    /// custom UUID. The two vocabularies do not even describe the same set — the plan carries Folate
    /// and Zinc where the log offers Folic acid and Iron, and a custom supplement cannot be logged at
    /// all. Joining them would mean inventing a name map that is wrong the first time either list is
    /// edited. Fix the vocabularies first; then this can narrow.
    public let daysLoggingSupplementsLastWeek: Int
    /// The hour of day she is demonstrably awake and using the app, or nil when there is too little
    /// history to say.
    ///
    /// Read from pH readings because `PhReading.recordedAt` is the ONLY wall-clock time this app
    /// records. `DailyLog` is keyed by `CalendarDate` and carries no clock at all, so "the hour she
    /// logs" is simply not answerable from the daily log. Widen this the day daily logs gain a
    /// timestamp; until then a woman who never uses the pH tracker gets nil and no shift, which is
    /// the correct outcome rather than a guess.
    public let typicalLogHour: Int?
    /// Her onboarding answers, read for the `support` question only.
    public let quizAnswers: [String: String]
    /// Carried, and deliberately NOT consumed — see `SupplementPersonalisation`.
    public let phase: Phase?

    public init(daysLoggingSupplementsLastWeek: Int,
                typicalLogHour: Int?,
                quizAnswers: [String: String],
                phase: Phase?) {
        self.daysLoggingSupplementsLastWeek = daysLoggingSupplementsLastWeek
        self.typicalLogHour = typicalLogHour
        self.quizAnswers = quizAnswers
        self.phase = phase
    }
}

extension SupplementSignals {

    /// Below this many timestamped readings the modal hour is noise, not a habit — one reading
    /// taken at 3am on a bad night should not move a morning alarm.
    public static let minimumHourSample = 4

    /// Reads the signals out of what the app already stores.
    ///
    /// Pure on purpose: the caller hands over the repositories' contents and gets a value back, so
    /// every rule here is testable without a simulator, a clock, or a notification centre.
    public static func from(logs: [CalendarDate: DailyLog],
                            readingDates: [Date],
                            quizAnswers: [String: String],
                            phase: Phase?,
                            today: CalendarDate = .today(),
                            calendar: Calendar = .current) -> SupplementSignals {
        SupplementSignals(
            daysLoggingSupplementsLastWeek: daysLoggingSupplements(logs: logs, today: today),
            typicalLogHour: typicalHour(of: readingDates, calendar: calendar),
            quizAnswers: quizAnswers,
            phase: phase
        )
    }

    /// Days in the trailing week — today and the six before it — on which she ticked any supplement.
    static func daysLoggingSupplements(logs: [CalendarDate: DailyLog], today: CalendarDate) -> Int {
        (0..<7).count { logs[today.minusDays($0)]?.supplements.isEmpty == false }
    }

    /// The hour she most often records a reading at, or nil below `minimumHourSample`.
    ///
    /// Ties break to the earliest hour so the same history always yields the same answer — the
    /// scheduled set has to be identical between launches given identical input.
    static func typicalHour(of dates: [Date], calendar: Calendar = .current) -> Int? {
        guard dates.count >= minimumHourSample else { return nil }
        let hours = dates.map { calendar.component(.hour, from: $0) }
        let counts = Dictionary(hours.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key
    }
}

/// Personalises the reminders she already set: WHEN they fire, and HOW they read. Never WHICH
/// supplements she takes.
///
/// That boundary is the entire design, not a limitation of it. Recommending a supplement to a named
/// individual is personalised health advice and needs medical-review sign-off; shifting the hour of
/// an alarm she set herself, and appending a sentence that makes no health claim, needs none. By
/// construction this type cannot add a supplement she did not choose or remove one she did — it maps
/// her list to itself, preserving `id` and `name` and `dose`.
///
/// `id` is preserved for a second, mechanical reason: it is the notification request identifier, so
/// changing it would orphan the pending request instead of replacing it.
///
/// **On cycle phase.** `SupplementSignals` carries `phase` and nothing reads it. Any wording that
/// tied a supplement to a phase — take this one now, in your luteal phase — asserts that the
/// supplement does something phase-specific, which is exactly the unsupported claim the gender
/// question already had stripped out of it for the same reason. Phase is plumbed because the signal
/// is genuinely wanted and the plumbing is the expensive half; a rule that uses it safely is a
/// content decision for the medical reviewer, not something to invent here.
public enum SupplementPersonalisation {

    /// How far a reminder may move from the hour she chose. She picked that time for reasons the app
    /// cannot see — with food, or spaced away from a medication — so this nudges by hours and never
    /// relocates to an arbitrarily "better" time.
    public static let maxShiftHours = 2

    /// At or below this over the trailing week, the alarm is not working and is worth moving. Above
    /// it, she is already acting on it and moving it would be change for its own sake.
    public static let poorAdherenceRatio = 0.5

    /// Days of the trailing week she must have logged supplements to earn the affirming line.
    public static let strongAdherenceDays = 5

    public static func apply(to reminders: [SupplementReminder],
                             signals: SupplementSignals) -> [SupplementReminder] {
        let days = signals.daysLoggingSupplementsLastWeek
        return reminders.map { reminder in
            SupplementReminder(
                id: reminder.id,
                name: reminder.name,
                dose: reminder.dose,
                hour: shiftedHour(from: reminder.hour, daysLogged: days, toward: signals.typicalLogHour),
                context: context(daysLogged: days, quizAnswers: signals.quizAnswers)
            )
        }
    }

    /// Moves the reminder toward the hour she is demonstrably awake and using the app, but only when
    /// the current hour is not earning its place, and never by more than `maxShiftHours`.
    static func shiftedHour(from hour: Int, daysLogged: Int, toward typical: Int?) -> Int {
        guard let typical, (0...23).contains(typical) else { return hour }
        guard Double(daysLogged) / 7.0 <= poorAdherenceRatio else { return hour }

        let delta = typical - hour
        let capped = max(-maxShiftHours, min(maxShiftHours, delta))
        return hour + capped
    }

    /// The one appended sentence, or nil for the plain reminder.
    ///
    /// A missed week returns nil on purpose. The planner's standing rule is never to make her feel
    /// guilty, and there is no sentence about a week of blanks that reads as encouragement to the
    /// person who lived it — silence is the kinder default, and the reminder still arrives.
    static func context(daysLogged: Int, quizAnswers: [String: String]) -> String? {
        if daysLogged >= strongAdherenceDays { return consistency }
        if quizAnswers["support"] == "supplements" { return guidance }
        return nil
    }

    static let consistency = "You've kept this going most of the week."
    static let guidance = "Open Nutrition whenever you'd like a refresher on your plan."

    /// Every context string that can ship, for the copy scans to walk.
    public static var allContexts: [String] { [consistency, guidance] }
}
