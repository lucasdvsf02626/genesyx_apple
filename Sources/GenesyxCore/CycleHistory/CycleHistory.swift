import Foundation

/// Whether a derived cycle is still running or has been closed by a later period start.
public enum CycleStatus: String, Sendable {
    case active, completed
}

/// One cycle, worked out from two consecutive period starts. Never stored: it is rebuilt from the
/// period records every time, so an edited or deleted start can never leave a stale length behind.
public struct DerivedCycle: Identifiable, Hashable, Sendable {
    /// The first day of the period that opened this cycle. Also its identity.
    public let start: CalendarDate
    /// The day before the next period start, inclusive. Nil while this is the latest cycle.
    public let end: CalendarDate?
    /// Next start minus this start, in days. Nil while the cycle is open. Never clamped.
    public let length: Int?
    /// Days of bleeding, counted inclusively. Nil unless she recorded an end for this period.
    public let periodDays: Int?
    /// Where this cycle's own start came from.
    public let source: PeriodSource
    /// Where the start that closed this cycle came from. Nil while the cycle is open.
    public let closingSource: PeriodSource?

    public var id: CalendarDate { start }

    public var status: CycleStatus { end == nil ? .active : .completed }

    /// True when neither boundary rests on the seeded record, so the length is something she
    /// entered at both ends. Statistics should count only these.
    public var isRecorded: Bool { source == .recorded && closingSource != .seeded }

    public init(
        start: CalendarDate,
        end: CalendarDate?,
        length: Int?,
        periodDays: Int?,
        source: PeriodSource,
        closingSource: PeriodSource?
    ) {
        self.start = start
        self.end = end
        self.length = length
        self.periodDays = periodDays
        self.source = source
        self.closingSource = closingSource
    }
}

/// Reading cycle history. Everything here is derived from period records and states facts only:
/// dates, counts of days, and whether enough has been recorded to say anything across cycles.
/// No prediction lives here, and nothing here feeds `CycleEngine`.
public enum CycleHistory {

    /// The fewest completed, recorded, in-range cycles before a statement across cycles is allowed.
    public static let minimumCyclesForCrossCycleStatement = 3

    /// The cycles her period records describe, earliest first.
    ///
    /// Each visible start opens a cycle; the next start closes it. The latest cycle is open, with
    /// no end and no length. A deleted start simply is not there, so the cycle before it runs on
    /// to the following start. Lengths are plain date differences, however short or long.
    public static func cycles(from records: [StoredPeriodRecord]) -> [DerivedCycle] {
        let periods = PeriodSync.visible(records)
        return periods.enumerated().map { index, period in
            let next = index + 1 < periods.count ? periods[index + 1] : nil
            // An end that reaches the next start can only arrive through a merge of two devices'
            // edits; it is not counted until she corrects it.
            let periodEnd = period.endDate.flatMap { end -> CalendarDate? in
                if end < period.startDate { return nil }
                if let next, end >= next.startDate { return nil }
                return end
            }
            return DerivedCycle(
                start: period.startDate,
                end: next.map { $0.startDate.minusDays(1) },
                length: next.map { CycleEngine.daysBetween(period.startDate, $0.startDate) },
                periodDays: periodEnd.map { CycleEngine.daysBetween(period.startDate, $0) + 1 },
                source: period.source,
                closingSource: next?.source
            )
        }
    }

    /// The cycle `date` falls in, or nil when it is before the first recorded start. The open
    /// cycle has no upper bound, so every date on or after the latest start belongs to it.
    ///
    /// `cycles` must be in start order, as `cycles(from:)` returns them.
    public static func cycle(containing date: CalendarDate, in cycles: [DerivedCycle]) -> DerivedCycle? {
        cycles.last { $0.start <= date }
    }

    /// The 1-based day of the recorded cycle `date` falls in: a start date is day 1. Nil before
    /// the first recorded start. This is a count from a recorded start, not a prediction.
    public static func cycleDay(on date: CalendarDate, in cycles: [DerivedCycle]) -> Int? {
        cycle(containing: date, in: cycles).map { CycleEngine.daysBetween($0.start, date) + 1 }
    }

    /// The length of every completed cycle, earliest first, seeded ones included. The open cycle
    /// has no length and is left out.
    public static func completedLengths(_ cycles: [DerivedCycle]) -> [Int] {
        cycles.compactMap(\.length)
    }

    /// The completed cycles that may be counted in a statement across cycles: recorded at both
    /// ends, and with a length inside the range the app already accepts for a cycle length.
    /// Anything else can still be listed with its dates and length, without comment.
    public static func countableCycles(_ cycles: [DerivedCycle]) -> [DerivedCycle] {
        cycles.filter { cycle in
            guard let length = cycle.length else { return false }
            return cycle.isRecorded && CycleEngine.cycleLengthRange.contains(length)
        }
    }

    /// Whether enough has been recorded to say anything across cycles at all.
    public static func canMakeCrossCycleStatement(_ cycles: [DerivedCycle]) -> Bool {
        countableCycles(cycles).count >= minimumCyclesForCrossCycleStatement
    }

    /// Groups dated observations (daily logs, test results, readings) by the cycle their date
    /// falls in, keyed by that cycle's start. Order within a group is the order given. An
    /// observation dated before the first recorded start belongs to no cycle and is left out.
    /// Nothing is copied into the cycle: the observations stay in their own records.
    public static func group<Observation>(
        _ observations: [Observation],
        by cycles: [DerivedCycle],
        date: (Observation) -> CalendarDate
    ) -> [CalendarDate: [Observation]] {
        var groups: [CalendarDate: [Observation]] = [:]
        for observation in observations {
            guard let cycle = cycle(containing: date(observation), in: cycles) else { continue }
            groups[cycle.start, default: []].append(observation)
        }
        return groups
    }
}
