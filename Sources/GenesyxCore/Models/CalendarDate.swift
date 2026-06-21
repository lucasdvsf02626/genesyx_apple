import Foundation

/// A timezone-free calendar date (year-month-day), mirroring Java's `java.time.LocalDate`
/// used by the Android cycle engine. Backed by a proleptic-Gregorian day number so day
/// arithmetic, weekday, and month length are exact and deterministic — no `TimeZone`/DST
/// pitfalls, matching the web app's "local, no UTC" helpers.
public struct CalendarDate: Hashable, Comparable, Codable, Sendable {

    /// Days since 1970-01-01 (proleptic Gregorian). Internal source of truth.
    public let dayNumber: Int

    public init(dayNumber: Int) {
        self.dayNumber = dayNumber
    }

    public init(_ year: Int, _ month: Int, _ day: Int) {
        self.dayNumber = CalendarDate.daysFromCivil(year, month, day)
    }

    public var year: Int { CalendarDate.civilFromDays(dayNumber).year }
    public var month: Int { CalendarDate.civilFromDays(dayNumber).month }
    public var day: Int { CalendarDate.civilFromDays(dayNumber).day }

    /// Day of week with Sunday == 0 ... Saturday == 6 (used for the Sunday-first month grid).
    public var weekdaySundayZero: Int { ((dayNumber % 7) + 4).mod(7) }

    public func plusDays(_ n: Int) -> CalendarDate { CalendarDate(dayNumber: dayNumber + n) }
    public func minusDays(_ n: Int) -> CalendarDate { CalendarDate(dayNumber: dayNumber - n) }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        lhs.dayNumber < rhs.dayNumber
    }

    /// The current local date.
    public static func today(_ calendar: Calendar = .current, now: Date = Date()) -> CalendarDate {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return CalendarDate(c.year!, c.month!, c.day!)
    }

    // MARK: - Howard Hinnant's days-from-civil algorithm (exact integer day math)

    static func daysFromCivil(_ y0: Int, _ m: Int, _ d: Int) -> Int {
        let y = (m <= 2) ? y0 - 1 : y0
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }

    static func civilFromDays(_ z0: Int) -> (year: Int, month: Int, day: Int) {
        let z = z0 + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp + (mp < 10 ? 3 : -9)
        return (m <= 2 ? y + 1 : y, m, d)
    }
}

/// A year + month, mirroring `java.time.YearMonth` for the calendar grid.
public struct YearMonth: Hashable, Sendable {
    public let year: Int
    public let month: Int

    public init(_ year: Int, _ month: Int) {
        self.year = year
        self.month = month
    }

    public func atDay(_ day: Int) -> CalendarDate { CalendarDate(year, month, day) }

    public var lengthOfMonth: Int {
        let isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
        switch month {
        case 2: return isLeap ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }
}

extension Int {
    /// Floored modulo (always non-negative for a positive modulus), matching Kotlin's `mod`.
    func mod(_ n: Int) -> Int { ((self % n) + n) % n }
}
