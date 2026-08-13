import Foundation

/// A reminder she set herself, for one supplement, at one hour of the day.
///
/// Deliberately outside `NotificationPlanner`. Everything the planner sends is something the app
/// decided to say, so it is rationed: a weekly budget, one a day, and silence once she stops
/// logging. This is the opposite — an alarm she asked for. Rationing it would mean the app
/// overruling an instruction, and an alarm that skips a day because something else was already
/// scheduled is simply broken.
///
/// The one planner rule that does still hold is the copy contract: no medical claim, no guilt.
/// `allPossibleCopy` is how the safety scans reach it.
public struct SupplementReminder: Identifiable, Equatable, Sendable {
    /// Stable across renames and reorderings — the custom supplement's UUID, or `essential.<initial>`
    /// for the fixed Genesyx plan. It becomes the notification identifier, which is what cancels and
    /// replaces a pending request, so it must never be the display name.
    public let id: String
    public let name: String
    public let dose: String
    public let hour: Int
    /// One personalised sentence appended to the body, or nil for the plain reminder. Only
    /// `SupplementPersonalisation` ever sets it, and only when its feature flag is on — so the
    /// manual path this type was written for produces exactly the string it always did.
    public let context: String?

    public init(id: String, name: String, dose: String, hour: Int, context: String? = nil) {
        self.id = id
        self.name = name
        self.dose = dose
        self.hour = hour
        self.context = context
    }

    public var title: String { "Time for \(name)" }

    /// Says where it came from, because a notification whose origin isn't obvious reads as spam.
    public var body: String {
        let base = dose.isEmpty ? "From your supplement plan." : "\(dose). From your supplement plan."
        guard let context else { return base }
        return "\(base) \(context)"
    }

    /// The fixed Genesyx plan has no record of its own to hang an id on, so one is derived. Keyed on
    /// the initial rather than the name: renaming "Vitamin D" in content must not orphan her alarm.
    public static func essentialKey(initial: String) -> String { "essential.\(initial)" }

    /// Every supplement she can see, paired with the hour she chose for it. Supplements she set no
    /// time for are absent — no reminder is the default, and four unrequested alarms a day is how an
    /// app gets muted entirely.
    ///
    /// Sorted so the scheduled set is identical between launches given identical input.
    public static func all(customs: [CustomSupplement], hours: [String: Int]) -> [SupplementReminder] {
        let essentials = NutritionContent.supplementPlan.map {
            (id: essentialKey(initial: $0.initial), name: $0.name, dose: "")
        }
        let mine = customs.map { (id: $0.id, name: $0.name, dose: $0.dose) }

        return (essentials + mine)
            .compactMap { supplement in
                guard let hour = hours[supplement.id], (0...23).contains(hour) else { return nil }
                return SupplementReminder(id: supplement.id, name: supplement.name,
                                          dose: supplement.dose, hour: hour)
            }
            .sorted { ($0.hour, $0.id) < ($1.hour, $1.id) }
    }

    /// Both branches of the body, plus a title — the surface the banned-phrase and guilt scans walk.
    ///
    /// Includes every personalised variant even while the feature is dormant. Copy that ships in the
    /// binary is copy that can reach her the day the flag flips, and a scan that only walked the
    /// live path would clear it the day before and fail nobody.
    public static var allPossibleCopy: [String] {
        let plain = [SupplementReminder(id: "x", name: "Magnesium", dose: "200 mg", hour: 8),
                     SupplementReminder(id: "y", name: "Folate", dose: "", hour: 20)]
        let personalised = SupplementPersonalisation.allContexts.map {
            SupplementReminder(id: "z", name: "Zinc", dose: "15 mg", hour: 9, context: $0)
        }
        return (plain + personalised).flatMap { [$0.title, $0.body] }
    }
}
