import Foundation

/// DRAFT WORDING: pending editorial review.
///
/// Every word of the cycle history screen and its period sheet. Facts about what she recorded, in
/// plain sentences: no judgement of a length, no remark about a period that is expected or late.
/// The labels `setEnd`, `changeEnd`, `correctStart`, `deletePeriod` and `deleteTitle` are found
/// by the journeys by their text (a menu item and an alert carry no identifier): they are not
/// reworded without the QA agent.
public enum CycleHistoryScreenCopy {

    // MARK: The screen

    public static let intro = "Your cycle history starts from the first period you record here. Nothing is filled in from before."
    public static let emptyState = intro
    public static let addStart = "Add a period start"
    public static let currentCycle = "Current cycle"
    public static let fromSettings = "From your cycle settings"
    public static let rowActions = "Period actions"
    public static let notSaved = "This period is saved on this phone only. Check its date, then correct or delete it."
    public static let predictionsNote = "Predictions use your latest period start."

    public static func started(_ dateText: String) -> String { "Started \(dateText)" }

    public static func length(_ days: Int) -> String { days == 1 ? "1 day" : "\(days) days" }

    public static func periodDays(_ days: Int) -> String { days == 1 ? "Period: 1 day" : "Period: \(days) days" }

    // MARK: The row menu (FROZEN: found by label)

    public static let setEnd = "Set period end"
    public static let changeEnd = "Change period end"
    public static let correctStart = "Correct start date"
    public static let deletePeriod = "Delete this period"

    // MARK: Deleting

    public static let deleteTitle = "Delete this period?"
    public static let deleteBody = "This removes the record from your history."
    public static let deleteLatestBody = "This is your latest period start. Your cycle predictions will use the start before it."
    public static let deleted = "Period deleted."

    // MARK: The sheet

    public static let dateLabel = "Date"
    public static let clearEnd = "Clear period end"

    public static func correctionNote(_ existingStartText: String) -> String {
        "This date is within \(CycleHistoryRules.correctionWindowDays) days of the start on \(existingStartText), so that start will move to this date."
    }

    public static func correctRange(_ days: Int) -> String {
        "You can move this start by up to \(days) days. To move it further, delete it and add a new one."
    }

    // MARK: What a save did

    public static let startAdded = "Period start added."
    public static let earlierStartAdded = "Earlier period start added."
    public static let startAlreadyRecorded = "That start date is already recorded."
    public static let startRefused = "That date cannot be recorded as a period start."

    public static func startMoved(from: CalendarDate, to: CalendarDate) -> String {
        "Start date moved from \(dayMonth(from)) to \(dayMonth(to))."
    }

    public static func sentence(for outcome: PeriodStartOutcome) -> String {
        switch outcome {
        case .append: return startAdded
        case .backFill: return earlierStartAdded
        case .correction(let from, let to): return startMoved(from: from, to: to)
        case .noChange: return startAlreadyRecorded
        case .refused: return startRefused
        }
    }

    public static let endSaved = "Period end saved."
    public static let endCleared = "Period end cleared."
    public static let endNoChange = "Nothing changed."
    public static let endUnknownStart = "That period could not be found."
    public static let endBeforeStart = "The end date cannot be before the start date."
    public static let endReachesNextStart = "The end date cannot reach the period start recorded after it."
    public static let endInFuture = "The end date cannot be in the future."

    public static func tooLong(_ days: Int) -> String { "A period can be recorded for up to \(days) days." }

    public static func sentence(for outcome: PeriodEndOutcome) -> String {
        switch outcome {
        case .updated: return endSaved
        case .noChange: return endNoChange
        case .refusedUnknownStart: return endUnknownStart
        case .refusedBeforeStart: return endBeforeStart
        case .refusedTooLong: return tooLong(CycleEngine.periodLengthRange.upperBound)
        case .refusedReachesNextStart: return endReachesNextStart
        case .refusedFuture: return endInFuture
        }
    }

    private static func dayMonth(_ date: CalendarDate) -> String {
        FertilityKitCopy.dayMonth(day: date.day, month: date.month)
    }

    // MARK: For the guard

    /// Every string, and one sample of every function, for the copy guard.
    public static var allSurfaces: [String] {
        let first = CalendarDate(2026, 9, 28)
        let second = CalendarDate(2026, 10, 6)
        let starts: [PeriodStartOutcome] = [.append(second), .backFill(first), .correction(from: first, to: second),
                                            .noChange, .refused]
        let ends: [PeriodEndOutcome] = [.updated, .noChange, .refusedUnknownStart, .refusedBeforeStart, .refusedTooLong,
                                        .refusedReachesNextStart, .refusedFuture]
        return [intro, emptyState, addStart, currentCycle, fromSettings, rowActions, notSaved, predictionsNote,
                started("6 October"), length(29), length(1), periodDays(5), periodDays(1),
                setEnd, changeEnd, correctStart, deletePeriod,
                deleteTitle, deleteBody, deleteLatestBody, deleted, dateLabel, clearEnd,
                correctionNote("28 September"), correctRange(CycleHistoryRules.correctionWindowDays),
                startAdded, earlierStartAdded, startAlreadyRecorded, startRefused, startMoved(from: first, to: second),
                endSaved, endCleared, endNoChange, endUnknownStart, endBeforeStart, endReachesNextStart, endInFuture,
                tooLong(CycleEngine.periodLengthRange.upperBound)]
            + starts.map(sentence(for:)) + ends.map(sentence(for:))
    }
}
