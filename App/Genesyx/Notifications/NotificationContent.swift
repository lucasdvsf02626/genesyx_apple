import Foundation
import GenesyxCore

/// Stable identifiers for every notification the app can schedule. Never change a raw value after
/// release — it is the key used to cancel and replace a pending request.
///
/// `weeklyNutrition` and `weeklyPhase` are dead but retained: build 9 scheduled them, and an app
/// upgrading from it must still be able to CANCEL them. Delete them once build 9 is off the estate.
enum NotificationKind: String, CaseIterable {
    case dailyHydration  = "genesyx.daily.hydration"
    case weeklyPh        = "genesyx.weekly.ph"
    case weeklyLearn     = "genesyx.weekly.learn"
    case weeklyInsights  = "genesyx.weekly.insights"
    case weeklyTrack     = "genesyx.weekly.track"
    case weeklyNutrition = "genesyx.weekly.nutrition"   // retired (build 9) — kept to cancel
    case weeklyPhase     = "genesyx.weekly.phase"       // retired (build 9) — kept to cancel
    case milestone7      = "genesyx.milestone.7"
    case milestone14     = "genesyx.milestone.14"
    case milestoneWeek1  = "genesyx.milestone.w1"
    case milestoneWeek4  = "genesyx.milestone.w4"

    init(slot: NotificationSlot) {
        switch slot {
        case .hydration: self = .dailyHydration
        case .ph:        self = .weeklyPh
        case .learn:     self = .weeklyLearn
        case .insights:  self = .weeklyInsights
        case .track:     self = .weeklyTrack
        }
    }

    init(milestone: Milestone) {
        switch milestone {
        case .day7:  self = .milestone7
        case .day14: self = .milestone14
        case .week1: self = .milestoneWeek1
        case .week4: self = .milestoneWeek4
        }
    }
}

/// Tab a notification tap lands on (matches the `MainTabView` order, and `NotificationTarget`).
enum NotificationTab: Int {
    case home = 0, track = 1, nutrition = 2, insights = 3, learn = 4, profile = 5
}

/// The celebrations. Every *other* sentence the app can send is written by `NotificationPlanner`
/// from her own data — this is only the milestone copy, which depends on nothing but the milestone
/// itself.
enum NotificationContent {

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

    /// Every user-facing string the app can send: the milestone copy, plus every sentence the
    /// planner can reach in any state. This is the surface the safety scans walk.
    static var allCopyStrings: [String] {
        Milestone.allCases.flatMap { [milestoneTitle($0), milestoneBody($0)] }
            + NotificationPlanner.allPossibleCopy()
    }
}
