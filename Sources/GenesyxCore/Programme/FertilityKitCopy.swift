import Foundation

/// DRAFT WORDING: pending editorial review.
///
/// The words every Fertility Kit screen shares: product and screen names, the four access states,
/// statuses, the ways a label is put together, and dates in words. A string two screens need is
/// here, so no screen retypes another's wording. Everything is covered by the guard tests once it
/// is in `allSurfaces`.
public enum FertilityKitCopy {

    // MARK: Names

    public static let productName = "Genesyx Fertility Kit"
    public static let kitName = "Fertility Kit"
    public static let premium = "Premium"
    public static let programmeName = "90-Day Fertility Programme"
    public static let programmeShortName = "90-Day Programme"
    public static let yourProgramme = "Your Programme"
    public static let todaysProgramme = "Today's Programme"
    public static let programmeGuide = "Programme Guide"
    public static let dietPlan = "Your Diet Plan"
    public static let programmeReviews = "Programme Reviews"
    public static let weeklyReview = "Weekly Programme Review"
    public static let cycleHistory = "Cycle history"
    /// The More row is drawn only with access, so "Your" is true of whoever reads it.
    public static let moreRowDescription = "Your 90-Day Programme and Your Diet Plan"

    // MARK: The access states

    public static let noAccessDescription = "The Genesyx Fertility Kit adds the 90-Day Fertility Programme and Your Diet Plan to your app, with daily guidance, weekly reviews and a guide to everything in your kit. If you have a kit, activate it here."
    public static let activate = "Activate My Kit"
    public static let accessActive = "Premium access active"
    public static let includedHeading = "What is included"
    public static let includedProgramme = programmeName
    public static let includedDietPlan = dietPlan
    public static let includedReviews = programmeReviews
    public static let includedGuidance = "Fertility Kit Guidance"
    public static let includedTesting = "Testing Integration"

    /// What access includes. Testing is listed only where the scan screens exist.
    public static func includedItems(scanAvailable: Bool) -> [String] {
        [includedProgramme, includedDietPlan, includedReviews, includedGuidance] + (scanAvailable ? [includedTesting] : [])
    }

    public static let startProgramme = "Start My 90-Day Programme"
    public static let continueProgramme = "Continue Programme"
    public static let openKit = "Open Fertility Kit"
    public static let programmeCompleted = "90-Day Programme Completed"
    public static let viewNinetyDayReview = "View My 90-Day Review"
    public static let continueWithGenesyx = "Continue with Genesyx"

    // MARK: Position and reading time

    public static func weekOfProgramme(_ week: Int) -> String {
        "Week \(week) of \(ProgrammeCalendar.totalWeeks)"
    }

    public static func minutesToRead(_ minutes: Int) -> String {
        "\(minutes) min read"
    }

    // MARK: Nutrition, as a record

    public static let nutritionCheckInCompleted = "Nutrition check-in: completed"

    public static func foodGroupsRecorded(_ recorded: Int, of total: Int) -> String {
        "Food groups recorded: \(recorded) of \(total)"
    }

    // MARK: Statuses

    public static let statusDone = "Done"
    public static let statusPartDone = "Part done"
    public static let statusToDo = "To do"
    public static let statusOptional = "Optional"
    public static let statusNotRecorded = "Not recorded"

    // MARK: Labels put together

    /// The one label of a task row: the name, a comma, the status in lower case, then every
    /// detail line the row shows, so VoiceOver reads what a sighted user sees.
    public static func rowLabel(_ name: String, status: String, details: [String] = []) -> String {
        sentences(["\(name), \(status.lowercased())."] + details)
    }

    /// The label of a row with a title and a line under it: title, full stop, detail.
    public static func titleAndDetail(_ title: String, _ detail: String?) -> String {
        sentences([title] + (detail.map { [$0] } ?? []))
    }

    /// Several lines as one label. A full stop is added only between lines, and only where a
    /// line does not end with one.
    public static func sentences(_ lines: [String]) -> String {
        let last = lines.count - 1
        return lines.enumerated().map { index, line in
            index == last || line.hasSuffix(".") || line.hasSuffix("?") || line.hasSuffix("!") ? line : line + "."
        }.joined(separator: " ")
    }

    /// Parts joined with a middle dot, for eyebrows.
    public static func dotJoined(_ parts: [String]) -> String {
        parts.joined(separator: " · ")
    }

    // MARK: Today

    public static func partlyCompletedToday(_ count: Int) -> String {
        count == 1 ? "1 activity partly completed" : "\(count) activities partly completed"
    }

    public static let nothingCountedToday = "Nothing is counted today."

    /// Today in words: counts only, never a percentage. The home and the day reader both use
    /// this, so the two cannot differ.
    public static func todayProgressLines(_ progress: ProgrammeTodayProgress) -> [String] {
        guard progress.total > 0 else { return [nothingCountedToday] }
        return [FertilityPictureCopy.activitiesCompletedToday(progress.completed, of: progress.total)]
            + (progress.partlyCompleted > 0 ? [partlyCompletedToday(progress.partlyCompleted)] : [])
    }

    // MARK: Dates in words

    private static let monthNames = ["January", "February", "March", "April", "May", "June", "July", "August",
                                     "September", "October", "November", "December"]

    /// January to December for 1 to 12. Anything else is held to that range.
    public static func monthName(_ month: Int) -> String {
        monthNames[min(max(month, 1), 12) - 1]
    }

    /// Day, then month, always.
    public static func dayMonth(day: Int, month: Int) -> String {
        "\(day) \(monthName(month))"
    }

    public static func dayMonthYear(day: Int, month: Int, year: Int) -> String {
        "\(dayMonth(day: day, month: month)) \(year)"
    }

    public static func dateRange(_ first: String, _ last: String) -> String {
        "\(first) to \(last)"
    }

    // MARK: Buttons

    public static let done = "Done"
    public static let cancel = "Cancel"
    public static let save = "Save"
    public static let delete = "Delete"
    public static let back = "Back"
    public static let notNow = "Not now"
    public static let tryAgain = "Try again"

    // MARK: Registry

    /// Every constant, and one or two samples of every function.
    public static var allSurfaces: [String] {
        [productName, kitName, premium, programmeName, programmeShortName, yourProgramme, todaysProgramme,
         programmeGuide, dietPlan, programmeReviews, weeklyReview, cycleHistory, moreRowDescription,
         noAccessDescription, activate, accessActive, includedHeading,
         startProgramme, continueProgramme, openKit, programmeCompleted, viewNinetyDayReview, continueWithGenesyx,
         weekOfProgramme(1), weekOfProgramme(4), minutesToRead(3),
         nutritionCheckInCompleted, foodGroupsRecorded(4, of: 6),
         statusDone, statusPartDone, statusToDo, statusOptional, statusNotRecorded,
         rowLabel("Mood check-in", status: statusDone),
         rowLabel("Nutrition check-in", status: statusDone,
                  details: [nutritionCheckInCompleted, foodGroupsRecorded(4, of: 6)]),
         titleAndDetail(programmeGuide, moreRowDescription), titleAndDetail(dietPlan, nil),
         sentences([weekOfProgramme(4), partlyCompletedToday(1)]),
         dotJoined([FertilityPictureCopy.dayOfProgramme(23), weekOfProgramme(4), minutesToRead(3)]),
         partlyCompletedToday(1), partlyCompletedToday(2), nothingCountedToday,
         dayMonth(day: 6, month: 10), dayMonthYear(day: 6, month: 10, year: 2026),
         dateRange(dayMonth(day: 6, month: 10), dayMonth(day: 12, month: 10)),
         done, cancel, save, delete, back, notNow, tryAgain]
            + includedItems(scanAvailable: true)
            + (1...12).map(monthName)
    }
}
