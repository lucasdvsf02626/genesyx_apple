// WeeklySummaryLogic.swift
// Pure aggregation + deterministic narrative for the Weekly Summary card (My Logs).
// No UI, no async, no LLM — one rule-based British-English line, fully unit-testable.
//
// A "week" is the canonical ISO Mon–Sun week (`CalendarDate.startOfWeek`). Everything here is
// derived from real logged data; thin data is called thin (deltas are only shown when the previous
// week actually has something to compare against — no fabricated comparisons).

import Foundation

/// Count of one mood across the week, in canonical order (great → low).
public struct MoodTally: Equatable, Sendable {
    public let mood: Mood
    public let count: Int
    public init(mood: Mood, count: Int) { self.mood = mood; self.count = count }
}

/// Count of one energy level across the week, in canonical order (low → high).
public struct EnergyTally: Equatable, Sendable {
    public let level: EnergyLevel
    public let count: Int
    public init(level: EnergyLevel, count: Int) { self.level = level; self.count = count }
}

/// Week-over-week deltas. Each is `nil` when there's nothing honest to compare against.
public struct WeeklyDeltas: Equatable, Sendable {
    /// This week's water total minus last week's — nil unless last week logged some water.
    public let waterTotalMl: Int?
    /// This week's logged-day count minus last week's — nil unless last week had any log.
    public let daysLogged: Int?
    /// This week's mean sleep minus last week's — nil unless BOTH weeks logged sleep.
    public let sleepAverageMinutes: Int?

    public init(waterTotalMl: Int?, daysLogged: Int?, sleepAverageMinutes: Int?) {
        self.waterTotalMl = waterTotalMl
        self.daysLogged = daysLogged
        self.sleepAverageMinutes = sleepAverageMinutes
    }
}

/// Everything the Weekly Summary card renders for one ISO week.
public struct WeeklySummary: Equatable, Sendable {
    public let weekStart: CalendarDate       // Monday
    public let goalMl: Int
    public let waterByDay: [Int]             // 7 values, Mon → Sun
    public let loggedDays: [Bool]            // 7 flags, Mon → Sun (meaningful log incl. pH)
    public let waterTotalMl: Int
    public let daysLogged: Int               // 0…7
    public let daysOnGoal: Int               // 0…7 (water ≥ goal)
    public let moodTallies: [MoodTally]      // only moods that appear, canonical order
    public let energyTallies: [EnergyTally]  // only levels that appear, canonical order
    public let sleepAverageMinutes: Int?     // nil when no sleep logged this week
    public let phAverage: Double?            // nil when no readings this week
    public let deltas: WeeklyDeltas
    public let narrative: String
    public let isEmpty: Bool                 // nothing meaningful logged this week

    public init(
        weekStart: CalendarDate,
        goalMl: Int,
        waterByDay: [Int],
        loggedDays: [Bool],
        waterTotalMl: Int,
        daysLogged: Int,
        daysOnGoal: Int,
        moodTallies: [MoodTally],
        energyTallies: [EnergyTally],
        sleepAverageMinutes: Int?,
        phAverage: Double?,
        deltas: WeeklyDeltas,
        narrative: String,
        isEmpty: Bool
    ) {
        self.weekStart = weekStart
        self.goalMl = goalMl
        self.waterByDay = waterByDay
        self.loggedDays = loggedDays
        self.waterTotalMl = waterTotalMl
        self.daysLogged = daysLogged
        self.daysOnGoal = daysOnGoal
        self.moodTallies = moodTallies
        self.energyTallies = energyTallies
        self.sleepAverageMinutes = sleepAverageMinutes
        self.phAverage = phAverage
        self.deltas = deltas
        self.narrative = narrative
        self.isEmpty = isEmpty
    }
}

public enum WeeklySummaryLogic {

    /// Aggregate one ISO week (Mon–Sun starting at `weekStart`) and the previous week for deltas.
    /// `phValuesByDate` holds the pH readings recorded on each date (already mapped to the local day).
    public static func summary(
        weekStart: CalendarDate,
        logsByDate: [CalendarDate: DailyLog],
        phValuesByDate: [CalendarDate: [Double]],
        goalMl: Int = TrackingEngine.defaultWaterGoalMl
    ) -> WeeklySummary {
        let days = (0..<7).map { weekStart.addingDays($0) }
        let logs = days.map { logsByDate[$0] ?? DailyLog() }

        let waterByDay = logs.map(\.waterMl)
        let loggedDays = days.enumerated().map { i, date in
            logs[i].isMeaningfulLog || !(phValuesByDate[date] ?? []).isEmpty
        }
        let waterTotal = waterByDay.reduce(0, +)
        let daysLogged = loggedDays.filter { $0 }.count
        let daysOnGoal = waterByDay.filter { $0 >= goalMl }.count

        let moodTallies = Mood.allCases.compactMap { mood -> MoodTally? in
            let count = logs.filter { $0.mood == mood }.count
            return count > 0 ? MoodTally(mood: mood, count: count) : nil
        }
        let energyTallies = EnergyLevel.allCases.compactMap { level -> EnergyTally? in
            let count = logs.filter { $0.energy == level }.count
            return count > 0 ? EnergyTally(level: level, count: count) : nil
        }

        let sleepAvg = mean(logs.compactMap { $0.sleepMinutes }.filter { $0 > 0 })
        let phValues = days.flatMap { phValuesByDate[$0] ?? [] }
        let phAvg = phValues.isEmpty ? nil : phValues.reduce(0, +) / Double(phValues.count)

        // Previous week — for honest deltas only.
        let prevStart = weekStart.addingDays(-7)
        let prevDays = (0..<7).map { prevStart.addingDays($0) }
        let prevLogs = prevDays.map { logsByDate[$0] ?? DailyLog() }
        let prevLoggedCount = prevDays.enumerated().filter { i, date in
            prevLogs[i].isMeaningfulLog || !(phValuesByDate[date] ?? []).isEmpty
        }.count
        let prevHasAnyLog = prevLoggedCount > 0
        let prevWaterTotal = prevLogs.map(\.waterMl).reduce(0, +)
        let prevHasWater = prevLogs.contains { $0.waterMl > 0 }
        let prevSleepAvg = mean(prevLogs.compactMap { $0.sleepMinutes }.filter { $0 > 0 })

        let deltas = WeeklyDeltas(
            waterTotalMl: prevHasWater ? waterTotal - prevWaterTotal : nil,
            daysLogged: prevHasAnyLog ? daysLogged - prevLoggedCount : nil,
            sleepAverageMinutes: (sleepAvg != nil && prevSleepAvg != nil) ? sleepAvg! - prevSleepAvg! : nil
        )

        let isEmpty = daysLogged == 0
        return WeeklySummary(
            weekStart: weekStart,
            goalMl: goalMl,
            waterByDay: waterByDay,
            loggedDays: loggedDays,
            waterTotalMl: waterTotal,
            daysLogged: daysLogged,
            daysOnGoal: daysOnGoal,
            moodTallies: moodTallies,
            energyTallies: energyTallies,
            sleepAverageMinutes: sleepAvg,
            phAverage: phAvg,
            deltas: deltas,
            narrative: narrativeLine(
                daysLogged: daysLogged, daysOnGoal: daysOnGoal,
                hasAnyWater: waterTotal > 0, isEmpty: isEmpty),
            isEmpty: isEmpty
        )
    }

    /// One deterministic, de-pressured British-English line summarising the week. Never medical,
    /// never guilt. Consistency first, hydration as a gentle second clause.
    public static func narrativeLine(
        daysLogged: Int,
        daysOnGoal: Int,
        hasAnyWater: Bool,
        isEmpty: Bool
    ) -> String {
        if isEmpty {
            return "Nothing logged this week yet — one small entry starts the picture."
        }
        var line: String
        switch daysLogged {
        case 6...7: line = "A really consistent week — \(daysLogged) of 7 days logged."
        case 3...5: line = "A steady week — \(daysLogged) of 7 days logged."
        default:    line = "\(daysLogged) day\(daysLogged == 1 ? "" : "s") logged this week — every entry counts."
        }
        if hasAnyWater {
            switch daysOnGoal {
            case 4...7: line += " Hydration was on goal most days."
            case 1...3: line += " Hydration reached goal on \(daysOnGoal) day\(daysOnGoal == 1 ? "" : "s")."
            default:    break
            }
        }
        return line
    }

    /// Integer mean, or nil for an empty set.
    private static func mean(_ values: [Int]) -> Int? {
        values.isEmpty ? nil : values.reduce(0, +) / values.count
    }
}
