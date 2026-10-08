import Foundation

/// The words of the Your Diet Plan screen and its meal sheet. Everything else it prints comes from
/// the Diet Plan content, the shared kit registry or the recipes themselves. The file name does not
/// start with `DietPlan`: `DietPlanGuardTests` pins that prefix to four files.
public enum YourDietPlanScreenCopy {

    // MARK: Section titles

    public static let todayTitle = "Today's nutrition"
    public static let focusTitle = "This week's nutrition focus"
    public static let foodGuideTitle = "Food guide"
    public static let mealsTitle = "Meal inspiration"
    public static let historyTitle = "Your nutrition history"
    public static let connectionTitle = "Programme connection"

    // MARK: Today

    public static let todayEmpty = "No food groups recorded today."
    public static let track = "Record today's food groups"

    // MARK: Meals

    /// "Contains: Vegetables, Protein".
    public static func mealContains(_ groups: [String]) -> String {
        "Contains: \(groupList(groups))"
    }

    /// Names joined for reading: "Vegetables, Fruit". Joining happens here, never in a view.
    public static func groupList(_ names: [String]) -> String {
        names.joined(separator: ", ")
    }

    public static let swapNote = "Recipes are a starting point. Swap anything that does not suit you."

    // MARK: History

    public static let rangeProgrammeWeek = "This programme week"
    public static let rangeLast7 = "Last 7 days"
    public static let rangeLast28 = "Last 28 days"
    public static let historyEmpty = "Nothing recorded in this period."

    /// "Nutrition check-in on 4 of 7 days".
    public static func checkInDays(_ days: Int, of elapsed: Int) -> String {
        "Nutrition check-in on \(days) of \(elapsed) days"
    }

    /// "Vegetables recorded on 3 days" or "Fruit recorded on 1 day".
    public static func groupDays(_ label: String, _ days: Int) -> String {
        "\(label) recorded on \(days) \(days == 1 ? "day" : "days")"
    }

    // MARK: Programme connection

    public static func connectionWeek(_ week: Int) -> String {
        "You are in week \(week) of your 90-Day Programme."
    }

    public static let connectionBody =
        "The nutrition check-in is part of Today's Programme. It notes that you checked in, never what you ate."
    public static let openToday = "Open Today's Programme"
    public static let connectionNotRunning =
        "Your Diet Plan is yours to use at any time, with or without the programme."

    public static var allSurfaces: [String] {
        [todayTitle, focusTitle, foodGuideTitle, mealsTitle, historyTitle, connectionTitle,
         todayEmpty, track, mealContains(["Vegetables", "Protein"]), groupList(["Vegetables", "Fruit"]), swapNote,
         rangeProgrammeWeek, rangeLast7, rangeLast28, historyEmpty,
         checkInDays(4, of: 7), groupDays("Vegetables", 3), groupDays("Fruit", 1),
         connectionWeek(4), connectionBody, openToday, connectionNotRunning]
    }
}
