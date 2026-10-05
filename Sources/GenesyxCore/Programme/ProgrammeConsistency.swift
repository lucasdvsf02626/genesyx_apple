import Foundation

// Programme consistency: counts and an optional percentage, no wording. The arithmetic is set out
// in plain words at the top of `ProgrammeTaskEngine.swift`. Separate from the logging streak, which
// this file neither reads nor alters; the two answer different questions and can disagree.

/// Why a figure carries no percentage.
public enum ProgrammePercentageWithheld: String, Sendable {
    /// Nothing was counted in the period.
    case nothingCounted
    /// Fewer activities were counted than `ProgrammeConsistency.minimumCountedForPercentage`.
    case belowMinimum
}

/// A consistency figure for a day or a period. Presentation-neutral: the screen chooses the words.
public struct ProgrammeConsistencyFigure: Hashable, Sendable {
    /// The denominator: activities counted.
    public let counted: Int
    /// The numerator: the sum of their credits.
    public let credit: Double
    /// Counted activities fully done.
    public let completed: Int
    /// Counted activities with some credit but not all of it.
    public let partlyCompleted: Int
    /// Whole per cent, halves up. `nil` when withheld.
    public let percentage: Int?
    public let withheld: ProgrammePercentageWithheld?

    /// Activities were counted and none has any credit: the "nothing recorded" state.
    public var nothingRecorded: Bool { counted > 0 && credit == 0 }
}

/// Today, as counts only. Today never gets a percentage.
public struct ProgrammeTodayProgress: Hashable, Sendable {
    public let completed: Int
    public let partlyCompleted: Int
    public let total: Int
}

/// Every figure the programme shows, for one "today".
public struct ProgrammeConsistencyReport: Hashable, Sendable {
    /// `nil` when today is not a programme day or no plan was supplied for it.
    public let today: ProgrammeTodayProgress?
    /// The current programme week (week 13 once the programme is complete), up to yesterday.
    public let week: ProgrammeConsistencyFigure
    /// The thirty programme days ending yesterday.
    public let trailing30Days: ProgrammeConsistencyFigure
    public let phases: [ProgrammePhase: ProgrammeConsistencyFigure]
    public let programme: ProgrammeConsistencyFigure
    /// Whole programme, one figure per activity that was ever counted.
    public let categories: [ProgrammeTaskCategory: ProgrammeConsistencyFigure]
}

public enum ProgrammeConsistency {

    /// A percentage is offered only from this many counted activities.
    public static let minimumCountedForPercentage = 5

    /// The figure for any collection of tasks. Only counted tasks are read.
    public static func figure(for tasks: [ProgrammeTask]) -> ProgrammeConsistencyFigure {
        let counted = tasks.filter(\.isCounted)
        let credit = counted.reduce(0) { $0 + $1.credit }
        let withheld: ProgrammePercentageWithheld? =
            counted.isEmpty ? .nothingCounted
            : counted.count < minimumCountedForPercentage ? .belowMinimum : nil
        return ProgrammeConsistencyFigure(
            counted: counted.count,
            credit: credit,
            completed: counted.filter(\.isDone).count,
            partlyCompleted: counted.filter { $0.credit > 0 && !$0.isDone }.count,
            percentage: withheld == nil ? Int((credit * 100 / Double(counted.count) + 0.5).rounded(.down)) : nil,
            withheld: withheld
        )
    }

    /// One day, on its own. Weekly activities are not part of a day.
    public static func day(_ plan: ProgrammeDayPlan) -> ProgrammeConsistencyFigure {
        figure(for: plan.tasks)
    }

    /// Today as "n of m activities completed".
    public static func today(_ plan: ProgrammeDayPlan) -> ProgrammeTodayProgress {
        let figure = figure(for: plan.tasks)
        return ProgrammeTodayProgress(completed: figure.completed, partlyCompleted: figure.partlyCompleted,
                                      total: figure.counted)
    }

    /// A span of programme days, read up to the end of yesterday.
    ///
    /// `plans` holds one plan per programme day, in any order; a day with no plan adds nothing.
    /// `todayDay` is today's programme day number and may be above 90. Daily tasks are summed for
    /// the days in `days` before `todayDay`. Each weekly activity adds one unit for every
    /// programme week whose first day is among those days, once it is completed or skipped.
    public static func period(
        _ plans: [ProgrammeDayPlan],
        days: ClosedRange<Int>,
        todayDay: Int
    ) -> ProgrammeConsistencyFigure {
        figure(for: countedTasks(plans, days: days, todayDay: todayDay))
    }

    /// All figures for `today`. `plans` as for `period`.
    public static func report(
        state: ProgrammeState,
        today: CalendarDate,
        plans: [ProgrammeDayPlan]
    ) -> ProgrammeConsistencyReport {
        let all = 1...ProgrammeCalendar.totalDays
        guard let start = state.startedOn else {
            let empty = figure(for: [])
            return ProgrammeConsistencyReport(
                today: nil, week: empty, trailing30Days: empty,
                phases: Dictionary(uniqueKeysWithValues: ProgrammePhase.allCases.map { ($0, empty) }),
                programme: empty, categories: [:])
        }
        let todayDay = ProgrammeCalendar.dayNumber(on: today, startedOn: start)
        let week = ProgrammeCalendar.week(forDay: todayDay)
        let everything = countedTasks(plans, days: all, todayDay: todayDay)

        return ProgrammeConsistencyReport(
            today: plans.first { $0.day == todayDay }.map { self.today($0) },
            week: period(plans, days: ProgrammeCalendar.dayRange(ofWeek: week), todayDay: todayDay),
            trailing30Days: period(plans, days: (todayDay - 30)...(todayDay - 1), todayDay: todayDay),
            phases: Dictionary(uniqueKeysWithValues: ProgrammePhase.allCases.map {
                ($0, period(plans, days: $0.dayRange, todayDay: todayDay))
            }),
            programme: figure(for: everything),
            categories: Dictionary(grouping: everything, by: \.category).mapValues { figure(for: $0) }
        )
    }

    /// The counted tasks of a period: daily ones from each day before today, and one per weekly
    /// activity for each programme week that starts in the period.
    private static func countedTasks(
        _ plans: [ProgrammeDayPlan],
        days: ClosedRange<Int>,
        todayDay: Int
    ) -> [ProgrammeTask] {
        let past = plans.filter { $0.day < todayDay }
        var tasks = past.filter { days.contains($0.day) }.flatMap(\.tasks).filter(\.isCounted)

        for (week, weekPlans) in Dictionary(grouping: past, by: \.week) {
            guard days.contains(ProgrammeCalendar.dayRange(ofWeek: week).lowerBound) else { continue }
            let weekly = weekPlans.sorted { $0.day < $1.day }.flatMap(\.weeklyTasks)
            for (_, sameActivity) in Dictionary(grouping: weekly, by: \.category) {
                // Completed on any day of the week wins; otherwise it counts only once the week is
                // over. An open weekly activity adds nothing yet.
                if let unit = sameActivity.first(where: { $0.status == .completed })
                    ?? sameActivity.first(where: { $0.status == .skipped }) {
                    tasks.append(unit)
                }
            }
        }
        return tasks
    }
}
