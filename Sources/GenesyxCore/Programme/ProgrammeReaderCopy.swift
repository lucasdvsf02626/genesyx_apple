import Foundation

/// DRAFT WORDING: pending editorial review.
///
/// The words around the day reader and the Programme Guide: section headings, the day buttons and
/// the label of each day's main button. The day's own title, lesson and reflection, and the
/// guide's sections, are written elsewhere and printed as they are.
public enum ProgrammeReaderCopy {

    // MARK: Sections of a day

    public static let todaysFocus = "Today's focus"
    public static let whyThisMatters = "Why this matters"
    public static let todaysActions = "Today's actions"
    public static let learnMore = "Learn more"
    public static let yourProgress = "Your progress"
    public static let optionalReflection = "Optional reflection"

    // MARK: Moving between days

    public static let previousDay = "Previous day"
    public static let nextDay = "Next day"

    // MARK: Buttons to the daily log

    public static let openTodaysLog = "Open today's log"
    public static let openThisDaysLog = "Open this day's log"

    // MARK: States and the guide

    public static let notStarted = "Your programme has not started yet."
    public static let guideIntro = "Thirty short sections. Read them in any order."
    public static let relatedHeading = "Related reading"

    /// The label of a day's main button. `nil` for the lesson itself: she is already reading it.
    public static func callToActionLabel(for destination: ProgrammeDestination) -> String? {
        switch destination {
        case .cycle: return "Open your calendar"
        case .dailyLog: return openTodaysLog
        case .hydration: return "Track today's water"
        case .nutrition: return "Open Your Diet Plan"
        case .insights: return "See your insights"
        case .weeklyReview: return "Open your Programme Reviews"
        case .programmeProgress: return "See your programme progress"
        case .lhTest: return "Open ovulation tests"
        case .phTest: return "Open the pH tracker"
        case .fertilityKitGuide: return "Open the Programme Guide"
        case .programmeLesson: return nil
        }
    }

    /// Every constant, and every destination's label.
    public static var allSurfaces: [String] {
        [todaysFocus, whyThisMatters, todaysActions, learnMore, yourProgress, optionalReflection,
         previousDay, nextDay, openTodaysLog, openThisDaysLog, notStarted, guideIntro, relatedHeading]
            + ProgrammeDestination.allCases.compactMap(callToActionLabel(for:))
    }
}
