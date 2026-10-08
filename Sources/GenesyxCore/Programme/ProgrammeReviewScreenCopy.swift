import Foundation

/// DRAFT WORDING: pending editorial review.
///
/// What the Programme Reviews list and the two review screens say themselves. The reviews' own
/// sentences and section titles are in `ProgrammeReviewCopy`; this holds the rest: the list's
/// headings, when the next review is ready, and what is shown when there is no review to show.
/// A date is passed in already put into words.
public enum ProgrammeReviewScreenCopy {

    // MARK: The consistency card

    public static let consistencySoFar = "Programme so far"
    public static let lastThirtyDays = "Last 30 days"
    public static let byActivity = "By activity"

    // MARK: The list of reviews

    public static let weeklyHeading = "Weekly reviews"

    public static func weekRow(_ week: Int) -> String { "Week \(week)" }

    public static let noReviewsYet = "Your first weekly review will be ready after your first programme week."

    public static func nextReviewReady(_ week: Int, _ date: String) -> String {
        "Your Week \(week) review will be ready on \(date)."
    }

    public static func nextReviewReadyTomorrow(_ week: Int) -> String {
        "Your Week \(week) review will be ready tomorrow."
    }

    public static func ninetyDayReady(_ date: String) -> String {
        "Your 90-Day Review will be ready on \(date)."
    }

    // MARK: Nothing to show

    public static let notStarted = "Reviews begin once your programme has started."
    public static let notAvailable = "This review is not available yet."

    // MARK: Links

    public static let openPicture = "Open My Fertility Picture"

    // MARK: Registry

    /// Every constant, and a sample of every function.
    public static var allSurfaces: [String] {
        [consistencySoFar, lastThirtyDays, byActivity, weeklyHeading, noReviewsYet, notStarted, notAvailable,
         openPicture, weekRow(1), weekRow(13),
         nextReviewReady(3, "20 October"), nextReviewReadyTomorrow(3), ninetyDayReady("4 January")]
    }
}
