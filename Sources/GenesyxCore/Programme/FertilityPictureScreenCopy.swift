import Foundation

/// DRAFT WORDING: pending editorial review.
///
/// The words My Fertility Picture adds around what core already wrote. The rows, section titles
/// and notes are core's (`FertilityPictureCopy`); this holds the screen's own two sentences and
/// the way a row's parts become the lines of one row.
public enum FertilityPictureScreenCopy {

    public static let intro = "A summary of what you have recorded. It reflects your own records and is not medical advice."
    public static let empty = "Nothing to show yet. Your picture fills in as you record."

    /// The lines of one row, in reading order: its label, value and detail, then the day or days
    /// the record is from. A part the row does not have is left out.
    public static func rowLines(for row: FertilityPictureRow) -> [String] {
        var lines = [row.label]
        lines += [row.value, row.detail].compactMap { $0 }
        if let range = row.dateRange {
            lines.append(FertilityKitCopy.dateRange(dayMonth(range.lowerBound), dayMonth(range.upperBound)))
        } else if let date = row.date {
            lines.append(dayMonth(date))
        }
        return lines
    }

    private static func dayMonth(_ date: CalendarDate) -> String {
        FertilityKitCopy.dayMonth(day: date.day, month: date.month)
    }

    /// Every string, for the copy guard.
    public static var allSurfaces: [String] { [intro, empty] }
}
