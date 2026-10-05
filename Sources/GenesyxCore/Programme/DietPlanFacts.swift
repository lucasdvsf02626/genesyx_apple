import Foundation

// Your Diet Plan: what she has recorded, as plain facts. Pure and synchronous, Foundation only, no
// stored state: every date is passed in and every figure is counted again from `DailyLog`.
//
// THE COUNTING, IN PLAIN WORDS
//   • A day's built-in groups are the `FoodGroup` cases whose raw value is in `DailyLog.foodGroups`,
//     in the tracker's order. Any other token in that set is one of her own groups.
//   • A day has a nutrition check-in when the set holds anything at all, built-in or her own. This
//     is the rule `ProgrammeTaskEngine` uses for the nutrition check-in, and a test holds the two
//     together.
//   • Over a range of dates, only the days that have begun are read: the first day of the range up
//     to today, and never past the end of the range. Today is a day that has begun.
//   • Per group, the figure is the number of those days on which the group was recorded.
//
// WHAT IS DELIBERATELY NOT HERE
//   Whole-number counts are all this file produces. There is no score, no percentage, no grade, no
//   rating and no measure of diet quality; no share of six, no average and no total across groups.
//   The groups always come back in the tracker's own order, so nothing orders them by how often
//   they were recorded, and no list holds the groups or the days that were left blank.
//   `DietPlanGuardTests` reads this source and fails if that changes.

/// One day of the food group tracker.
public struct DietPlanDayFacts: Hashable, Sendable {
    /// The built-in groups recorded on the day, in the tracker's order.
    public let recordedGroups: [FoodGroup]
    /// Her own groups recorded on the day, by name, in alphabetical order. Not part of the six.
    public let customGroups: [String]
    /// Something was recorded on the day: a built-in group, one of her own, or both.
    public let hasCheckIn: Bool

    /// How many of the built-in groups were recorded. A fact for display beside `groupTotal`.
    public var recordedCount: Int { recordedGroups.count }
    /// The number of built-in groups: six.
    public var groupTotal: Int { FoodGroup.allCases.count }
}

/// The number of days in a range on which one built-in group was recorded.
public struct DietPlanGroupDays: Hashable, Sendable {
    public let group: FoodGroup
    public let days: Int
}

/// A range of dates, counted.
public struct DietPlanHistoryFacts: Hashable, Sendable {
    public let firstDate: CalendarDate
    /// The last date of the range. It can be later than today.
    public let lastDate: CalendarDate
    /// The days of the range that have begun: from `firstDate` to today, never past `lastDate`.
    public let daysElapsed: Int
    /// Of those days, the ones with a nutrition check-in.
    public let daysWithCheckIn: Int
    /// One entry for each built-in group, always in the tracker's order.
    public let groupDays: [DietPlanGroupDays]

    /// The number of elapsed days on which `group` was recorded.
    public func days(recording group: FoodGroup) -> Int {
        groupDays.first { $0.group == group }?.days ?? 0
    }
}

public enum DietPlanFacts {

    /// The facts for one day. Pass `nil` when the day has no log.
    public static func day(_ log: DailyLog?) -> DietPlanDayFacts {
        let logged = log?.foodGroups ?? []
        return DietPlanDayFacts(
            recordedGroups: FoodGroup.allCases.filter { logged.contains($0.rawValue) },
            customGroups: logged.subtracting(FoodGroup.allCases.map(\.rawValue)).sorted(),
            hasCheckIn: !logged.isEmpty)
    }

    /// The facts for the dates from `first` to `last`. Days after `today` are not read.
    public static func history(
        from first: CalendarDate,
        through last: CalendarDate,
        today: CalendarDate,
        logsByDate: [CalendarDate: DailyLog]
    ) -> DietPlanHistoryFacts {
        let end = min(last, today)
        var elapsed = 0
        var withCheckIn = 0
        var daysByGroup: [FoodGroup: Int] = [:]
        var date = first
        while date <= end {
            let facts = day(logsByDate[date])
            elapsed += 1
            if facts.hasCheckIn { withCheckIn += 1 }
            for group in facts.recordedGroups { daysByGroup[group, default: 0] += 1 }
            date = date.plusDays(1)
        }
        return DietPlanHistoryFacts(
            firstDate: first,
            lastDate: last,
            daysElapsed: elapsed,
            daysWithCheckIn: withCheckIn,
            groupDays: FoodGroup.allCases.map { DietPlanGroupDays(group: $0, days: daysByGroup[$0] ?? 0) })
    }

    /// The facts for one programme week (1 to 13), over the dates `ProgrammeCalendar` gives it.
    /// `nil` when the programme has no start date or the week does not exist.
    public static func programmeWeek(
        _ week: Int,
        state: ProgrammeState,
        today: CalendarDate,
        logsByDate: [CalendarDate: DailyLog]
    ) -> DietPlanHistoryFacts? {
        guard let start = state.startedOn, (1...ProgrammeCalendar.totalWeeks).contains(week) else { return nil }
        let days = ProgrammeCalendar.dayRange(ofWeek: week)
        return history(
            from: ProgrammeCalendar.date(ofDay: days.lowerBound, startedOn: start),
            through: ProgrammeCalendar.date(ofDay: days.upperBound, startedOn: start),
            today: today,
            logsByDate: logsByDate)
    }

    /// The facts for the `days` days ending today: 7 gives today and the six days before it.
    public static func trailing(
        days: Int,
        endingOn today: CalendarDate,
        logsByDate: [CalendarDate: DailyLog]
    ) -> DietPlanHistoryFacts {
        history(from: today.minusDays(max(days, 1) - 1), through: today, today: today, logsByDate: logsByDate)
    }
}
