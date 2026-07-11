import Foundation
import GenesyxCore

/// Stable identifiers for every notification the app can schedule. Never change a raw value after
/// release — it is the key used to cancel and replace a pending request.
enum NotificationKind: String, CaseIterable {
    case dailyHydration  = "genesyx.daily.hydration"
    case weeklyPh        = "genesyx.weekly.ph"
    case weeklyPhase     = "genesyx.weekly.phase"
    case weeklyNutrition = "genesyx.weekly.nutrition"
    case weeklyLearn     = "genesyx.weekly.learn"
    case milestone7      = "genesyx.milestone.7"
    case milestone14     = "genesyx.milestone.14"
    case milestoneWeek1  = "genesyx.milestone.w1"
    case milestoneWeek4  = "genesyx.milestone.w4"

    init(milestone: Milestone) {
        switch milestone {
        case .day7:  self = .milestone7
        case .day14: self = .milestone14
        case .week1: self = .milestoneWeek1
        case .week4: self = .milestoneWeek4
        }
    }
}

/// Tab a notification tap lands on (matches the `MainTabView` order).
enum NotificationTab: Int {
    case home = 0, track = 1, nutrition = 2, insights = 3, learn = 4, profile = 5
}

/// All copy and cadence in one place, so the content-safety scan (and any future localisation) has
/// a single source. Every nudge is behavioural — "log", "check", "read". None makes a medical
/// claim, and none guilts her: there is deliberately no "you broke your streak" notification and
/// no evening follow-up.
enum NotificationContent {

    // MARK: Cadence (Calendar weekday: 1 = Sun … 7 = Sat)
    static let hydrationHour = 10                        // daily 10:00, only on days she hasn't logged
    static let phWeekday = 2,        phHour = 9          // Monday 09:00
    static let phaseWeekday = 4,     phaseHour = 8       // Wednesday 08:00
    static let nutritionWeekday = 6, nutritionHour = 12  // Friday 12:00
    static let learnWeekday = 1,     learnHour = 9       // Sunday 09:00

    // MARK: Daily hydration
    static let hydrationTitle = "A glass to start"
    static let hydrationBody  = "Nothing logged yet today — one tap on the coach and you're going."

    // MARK: pH
    static let phTitle = "Log your pH"
    static let phBody  = "A weekly reading keeps your trend honest."

    // MARK: Phase (dynamic)
    static let phaseTitle = "Where are you in your cycle?"
    static func phaseBody(phaseLabel: String?) -> String {
        guard let phaseLabel else { return "Set up your cycle to see today's phase." }
        return "You're in your \(phaseLabel.lowercased()) phase — see what to expect."
    }

    // MARK: Nutrition
    static let nutritionTitle = "Check your nutrition"
    static let nutritionBody  = "Small phase-aware shifts this week."

    // MARK: Learn (rotates the library by ISO week)
    static let learnTitle = "A new read for your week"
    static func learnBody(article: LearnArticle) -> String {
        "Start with '\(article.title)' — a \(article.readingTime)."
    }

    /// Deterministic rotation keyed to the ISO week number, so every device shows the same article
    /// in a given week and nobody gets the same one twice in a row.
    static func rotatingLearnArticle(isoWeek: Int) -> LearnArticle {
        let all = learnArticles
        let index = ((isoWeek % all.count) + all.count) % all.count
        return all[index]
    }

    // MARK: Streak milestones (fired once, from StreakEngine)
    static func milestoneTitle(_ milestone: Milestone) -> String {
        switch milestone {
        case .day7:  return "One week strong"
        case .day14: return "Two weeks in"
        case .week1: return "A full steady week"
        case .week4: return "Four weeks of showing up"
        }
    }

    static func milestoneBody(_ milestone: Milestone) -> String {
        switch milestone {
        case .day7:  return "Seven days of hydration logged. That's a habit forming."
        case .day14: return "Fourteen days. Your trends are starting to mean something."
        case .week1: return "You logged on most days this week. That's all consistency asks."
        case .week4: return "Four steady weeks. Your data has a real story in it now."
        }
    }

    /// Every user-facing string, for the banned-phrase safety scan.
    static var allCopyStrings: [String] {
        var strings = [
            hydrationTitle, hydrationBody,
            phTitle, phBody,
            phaseTitle, phaseBody(phaseLabel: "follicular"), phaseBody(phaseLabel: nil),
            nutritionTitle, nutritionBody,
            learnTitle,
        ]
        strings += Milestone.allCases.flatMap { [milestoneTitle($0), milestoneBody($0)] }
        strings += learnArticles.map { learnBody(article: $0) }
        return strings
    }
}
