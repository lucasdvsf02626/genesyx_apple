import Foundation

/// Stable identifiers for every notification the app can schedule.
enum NotificationKind: String, CaseIterable {
    case weeklyPh       = "genesyx.weekly.ph"
    case weeklyPhase    = "genesyx.weekly.phase"
    case weeklyNutrition = "genesyx.weekly.nutrition"
    case weeklyLearn    = "genesyx.weekly.learn"
    // Future hook: `weeklySupplements` slots in here without touching the scheduler.
    case milestone7     = "genesyx.milestone.7"
    case milestone14    = "genesyx.milestone.14"
}

/// Tab a notification tap should land on (matches `MainTabView` tags).
enum NotificationTab: Int {
    case home = 0, track = 1, nutrition = 2, insights = 3, learn = 4, profile = 5
}

/// All copy + cadence for the notification system. Kept in one place so the content-safety
/// scan (and any future localisation) has a single source. Copy is deliberately behavioural
/// ("log", "check", "read") and never makes a medical claim.
enum NotificationContent {

    // MARK: Cadence (Calendar weekday: 1=Sun … 7=Sat)
    static let phWeekday = 2,        phHour = 9         // Monday 09:00
    static let phaseWeekday = 4,     phaseHour = 8      // Wednesday 08:00
    static let nutritionWeekday = 6, nutritionHour = 12 // Friday 12:00
    static let learnWeekday = 1,     learnHour = 9      // Sunday 09:00

    // MARK: pH
    static let phTitle = "Log your pH"
    static let phBody  = "A weekly reading keeps your trends honest. Tap to log today's pH."

    // MARK: Phase (dynamic)
    static let phaseTitle = "Where are you in your cycle?"
    static func phaseBody(phaseLabel: String?) -> String {
        if let p = phaseLabel {
            return "You're in your \(p.lowercased()) phase. See what to expect this week."
        }
        return "Set up your cycle to see today's phase."
    }

    // MARK: Nutrition (body generic enough to later mention supplements)
    static let nutritionTitle = "Check your nutrition"
    static let nutritionBody  = "Small, phase-aware shifts this week. See your focus foods."

    // MARK: Learn (rotates through the 10 articles)
    static let learnTitle = "A new read for your week"
    static func learnBody(article: LearnArticle) -> String {
        "Start with '\(article.title)' — a \(article.readingTime)."
    }
    /// Deterministic rotation keyed to the ISO week number.
    static func rotatingLearnArticle(isoWeek: Int) -> LearnArticle {
        let all = learnArticles
        let idx = ((isoWeek % all.count) + all.count) % all.count
        return all[idx]
    }

    // MARK: Streak milestones
    static let milestone7Title  = "One week strong 🌱"
    static let milestone7Body   = "Seven days of honest logging. Your future self will thank you."
    static let milestone14Title = "Two weeks in 🔥"
    static let milestone14Body  = "Fourteen days. Your trends are starting to mean something."

    /// Every user-facing string, for the banned-phrase safety scan.
    static var allCopyStrings: [String] {
        var strings = [
            phTitle, phBody,
            phaseTitle, phaseBody(phaseLabel: "follicular"), phaseBody(phaseLabel: nil),
            nutritionTitle, nutritionBody,
            learnTitle,
            milestone7Title, milestone7Body,
            milestone14Title, milestone14Body,
        ]
        strings += learnArticles.map { learnBody(article: $0) }
        return strings
    }
}
