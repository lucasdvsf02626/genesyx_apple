import Foundation

/// Pure copy + time-of-day logic for the Hydration Coach — kept separate so it's unit-testable
/// and its strings can be scanned by the content-safety test. Behavioural, never medical.
///
/// Moved verbatim from `NutritionView.swift` into GenesyxCore (PR1) so both the app UI and the
/// pure `HydrationStatusEvaluator` can reach the same single copy source — zero behaviour or
/// wording change.
public enum HydrationCoach {

    public enum DayPart: Equatable, Sendable {
        case morning, midday, afternoon, evening, night
        public static func at(hour: Int) -> DayPart {
            switch hour {
            case 5...11:  return .morning
            case 12...15: return .midday
            case 16...19: return .afternoon
            case 20...22: return .evening
            default:      return .night      // 23, 0–4
            }
        }
    }

    /// First two words always name the part of the day. Column chosen by `pct` (scales to the goal).
    public static func coachLine(hour: Int, pct: Double) -> String {
        let under = pct < 1.0
        switch DayPart.at(hour: hour) {
        case .morning:
            return under
                ? "Morning — start with a glass now. Anchor it to breakfast so you don't have to remember later."
                : "Great start — you're already hydrated this morning."
        case .midday:
            return under
                ? "Midday — a glass with lunch keeps you steady through the afternoon dip."
                : "Steady through lunch — nice."
        case .afternoon:
            return under
                ? "Afternoon — one glass with your desk break. This is where most days slip."
                : "You've kept it steady through the afternoon."
        case .evening:
            return under
                ? "Evening — small sips only. Don't front-load before bed."
                : "Target hit — ease off the water before bed."
        case .night:
            return under
                ? "Late night — a small sip if you're thirsty, nothing more."
                : "You're hydrated for the day."
        }
    }

    public static func contextLine(phase: Phase?) -> String {
        guard let phase else { return "Log your cycle to get phase-aware hydration guidance." }
        switch phase {
        case .period:     return "Iron-rich foods and steady water help during your period."
        case .follicular: return "You likely have energy this week — keep water steady to match."
        case .ovulatory:  return "Nothing special required — keep drinking."
        case .luteal:     return "Smaller, regular meals and water can ease energy dips."
        }
    }

    /// Weekly-consistency line — only surfaced when there's at least one complete week (≥4 of 7
    /// days). De-pressured: celebrates steadiness, never demands perfection.
    public static func weeklyStreakLabel(_ weeks: Int) -> String {
        weeks == 1
            ? "1 steady week — consistency is doing its quiet work."
            : "\(weeks) steady weeks — consistency is doing its quiet work."
    }

    /// Always-visible hydration-log-streak pill copy — de-pressured, encouraging even at zero.
    /// Named a "log streak" (water logged) so it never reads as a goal streak and can't contradict
    /// the "Days on goal X/7" tile.
    public static func streakLabel(_ streak: Int) -> String {
        switch streak {
        case 0:  return "Log streak — start today"
        case 1:  return "Day 1 — great start"
        default: return "\(streak)-day log streak"
        }
    }

    public static let whyText = "Steady hydration supports your energy and mood. The old 'eight glasses a day' rule came from a 1945 recommendation whose next sentence got lost: most of that water already comes from food. Thirst is a reasonable guide. Anchor a glass to meals and routines, and you won't have to think about it."

    /// Every user-facing string, for the content-safety scan.
    public static var allStrings: [String] {
        var out: [String] = []
        for hour in [7, 13, 17, 21, 2] {
            out.append(coachLine(hour: hour, pct: 0.2))
            out.append(coachLine(hour: hour, pct: 1.0))
        }
        for phase in Phase.allCases { out.append(contextLine(phase: phase)) }
        out.append(contextLine(phase: nil))
        for streak in [0, 1, 3] { out.append(streakLabel(streak)) }
        for weeks in [1, 4] { out.append(weeklyStreakLabel(weeks)) }
        out.append(whyText)
        return out
    }
}
