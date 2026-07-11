// NotificationContent.swift
// WS2 §4 — single source for every notification ID + copy, fully testable.
// Copy rules (§4 content-safety): behavioural nudges only ("log", "check",
// "read") — never medical claims, never guilt. Exact copy from the master doc.

import Foundation
import GenesyxCore

enum NotificationID {
    static let dailyHydration = "genesyx.daily.hydration"
    static let weeklyPh = "genesyx.weekly.ph"
    static let weeklyPhase = "genesyx.weekly.phase"
    static let weeklyNutrition = "genesyx.weekly.nutrition"
    static let weeklyLearn = "genesyx.weekly.learn"
    static func milestone(_ m: Milestone) -> String { "genesyx.milestone.\(m.rawValue)" }

    /// Every ID Genesyx can ever schedule — used for cancel-all and reconcile.
    static var all: [String] {
        [dailyHydration, weeklyPh, weeklyPhase, weeklyNutrition, weeklyLearn]
            + Milestone.allCases.map(milestone)
    }
}

struct NotificationSpec: Equatable {
    let id: String
    let title: String
    let body: String
    /// Deep-link target the router resolves on tap.
    let route: NotificationRoute
    /// Repeating calendar schedule; nil = one-shot (milestones).
    let schedule: DateComponents?
}

enum NotificationRoute: Equatable {
    case home
    case track           // pH + phase land on Track
    case nutrition       // Hydration Coach lives at the top of Nutrition
    case insights
    case learn(slug: String?)

    var userInfo: [String: String] {
        switch self {
        case .home: return ["route": "home"]
        case .track: return ["route": "track"]
        case .nutrition: return ["route": "nutrition"]
        case .insights: return ["route": "insights"]
        case .learn(let slug):
            var info = ["route": "learn"]
            if let slug { info["slug"] = slug }
            return info
        }
    }

    static func from(userInfo: [AnyHashable: Any]) -> NotificationRoute? {
        switch userInfo["route"] as? String {
        case "home": return .home
        case "track": return .track
        case "nutrition": return .nutrition
        case "insights": return .insights
        case "learn": return .learn(slug: userInfo["slug"] as? String)
        default: return nil
        }
    }

    /// Tab index in `MainTabView` (Home 0, Track 1, Nutrition 2, Insights 3, Learn 4, Profile 5).
    var tabIndex: Int {
        switch self {
        case .home: return 0
        case .track: return 1
        case .nutrition: return 2
        case .insights: return 3
        case .learn: return 4
        }
    }
}

enum NotificationContent {

    private static func weekly(_ weekday: Int, _ hour: Int) -> DateComponents {
        // Calendar.current weekday: 1 = Sunday … 7 = Saturday.
        var c = DateComponents()
        c.weekday = weekday
        c.hour = hour
        c.minute = 0
        return c
    }

    private static func daily(_ hour: Int) -> DateComponents {
        var c = DateComponents()
        c.hour = hour
        c.minute = 0
        return c
    }

    // MARK: the set (§4 table, verbatim copy)

    /// Daily 10:00 — suppressed by the service on days water is already logged.
    static let dailyHydration = NotificationSpec(
        id: NotificationID.dailyHydration,
        title: "A glass to start",
        body: "Nothing logged yet today — one tap on the coach and you're going.",
        route: .nutrition,
        schedule: daily(10)
    )

    static let weeklyPh = NotificationSpec(
        id: NotificationID.weeklyPh,
        title: "Log your pH",
        body: "A weekly reading keeps your trend honest.",
        route: .track,
        schedule: weekly(2, 9) // Monday 09:00
    )

    /// Wednesday 08:00 — body resolved from the CURRENT phase at scheduling time;
    /// the service re-schedules on every foreground so the copy stays fresh.
    static func weeklyPhase(phaseName: String?) -> NotificationSpec {
        NotificationSpec(
            id: NotificationID.weeklyPhase,
            title: "Where are you in your cycle?",
            body: phaseName.map { "You're in your \($0) phase — see what to expect." }
                ?? "Set up your cycle to see where you are — it takes one date.",
            route: .track,
            schedule: weekly(4, 8) // Wednesday 08:00
        )
    }

    static let weeklyNutrition = NotificationSpec(
        id: NotificationID.weeklyNutrition,
        title: "Check your nutrition",
        body: "Small phase-aware shifts this week.",
        route: .nutrition,
        schedule: weekly(6, 12) // Friday 12:00
    )

    /// Sunday 09:00 — rotates the article library by ISO week so every week
    /// suggests a different read; deep-links straight to that article.
    static func weeklyLearn(articleSlugs: [String], isoWeek: Int) -> NotificationSpec {
        let slug = articleSlugs.isEmpty ? nil
            : articleSlugs[((isoWeek % articleSlugs.count) + articleSlugs.count) % articleSlugs.count]
        return NotificationSpec(
            id: NotificationID.weeklyLearn,
            title: "A new read for your week",
            body: "A short article picked for this week is waiting in Learn.",
            route: .learn(slug: slug),
            schedule: weekly(1, 9) // Sunday 09:00
        )
    }

    /// Milestone celebrations — one-shot, congratulation only (§4/§8: no guilt,
    /// no "streak broken", ever).
    static func milestone(_ m: Milestone) -> NotificationSpec {
        let (title, body): (String, String)
        switch m {
        case .day7:
            (title, body) = ("One week strong",
                             "Seven days of hydration logging in a row. Quiet consistency — that's the whole game.")
        case .day14:
            (title, body) = ("Two weeks in",
                             "Fourteen straight days logged. Your insights get sharper with every one.")
        case .week1:
            (title, body) = ("A full steady week",
                             "You logged five or more days this week. That's exactly the rhythm that works.")
        case .week4:
            (title, body) = ("Four weeks of showing up",
                             "A month of steady weeks. Your patterns are becoming genuinely readable.")
        }
        return NotificationSpec(
            id: NotificationID.milestone(m),
            title: title,
            body: body,
            route: .insights,
            schedule: nil
        )
    }

    /// Every visible string, for the banned-phrase content-safety scan.
    static func allVisibleStrings(
        samplePhases: [String?] = ["period", "follicular", "ovulatory", "luteal", nil],
        sampleSlugs: [String] = ["your-first-week-with-genesyx"]
    ) -> [String] {
        var specs: [NotificationSpec] = [dailyHydration, weeklyPh, weeklyNutrition]
        specs += samplePhases.map { weeklyPhase(phaseName: $0) }
        specs.append(weeklyLearn(articleSlugs: sampleSlugs, isoWeek: 1))
        specs += Milestone.allCases.map(milestone)
        return specs.flatMap { [$0.title, $0.body] }
    }
}
