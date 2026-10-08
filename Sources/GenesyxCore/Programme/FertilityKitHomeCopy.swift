import Foundation

/// DRAFT WORDING: pending editorial review.
///
/// The words of the Fertility Kit home and its task list. Names and statuses shared with other
/// screens are in `FertilityKitCopy`; this holds only what these two screens say.
public enum FertilityKitHomeCopy {

    // MARK: Today's Programme

    public static let openToday = "Open today's lesson"
    public static let thisWeeksFocus = "This week's focus"
    public static let weeklyHeading = "This week"
    public static let weeklyToDo = "This week: to do"
    public static let weeklyDone = "This week: done"

    // MARK: The hub

    public static let exploreHeading = "In your Fertility Kit"
    public static let guideDetail = "Thirty short sections on your kit and your cycle"
    public static let dietPlanDetail = "Food groups, a weekly focus and meal ideas"
    public static let reviewsDetail = "Your consistency and weekly reviews"
    public static let pictureDetail = "What you have recorded, in one place"
    public static let cycleHistoryDetail = "Your recorded periods and cycles"
    public static let ninetyDayReviewDetail = "Your 90 days, from your own records"
    public static let programmeDays = "Programme days"
    public static let programmeDaysDetail = "Read any day again"
    public static let dailyLog = "Daily log"
    public static let dailyLogDetail = "Record today"

    // MARK: What each state says

    public static let notStartedBody = "Start your 90-Day Programme when you are ready. Everything else in your kit is available now."
    public static let scheduledBody = "Your Programme Guide, Your Diet Plan and My Fertility Picture are available now."
    public static let completedBody = "Your 90 days are complete. Everything in your Fertility Kit stays available to you."
    public static let stoppedBody = "Everything else in your Fertility Kit stays available."

    // MARK: Registry

    public static var allSurfaces: [String] {
        [openToday, thisWeeksFocus, weeklyHeading, weeklyToDo, weeklyDone, exploreHeading,
         guideDetail, dietPlanDetail, reviewsDetail, pictureDetail, cycleHistoryDetail, ninetyDayReviewDetail,
         programmeDays, programmeDaysDetail, dailyLog, dailyLogDetail,
         notStartedBody, scheduledBody, completedBody, stoppedBody]
    }
}
