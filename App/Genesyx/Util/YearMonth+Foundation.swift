import Foundation
import GenesyxCore

extension YearMonth {

    static var current: YearMonth {
        let t = CalendarDate.today()
        return YearMonth(t.year, t.month)
    }

    /// Returns this month offset by `months` (can be negative).
    func adding(months: Int) -> YearMonth {
        let total = year * 12 + (month - 1) + months
        return YearMonth(total / 12, total % 12 + 1)
    }

    /// "September 2026"
    var title: String { formatted("MMMM yyyy") }
    /// "Sep 2026"
    var shortTitle: String { formatted("MMM yyyy") }

    private func formatted(_ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        return formatter.string(from: atDay(1).toDate())
    }
}
