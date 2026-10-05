import Foundation

/// The three phases of the 90-Day Programme. Thirty days each.
public enum ProgrammePhase: Int, CaseIterable, Codable, Sendable {
    case buildTheFoundation = 1
    case discoverYourPatterns = 2
    case personaliseAndSustain = 3

    /// The programme days this phase covers.
    public var dayRange: ClosedRange<Int> {
        let first = (rawValue - 1) * ProgrammeCalendar.daysPerPhase + 1
        return first...(first + ProgrammeCalendar.daysPerPhase - 1)
    }
}

/// The facts about a programme run that cannot be derived, and nothing else.
///
/// There is no stored day, week, phase or "completed" flag: each of those is worked out from
/// `startedOn` and the date passed in, so a reinstall, a second device or a moved clock can never
/// leave a stored number disagreeing with the calendar.
///
/// Access to the programme is a separate model (`ProgrammeAccess`). Being granted access does not
/// set `startedOn`; she chooses when day 1 is.
public struct ProgrammeState: Hashable, Codable, Sendable {
    /// The calendar date she started on, in the app's date-only convention. `nil` = not started.
    public var startedOn: CalendarDate?
    /// The calendar date she chose to leave the programme. It cannot be inferred, so it is stored.
    public var stoppedOn: CalendarDate?
    /// The content version in force when she started, so a later schedule revision does not
    /// rewrite what her earlier weeks asked for.
    public var contentVersion: String?

    public init(startedOn: CalendarDate? = nil, stoppedOn: CalendarDate? = nil, contentVersion: String? = nil) {
        self.startedOn = startedOn
        self.stoppedOn = stoppedOn
        self.contentVersion = contentVersion
    }

    public static let notStarted = ProgrammeState()
}

/// Where a date falls in the programme.
public enum ProgrammePosition: Hashable, Sendable {
    /// No start date is stored.
    case notStarted
    /// The date is earlier than the start date (clock moved back, or a second device on an earlier
    /// calendar day). Never a negative day.
    case beforeStart(daysUntilStart: Int)
    /// Day 1 to 90.
    case active(day: Int, week: Int, phase: ProgrammePhase)
    /// Day 91 onwards: the programme is complete and she carries on. `day` keeps counting.
    case completed(day: Int)
    /// She left the programme on or before this date.
    case stopped
}

/// Day, week and phase arithmetic. Every function takes its dates as arguments.
///
/// The start is a calendar date, so the day is whole calendar days since the start, plus one. No
/// clock time is involved: a start at 23:59 and a clock change both leave the count alone.
public enum ProgrammeCalendar {

    public static let totalDays = 90
    public static let totalWeeks = 13
    public static let daysPerWeek = 7
    public static let daysPerPhase = 30

    /// Whole calendar days since the start, plus one. 1 on the start date; 0 or less before it; no
    /// upper bound. Use `position` when a bounded answer is wanted.
    public static func dayNumber(on date: CalendarDate, startedOn: CalendarDate) -> Int {
        date.dayNumber - startedOn.dayNumber + 1
    }

    /// The calendar date of a programme day.
    public static func date(ofDay day: Int, startedOn: CalendarDate) -> CalendarDate {
        startedOn.plusDays(day - 1)
    }

    /// Week 1 to 13 for a day from 1 to 90. Weeks run from the start date, seven days each; days 85
    /// to 90 are week 13, which therefore has six days.
    public static func week(forDay day: Int) -> Int {
        min(max((day - 1) / daysPerWeek + 1, 1), totalWeeks)
    }

    /// The programme days in a week (week 13 is 85...90).
    public static func dayRange(ofWeek week: Int) -> ClosedRange<Int> {
        let first = (week - 1) * daysPerWeek + 1
        return first...min(first + daysPerWeek - 1, totalDays)
    }

    /// The phase for a day from 1 to 90.
    public static func phase(forDay day: Int) -> ProgrammePhase {
        ProgrammePhase(rawValue: min(max((day - 1) / daysPerPhase + 1, 1), 3)) ?? .buildTheFoundation
    }

    public static func position(_ state: ProgrammeState, on date: CalendarDate) -> ProgrammePosition {
        guard let start = state.startedOn else { return .notStarted }
        if let stopped = state.stoppedOn, date >= stopped { return .stopped }
        let day = dayNumber(on: date, startedOn: start)
        if day < 1 { return .beforeStart(daysUntilStart: 1 - day) }
        if day > totalDays { return .completed(day: day) }
        return .active(day: day, week: week(forDay: day), phase: phase(forDay: day))
    }

    /// The programme day from 1 to 90 on this date, or `nil` when the date is not a programme day
    /// (not started, before the start, after day 90, or stopped).
    public static func activeDay(_ state: ProgrammeState, on date: CalendarDate) -> Int? {
        if case .active(let day, _, _) = position(state, on: date) { return day }
        return nil
    }

    /// Day reached out of 90, from 0 to 1. Day 23 gives 23/90; day 91 onwards gives 1; not started,
    /// before the start and stopped give 0.
    public static func progressFraction(_ state: ProgrammeState, on date: CalendarDate) -> Double {
        switch position(state, on: date) {
        case .active(let day, _, _): return Double(day) / Double(totalDays)
        case .completed: return 1
        case .notStarted, .beforeStart, .stopped: return 0
        }
    }

    /// Programme days still to come after this date: 89 on day 1, 0 on day 90 and afterwards, and
    /// the full 90 while she has not started or the date is before the start. `nil` once stopped.
    public static func daysRemaining(_ state: ProgrammeState, on date: CalendarDate) -> Int? {
        switch position(state, on: date) {
        case .active(let day, _, _): return totalDays - day
        case .completed: return 0
        case .notStarted, .beforeStart: return totalDays
        case .stopped: return nil
        }
    }
}
