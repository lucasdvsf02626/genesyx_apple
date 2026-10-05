import Foundation

// Your Diet Plan in one value: the content and the facts, put together for a screen. Pure and
// synchronous. The app passes the logs it already holds, the programme state and today's date,
// and reads the result. Whether she has access to the Diet Plan, and whether her consent is in
// force, are decided by the app before it calls this.

/// The facts for the three ranges the Diet Plan shows.
public struct DietPlanHistory: Hashable, Sendable {
    /// The current programme week. `nil` when today is not a programme day.
    public let programmeWeek: DietPlanHistoryFacts?
    /// Today and the six days before it.
    public let last7Days: DietPlanHistoryFacts
    /// Today and the twenty-seven days before it.
    public let last28Days: DietPlanHistoryFacts
}

public struct DietPlan: Hashable, Sendable {
    /// What is recorded in the food group tracker today.
    public let today: DietPlanDayFacts
    /// The current programme week's nutrition focus. `nil` when today is not a programme day: not
    /// started, before the start, after day 90, or stopped.
    public let weekFocus: DietPlanWeekFocus?
    /// One entry per food group, in the tracker's order.
    public let foodGuide: [DietPlanFoodGuideEntry]
    public let allergyNote: String
    /// One card per existing recipe.
    public let mealInspiration: [DietPlanMealCard]
    public let history: DietPlanHistory
    /// The line the food group tracker already shows: a record, not a target. Read from
    /// `FoodLogCopy.footnote` so the Diet Plan repeats it and never rewrites it.
    public let recordNote: String

    public static func assemble(
        logsByDate: [CalendarDate: DailyLog],
        state: ProgrammeState,
        today: CalendarDate,
        programme: ProgrammeContent = .draft,
        content: DietPlanContent = .draft
    ) -> DietPlan {
        var week: Int?
        if case .active(_, let current, _) = ProgrammeCalendar.position(state, on: today) { week = current }

        return DietPlan(
            today: DietPlanFacts.day(logsByDate[today]),
            weekFocus: week.flatMap { content.weekFocus(forWeek: $0, programme: programme) },
            foodGuide: content.foodGuide,
            allergyNote: content.allergyNote,
            mealInspiration: content.mealCards,
            history: DietPlanHistory(
                programmeWeek: week.flatMap {
                    DietPlanFacts.programmeWeek($0, state: state, today: today, logsByDate: logsByDate)
                },
                last7Days: DietPlanFacts.trailing(days: 7, endingOn: today, logsByDate: logsByDate),
                last28Days: DietPlanFacts.trailing(days: 28, endingOn: today, logsByDate: logsByDate)),
            recordNote: FoodLogCopy.footnote)
    }
}
