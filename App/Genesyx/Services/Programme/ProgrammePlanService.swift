import Foundation
import GenesyxCore

/// Everything the programme reads, as plain values. Nothing here is stored.
///
/// Two things are deliberately never a field: pregnancy test records, which feed no task and no
/// figure, and the intimacy field of a daily log, which nothing below reads. Access to the
/// programme is not a field either: whoever shows a plan or a figure checks access first.
///
/// Known limits. Three fields hold today's answer with no history behind it, and today's answer
/// is applied to every programme date, so a change rewrites what earlier days read as. Each is a
/// later decision, because the fix is a new stored fact.
/// - `consentActive`: after a re-grant, the days spent withdrawn read as not recorded.
/// - `quizAnswers`: a new supplements answer moves the supplements check-in into or out of the
///   count on every earlier day. From "no" to "yes", earlier days read as not recorded.
/// - `cycleSettings`: an edited cycle length moves the predicted fertile window of earlier
///   cycles, and with it the days an ovulation test is counted on. A new last period date does
///   not, where a period record exists (see `RecordIndex.cycleSettings`); where none does, it
///   moves them as well.
struct ProgrammePlanInput: Equatable {
    var state: ProgrammeState
    var today: CalendarDate
    var completions: ProgrammeCompletions = ProgrammeCompletions()
    var logsByDate: [CalendarDate: DailyLog] = [:]
    var waterGoalMl: Int = TrackingEngine.defaultWaterGoalMl
    var phReadingDates: [CalendarDate] = []     // local date of each visible vaginal reading, one entry per reading
    var lhResultDates: [CalendarDate] = []      // local date of each visible ovulation-test result
    var periods: [PeriodRecord] = []            // visible period records
    var cycleSettings: CycleSettings? = nil
    var quizAnswers: [String: String] = [:]     // keyed by QuizQuestion.id
    /// Today's answer, applied to every date. While consent is withdrawn every task of every day
    /// is not applicable and no figure is shown. Known limit: after a re-grant, the days spent
    /// withdrawn read as not recorded. A per-date answer from the consent trail is a later decision.
    var consentActive: Bool = true
    var scanFeaturesAvailable: Bool = false
    var phLoggingAvailable: Bool = true
}

/// Turns what the trackers hold into the core engine's inputs, and is the only producer of
/// `[ProgrammeDayPlan]` in the app: the reviews and My Fertility Picture are handed its output.
///
/// No arithmetic lives here. Every plan comes from `ProgrammeTaskEngine.plan`, every figure from
/// `ProgrammeConsistency.report`, and the dates are compared as calendar dates only. Of a test
/// only "a record exists on this date" is read, never its value or its result.
enum ProgrammePlanService {

    /// What the programme puts first for her, from the onboarding answer she already gave.
    static func goal(_ input: ProgrammePlanInput) -> ProgrammeGoalEmphasis {
        ProgrammeGoalEmphasis(storedStage: input.quizAnswers["stage"])
    }

    /// What the app knows about one date, in the engine's terms. A date outside the ninety
    /// programme dates has no programme week and no period answer: the engine has no plan for it.
    static func snapshot(on date: CalendarDate, input: ProgrammePlanInput) -> ProgrammeDaySnapshot {
        snapshot(on: date, input: input, index: RecordIndex(input))
    }

    /// The tasks for the programme day falling on `date`, or `nil` when it is not a programme day.
    static func plan(on date: CalendarDate, input: ProgrammePlanInput, content: ProgrammeContent = .draft) -> ProgrammeDayPlan? {
        plan(on: date, input: input, index: RecordIndex(input), content: content)
    }

    /// One plan for each programme day from day 1 up to today's, at most ninety, in day order.
    /// Empty when she has not started or today is before the start; all ninety from day 91 on;
    /// with a stop marker, the days before it.
    static func plans(_ input: ProgrammePlanInput, content: ProgrammeContent = .draft) -> [ProgrammeDayPlan] {
        guard let start = input.state.startedOn else { return [] }
        let todayDay = ProgrammeCalendar.dayNumber(on: input.today, startedOn: start)
        guard todayDay >= 1 else { return [] }
        let index = RecordIndex(input)   // built once: ninety days must not be ninety passes over the records
        return (1...min(todayDay, ProgrammeCalendar.totalDays)).compactMap { day in
            plan(on: ProgrammeCalendar.date(ofDay: day, startedOn: start), input: input, index: index, content: content)
        }
    }

    /// Every consistency figure for the input's "today". This builds the plans again: a caller
    /// that needs both takes `plans` once and hands them to `ProgrammeConsistency.report` itself.
    static func report(_ input: ProgrammePlanInput, content: ProgrammeContent = .draft) -> ProgrammeConsistencyReport {
        ProgrammeConsistency.report(state: input.state, today: input.today, plans: plans(input, content: content))
    }

    // MARK: Mapping

    private static func plan(
        on date: CalendarDate, input: ProgrammePlanInput, index: RecordIndex, content: ProgrammeContent
    ) -> ProgrammeDayPlan? {
        ProgrammeTaskEngine.plan(on: date, state: input.state, today: input.today, goal: goal(input),
                                 snapshot: snapshot(on: date, input: input, index: index), content: content)
    }

    private static func snapshot(on date: CalendarDate, input: ProgrammePlanInput, index: RecordIndex) -> ProgrammeDaySnapshot {
        ProgrammeDaySnapshot(
            log: input.logsByDate[date],
            waterGoalMl: input.waterGoalMl,
            phReadingExistsThisProgrammeWeek:
                programmeWeek(of: date, startedOn: input.state.startedOn).map { index.phWeeks.contains($0) } ?? false,
            lhResultExistsForDate: index.lhDates.contains(date),
            periodRecordExistsForDate: index.periodDates.contains(date),
            cycleSettings: index.cycleSettings(input.cycleSettings, on: date),
            scanFeaturesAvailable: input.scanFeaturesAvailable,
            phLoggingAvailable: input.phLoggingAvailable,
            completedLessonIDs: input.completions.lessonsRead,
            completedReviewWeeks: input.completions.weeklyReviewsViewed,
            supplementsAnswer: input.quizAnswers["supplements"],
            consentActive: input.consentActive
        )
    }

    /// The programme week a date falls in, or `nil` when it is not one of the ninety programme
    /// dates. `ProgrammeCalendar.week(forDay:)` clamps, so the range is checked first: the day
    /// before the start and day 91 belong to no programme week.
    private static func programmeWeek(of date: CalendarDate, startedOn start: CalendarDate?) -> Int? {
        guard let start else { return nil }
        let day = ProgrammeCalendar.dayNumber(on: date, startedOn: start)
        guard (1...ProgrammeCalendar.totalDays).contains(day) else { return nil }
        return ProgrammeCalendar.week(forDay: day)
    }

    /// What the test and period records say, worked out once per input and then asked day by day.
    private struct RecordIndex {
        /// Programme weeks holding a pH reading. Manual and scanned readings count alike.
        var phWeeks: Set<Int> = []
        /// Dates with an ovulation-test result. Any saved result counts: an invalid test was
        /// still a test.
        let lhDates: Set<CalendarDate>
        /// Programme dates a period record covers, the seeded record included. Clipped to the
        /// ninety programme dates, so a record with a far-off end cannot grow the set.
        var periodDates: Set<CalendarDate> = []
        /// Her period starts, earliest first.
        let periodStarts: [CalendarDate]

        init(_ input: ProgrammePlanInput) {
            lhDates = Set(input.lhResultDates)
            periodStarts = input.periods.map(\.startDate).sorted()
            guard let start = input.state.startedOn else { return }
            for date in input.phReadingDates {
                if let week = programmeWeek(of: date, startedOn: start) { phWeeks.insert(week) }
            }
            let last = ProgrammeCalendar.date(ofDay: ProgrammeCalendar.totalDays, startedOn: start)
            for period in input.periods {
                // An end earlier than its start counts as the start date only.
                let end = min(max(period.endDate ?? period.startDate, period.startDate), last)
                var date = max(period.startDate, start)
                while date <= end {
                    periodDates.insert(date)
                    date = date.plusDays(1)
                }
            }
        }

        /// Her settings as the prediction for `date` reads them. The last period date is her
        /// latest recorded start on or before `date`, or her first recorded start for a date
        /// before it, so recording her next period leaves the predicted window of earlier days
        /// where it was. The lengths are the ones she has set now, and `CycleEngine` still makes
        /// the prediction. With no period record her settings are passed on as they are.
        func cycleSettings(_ settings: CycleSettings?, on date: CalendarDate) -> CycleSettings? {
            // Searched from her latest start back, so it stops at the first one that fits.
            guard let settings, let start = periodStarts.last(where: { $0 <= date }) ?? periodStarts.first else {
                return settings
            }
            return CycleSettings(lastPeriodDate: start, cycleLength: settings.cycleLength, periodLength: settings.periodLength)
        }
    }
}
