import Foundation
import GenesyxCore

/// Foundation bridges for the UI-free `CalendarDate` — ISO string keys for persistence and
/// `Date` conversion for SwiftUI `DatePicker`.
extension CalendarDate {

    /// `yyyy-MM-dd`, used as a stable storage key.
    var iso: String { String(format: "%04d-%02d-%02d", year, month, day) }

    init?(iso: String) {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(parts[0], parts[1], parts[2])
    }

    /// Build from a `Date` using the given calendar (local by default).
    init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    /// Convert to a `Date` (anchored at noon to avoid DST edge cases) for pickers/formatting.
    func toDate(calendar: Calendar = .current) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = 12
        return calendar.date(from: c) ?? Date()
    }
}
