import Foundation

/// Where a period record came from. `seeded` is the single record copied from her cycle settings
/// when history first switches on; everything she enters afterwards is `recorded`.
///
/// Raw values are stored locally and on the server: never rename a case.
public enum PeriodSource: String, Codable, Sendable, CaseIterable {
    case recorded, seeded
}

/// One period she told the app about: the day it started and, if she said so, its last day.
/// This is the only stored fact in cycle history. Cycles and their lengths are always derived
/// from these records (`CycleHistory.cycles`), so they can never disagree with the dates.
///
/// The start date is the record's identity. Two devices that both record the same start while
/// offline therefore describe one record and merge by themselves.
public struct PeriodRecord: Identifiable, Hashable, Sendable {
    public let startDate: CalendarDate
    /// The last day of the period, inclusive. Nil until she records one.
    public let endDate: CalendarDate?
    public let source: PeriodSource

    public var id: CalendarDate { startDate }

    public init(startDate: CalendarDate, endDate: CalendarDate? = nil, source: PeriodSource = .recorded) {
        self.startDate = startDate
        self.endDate = endDate
        self.source = source
    }
}
