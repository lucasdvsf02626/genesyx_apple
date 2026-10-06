import Foundation

/// Every string My Fertility Picture writes itself (British English), and every existing string it
/// borrows, in one list so the banned-phrase guard can read all of it.
///
/// The picture reports what was recorded and what is estimated, and keeps the two apart. It never
/// says what a reading or a result means, it sets no target, and it has no wording at all for
/// ovulation having happened.
///
/// Every string written here is DRAFT, pending editorial and clinical review.
public enum FertilityPictureCopy {

    public static let title = "My Fertility Picture"

    // ── Sections ──

    public static let currentCycleTitle = "Current cycle"
    public static let testingTitle = "Testing"
    public static let everydayHealthTitle = "Everyday health"
    public static let programmeTitle = "Programme"
    public static let patternsTitle = "Patterns"

    // ── Current cycle ──

    public static let estimatedCycleDay = "Estimated cycle day"
    public static let estimatedPhase = "Estimated phase"
    public static let estimatedFertileWindow = "Estimated fertile window"
    public static let recordedCycleDay = "Recorded cycle day"
    /// Shown with the estimated rows, so a predicted day is not read as one she recorded.
    public static let estimateNote = "Estimated from your cycle settings. An estimate is not a record."

    // ── Testing ──

    public static let latestLhResult = "Latest ovulation test"
    public static let latestPhReading = "Latest pH reading"
    public static let phReadingsRecent = "pH readings in the last 30 days"

    /// A reading as it was logged, to one decimal place.
    public static func phValue(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    // ── Everyday health ──

    public static let lastSleep = "Last recorded sleep"
    public static let waterToday = "Water today"
    public static let foodGroups = "Food groups"
    public static let latestMood = "Latest mood"
    public static let latestEnergy = "Latest energy"
    public static let symptomsToday = "Symptoms recorded today"

    public static func energyLabel(_ level: EnergyLevel) -> String {
        switch level {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        }
    }

    // ── Programme ──

    public static let programmeDay = "Programme day"
    public static let programmeCompleted = "90-Day Programme completed"
    public static let today = "Today"
    public static let thisProgrammeWeek = "This programme week"
    public static let programmeConsistency = "Programme consistency"

    public static func dayOfProgramme(_ day: Int) -> String {
        "Day \(day) of \(ProgrammeCalendar.totalDays)"
    }

    /// Today's counts. A week's and the programme's are worded by `ProgrammeReviewCopy`, which
    /// states the same figures in the reviews; this builds on its line so the two cannot differ.
    public static func activitiesCompletedToday(_ completed: Int, of total: Int) -> String {
        ProgrammeReviewCopy.activitiesCompleted(completed, of: total) + " today"
    }

    // ── Patterns: counts and lengths only, stated without comment ──

    public static func lastCycleLength(_ length: Int) -> String {
        "Your last recorded cycle was \(days(length)) long."
    }

    public static func recordedDaysThisWeek(_ recorded: Int) -> String {
        "In the last \(ProgrammeCalendar.daysPerWeek) days you recorded something on \(days(recorded))."
    }

    public static func recordedDaysInCycle(_ recorded: Int, of elapsed: Int) -> String {
        "In your current recorded cycle you have recorded something on \(recorded) of \(days(elapsed))."
    }

    public static func lhResultsInCycle(_ count: Int) -> String {
        "In your current recorded cycle you have recorded \(count) ovulation test \(count == 1 ? "result" : "results")."
    }

    public static func phReadingsInCycle(_ count: Int) -> String {
        "In your current recorded cycle you have recorded \(count) pH \(count == 1 ? "reading" : "readings")."
    }

    /// `bounds` is given when she has also recorded a cycle outside the lengths that are counted.
    /// The sentence then names the cycles it is about, and does not speak for the one left out.
    public static func cycleLengthRange(cycles: Int, shortest: Int, longest: Int, ofLength bounds: ClosedRange<Int>? = nil) -> String {
        "Across your \(recordedCycles(cycles, ofLength: bounds)), cycle length ranged from \(shortest) to \(days(longest))."
    }

    /// `bounds` as for `cycleLengthRange`.
    public static func cycleLengthsEqual(cycles: Int, length: Int, ofLength bounds: ClosedRange<Int>? = nil) -> String {
        "Your \(recordedCycles(cycles, ofLength: bounds)) were each \(days(length)) long."
    }

    private static func recordedCycles(_ count: Int, ofLength bounds: ClosedRange<Int>?) -> String {
        "\(count) recorded cycles" + (bounds.map { " of \($0.lowerBound) to \(days($0.upperBound))" } ?? "")
    }

    private static func days(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }

    // ── Guarded registry ──

    /// The ovulation test results the picture can name. An unreadable test is never saved.
    static let shownLhClassifications = LhClassification.allCases.filter { $0 != .unreadable }

    /// Every string above, each function with a singular and a plural sample, followed by the
    /// existing strings the picture shows unchanged. A new constant belongs in this list in the
    /// same change that adds it.
    public static let allSurfaces: [String] = [
        title,
        currentCycleTitle, testingTitle, everydayHealthTitle, programmeTitle, patternsTitle,
        estimatedCycleDay, estimatedPhase, estimatedFertileWindow, recordedCycleDay, estimateNote,
        latestLhResult, latestPhReading, phReadingsRecent, phValue(4.5),
        lastSleep, waterToday, foodGroups, latestMood, latestEnergy, symptomsToday,
        programmeDay, programmeCompleted, today, thisProgrammeWeek, programmeConsistency,
        dayOfProgramme(1), dayOfProgramme(23),
        activitiesCompletedToday(1, of: 1), activitiesCompletedToday(2, of: 5),
        lastCycleLength(1), lastCycleLength(29),
        recordedDaysThisWeek(1), recordedDaysThisWeek(5),
        recordedDaysInCycle(1, of: 1), recordedDaysInCycle(12, of: 18),
        lhResultsInCycle(1), lhResultsInCycle(3),
        phReadingsInCycle(1), phReadingsInCycle(4),
        cycleLengthRange(cycles: 3, shortest: 27, longest: 30),
        cycleLengthRange(cycles: 3, shortest: 28, longest: 29, ofLength: CycleEngine.cycleLengthRange),
        cycleLengthsEqual(cycles: 3, length: 28),
        cycleLengthsEqual(cycles: 3, length: 28, ofLength: CycleEngine.cycleLengthRange),
        // Borrowed unchanged from the screens that own them.
        HcgScanCopy.cardTitle, HcgScanCopy.showHistory,
        LhScanCopy.resultNote, LhScanCopy.cycleDayLabel(1),
        // A consistency figure, in the words the Programme Reviews state it in.
        ProgrammeReviewCopy.percentage(79),
        ProgrammeReviewCopy.activitiesCompleted(1, of: 1), ProgrammeReviewCopy.activitiesCompleted(29, of: 37),
        ProgrammeReviewCopy.activitiesCompleted(29, of: 37, partlyCompleted: 1),
        ProgrammeReviewCopy.activitiesCompleted(0, of: 37, partlyCompleted: 3),
    ]
        + EnergyLevel.allCases.map(energyLabel)
        + shownLhClassifications.map(LhScanCopy.title(for:))
        + Phase.allCases.compactMap { CycleContent.phaseLabel[$0] }
        + PhStatus.allCases.map(\.label)
        + Mood.allCases.map(\.label)
        + (1...NutritionDaySignal.foodGroupCount).compactMap { NutritionDaySignal.summaryLine(supplements: 0, foodGroups: $0) }
        + ProgrammeEvidenceCopy.allSurfaces
}
