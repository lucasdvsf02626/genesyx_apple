import Foundation

/// DRAFT WORDING: pending editorial review.
///
/// Every sentence the Weekly Programme Review and the 90-Day Review can show. The logic and the
/// models hold no wording of their own, so a sentence is covered by the guard tests once it is in
/// `allSurfaces`. A count or a percentage is stated as it is: no word here calls a figure high or
/// low, and nothing is said about a food group, a test value or a result.
public enum ProgrammeReviewCopy {

    // MARK: Section titles

    public static let consistencyTitle = "Programme consistency"
    public static let trackedTitle = "What you tracked"
    public static let noticedTitle = "What we noticed"
    public static let strongestRoutineTitle = "Your strongest routine"
    public static let nextFocusTitle = "Next week's focus"

    public static let ninetyDayTitle = "Your 90-Day Review"
    public static let programmePeriodTitle = "Programme period"
    public static let hydrationTitle = "Hydration consistency"
    public static let sleepTitle = "Sleep tracking"
    public static let bodyCheckInsTitle = "Body check-ins"
    public static let strongestRoutinesTitle = "Your strongest routines"
    public static let patternsTitle = "Patterns"
    public static let whatToContinueTitle = "What to continue"

    // MARK: Consistency

    public static func weekComplete(_ week: Int) -> String { "Week \(week) complete" }

    public static func percentage(_ value: Int) -> String { "\(value)%" }

    /// The counts a percentage came from. Shown after every percentage, and alone when there is none.
    /// When nothing was completed in full, only the partly completed count is stated.
    public static func activitiesCompleted(_ completed: Int, of counted: Int, partlyCompleted: Int = 0) -> String {
        let activities = " of \(counted) " + plural(counted, "activity", "activities")
        if completed == 0, partlyCompleted > 0 { return "\(partlyCompleted)" + activities + " partly completed" }
        let line = "\(completed)" + activities + " completed"
        return partlyCompleted > 0 ? line + ", \(partlyCompleted) partly completed" : line
    }

    /// A figure's lines run together, for a routine that has one line to itself.
    public static func onOneLine(_ lines: [String]) -> String { lines.joined(separator: ", ") }

    /// A fully missed period: activities were counted, none was recorded, and nothing else was
    /// tracked either. Never shown beside a list of what was tracked.
    public static let nothingRecorded = "No Programme activities recorded."
    /// Beside `nothingRecorded` in a weekly review.
    public static let welcomeBack = "Welcome back. Continue with today."
    /// Beside `nothingRecorded` in the 90-day review.
    public static let pickUpYourRoutine = "Pick up your routine whenever you are ready."

    // MARK: What you tracked

    /// One count. `days` is the number of days in the period and is read by `daysRecorded` only.
    public static func tracked(_ kind: ProgrammeReviewCount.Kind, _ count: Int, ofDays days: Int) -> String {
        let onDays = "on \(count) " + plural(count, "day", "days")
        switch kind {
        case .daysRecorded: return "Something recorded on \(count) of \(days) days"
        case .nutritionCheckIns: return "Nutrition check-in " + onDays
        case .waterDays: return "Water recorded " + onDays
        case .waterGoalDays: return "Water goal reached " + onDays
        case .sleepNights: return "Sleep recorded for \(count) " + plural(count, "night", "nights")
        case .moodCheckIns: return "Mood recorded " + onDays
        case .energyCheckIns: return "Energy recorded " + onDays
        case .symptomDays: return "Symptoms recorded " + onDays
        case .periodStarts: return "\(count) period " + plural(count, "start", "starts") + " recorded"
        case .phReadings: return "\(count) pH " + plural(count, "reading", "readings") + " recorded"
        case .lhResults: return "\(count) ovulation test " + plural(count, "result", "results") + " recorded"
        case .lessonsRead: return "\(count) programme " + plural(count, "lesson", "lessons") + " read"
        }
    }

    // MARK: What we noticed

    public static let recordedEveryDay = "You recorded something on every day of the week."

    public static func waterGoalMostDays(_ days: Int) -> String {
        "You reached your water goal on \(days) " + plural(days, "day", "days") + "."
    }

    /// Two numbers side by side. Neither is called more or less.
    public static func recordedDaysCompared(thisWeek: Int, weekBefore: Int) -> String {
        "You recorded something on \(thisWeek) " + plural(thisWeek, "day", "days")
            + " this week and \(weekBefore) the week before."
    }

    /// Two percentages side by side. Neither is called more or less.
    public static func consistencyCompared(thisWeek: Int, weekBefore: Int) -> String {
        "Your programme consistency was \(thisWeek)% this week and \(weekBefore)% the week before."
    }

    // MARK: Routines

    /// The name an activity goes by in a review. `nil` for the pregnancy-test guidance, which is
    /// reading matter and never a routine.
    public static func routineName(for category: ProgrammeTaskCategory) -> String? {
        switch category {
        case .moodCheckIn: return "Mood check-in"
        case .energyCheckIn: return "Energy check-in"
        case .sleepCheckIn: return "Sleep check-in"
        case .hydrationCheckIn: return "Hydration check-in"
        case .supplementCheckIn: return "Supplement check-in"
        case .symptomCheckIn: return "Symptom check-in"
        case .nutritionCheckIn: return "Nutrition check-in"
        case .cycleCheckIn: return "Cycle check-in"
        case .periodLog: return "Period log"
        case .lhTest: return "Ovulation test"
        case .phTest: return "pH test"
        case .programmeLesson: return "Programme lesson"
        case .weeklyReview: return "Weekly review"
        case .fertilityKitEducation: return "Fertility Kit guide"
        case .pregnancyTestRelatedAction: return nil
        }
    }

    // MARK: What to continue

    /// One line for a routine worth carrying on with. The name is put in sentence case, except the
    /// kit's own name.
    public static func continueWith(_ category: ProgrammeTaskCategory) -> String? {
        guard let name = routineName(for: category) else { return nil }
        let inSentence = category == .fertilityKitEducation ? name : name.prefix(1).lowercased() + name.dropFirst()
        return "Continue with your " + inSentence + "."
    }

    /// The last line of the 90-day review, always shown.
    public static let continueClosing = "Everything in your Fertility Kit stays available. Continue with today."

    // MARK: Guarded registry

    /// Every constant above, and every function evaluated with sample values in the singular and
    /// the plural. The guard tests scan this list, so a sentence added to this file has to be added
    /// here to be covered.
    public static let allSurfaces: [String] =
        [consistencyTitle, trackedTitle, noticedTitle, strongestRoutineTitle, nextFocusTitle,
         ninetyDayTitle, programmePeriodTitle, hydrationTitle, sleepTitle, bodyCheckInsTitle,
         strongestRoutinesTitle, patternsTitle, whatToContinueTitle,
         nothingRecorded, welcomeBack, pickUpYourRoutine, recordedEveryDay, continueClosing]
        + [weekComplete(3), percentage(79),
           activitiesCompleted(1, of: 1), activitiesCompleted(29, of: 37),
           activitiesCompleted(29, of: 37, partlyCompleted: 1), activitiesCompleted(0, of: 37, partlyCompleted: 3),
           activitiesCompleted(0, of: 1, partlyCompleted: 1),
           onOneLine([percentage(79), activitiesCompleted(29, of: 37)]),
           onOneLine([percentage(79), activitiesCompleted(29, of: 37, partlyCompleted: 1)]),
           onOneLine([percentage(4), activitiesCompleted(0, of: 37, partlyCompleted: 3)])]
        + ProgrammeReviewCount.Kind.allCases.flatMap { [tracked($0, 1, ofDays: 7), tracked($0, 5, ofDays: 7)] }
        + [waterGoalMostDays(1), waterGoalMostDays(4),
           recordedDaysCompared(thisWeek: 1, weekBefore: 3), recordedDaysCompared(thisWeek: 5, weekBefore: 3),
           consistencyCompared(thisWeek: 79, weekBefore: 71)]
        + ProgrammeTaskCategory.allCases.compactMap(routineName(for:))
        + ProgrammeTaskCategory.allCases.compactMap(continueWith)

    private static func plural(_ count: Int, _ one: String, _ many: String) -> String {
        count == 1 ? one : many
    }
}
