import Foundation

/// The kinds of notification she can switch on and off one at a time.
///
/// One global switch cannot hold seven kinds of message. Someone who wants the cycle note and
/// nothing else had to choose between all of it and none of it, and "none" is the choice people
/// make when the only alternative is everything.
///
/// Deliberately not `NotificationSlot`: `milestones` and `supplements` have no slot (neither is
/// planned — one is fired on the spot, the other is an alarm she set), and the slot names are
/// engineering words rather than hers. Declaration order is the order they are listed in Profile.
public enum NotificationCategory: String, CaseIterable, Sendable {
    case checkIn     = "check_in"
    case cycle       = "cycle"
    case ph          = "ph"
    case logging     = "logging"
    case supplements = "supplements"
    case insights    = "insights"
    case learn       = "learn"
    case milestones  = "milestones"

    public var title: String {
        switch self {
        case .checkIn:     return "Evening check-in"
        case .cycle:       return "Cycle"
        case .ph:          return "pH readings"
        case .logging:     return "Logging reminders"
        case .supplements: return "Supplement reminders"
        case .insights:    return "Insights"
        case .learn:       return "Weekly read"
        case .milestones:  return "Milestones"
        }
    }
}

public extension NotificationSlot {
    var category: NotificationCategory {
        switch self {
        case .hydration: return .checkIn
        case .fertile:   return .cycle
        case .ph:        return .ph
        case .track:     return .logging
        case .insights:  return .insights
        case .learn:     return .learn
        }
    }
}
