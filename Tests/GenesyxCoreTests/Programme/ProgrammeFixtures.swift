import Foundation
@testable import GenesyxCore

/// Shared set-up for the programme tests: the plan's example user and its three worked days.
///
/// The user is on programme day 23 (week 4), answered "yes" to the supplements question, and has a
/// 28-day cycle with a 5-day period, so the predicted fertile window is cycle days 9 to 15.
enum ProgrammeFixtures {

    static let start = CalendarDate(2026, 6, 1)
    static let state = ProgrammeState(startedOn: start, contentVersion: ProgrammeContent.draft.version)

    static func date(ofDay day: Int) -> CalendarDate { ProgrammeCalendar.date(ofDay: day, startedOn: start) }

    /// Cycle settings that put programme day `day` on cycle day `cycleDay`.
    static func settings(day: Int, onCycleDay cycleDay: Int, cycleLength: Int = 28) -> CycleSettings {
        CycleSettings(lastPeriodDate: date(ofDay: day).minusDays(cycleDay - 1), cycleLength: cycleLength, periodLength: 5)
    }

    /// Day A: an ordinary day. Cycle day 20, no scan features, pH already taken this week, water
    /// 1500 of 2400 ml, three food groups, no symptoms.
    static func snapshotA(day: Int = 23) -> ProgrammeDaySnapshot {
        ProgrammeDaySnapshot(
            log: DailyLog(mood: .good, energy: .normal, sleepMinutes: 440, supplements: ["folate"],
                          waterMl: 1500, foodGroups: ["vegetables", "fruit", "protein"]),
            phReadingExistsThisProgrammeWeek: true,
            cycleSettings: settings(day: day, onCycleDay: 20),
            scanFeaturesAvailable: false,
            supplementsAnswer: "yes"
        )
    }

    /// Day B: cycle day 11, scan features available, an LH record, water on goal, no supplement,
    /// no pH reading yet this week.
    static func snapshotB(day: Int = 23) -> ProgrammeDaySnapshot {
        ProgrammeDaySnapshot(
            log: DailyLog(mood: .okay, energy: .high, sleepMinutes: 400, waterMl: 2400),
            phReadingExistsThisProgrammeWeek: false,
            lhResultExistsForDate: true,
            cycleSettings: settings(day: day, onCycleDay: 11),
            scanFeaturesAvailable: true,
            supplementsAnswer: "yes"
        )
    }

    /// Day C: the Day A profile with nothing logged.
    static func snapshotC(day: Int = 23) -> ProgrammeDaySnapshot {
        var snapshot = snapshotA(day: day)
        snapshot.log = nil
        return snapshot
    }

    /// The plan for a programme day. `todayDay` defaults to the day itself.
    static func plan(
        day: Int = 23,
        todayDay: Int? = nil,
        goal: ProgrammeGoalEmphasis = .understandMyCycle,
        _ snapshot: ProgrammeDaySnapshot,
        content: ProgrammeContent = .draft
    ) -> ProgrammeDayPlan {
        ProgrammeTaskEngine.plan(on: date(ofDay: day), state: state, today: date(ofDay: todayDay ?? day),
                                 goal: goal, snapshot: snapshot, content: content)!
    }

    /// The draft content with one activity's standing changed in every week.
    static func content(_ category: ProgrammeTaskCategory, _ standing: ProgrammeActivityStanding) -> ProgrammeContent {
        let draft = ProgrammeContent.draft
        let weeks = draft.weeks.map { week in
            ProgrammeWeekDefinition(
                number: week.number, themeTitle: week.themeTitle, purpose: week.purpose,
                connectsTo: week.connectsTo, nutritionFocus: week.nutritionFocus,
                activities: week.activities.filter { $0.category != category } + [ProgrammeActivityRule(category, standing)],
                relatedContent: week.relatedContent, safetyNotes: week.safetyNotes, review: week.review)
        }
        return ProgrammeContent(version: "test", weeks: weeks, phaseTitles: draft.phaseTitles,
                                kindCopy: draft.kindCopy, kindReflections: draft.kindReflections,
                                kindReadMinutes: draft.kindReadMinutes, testGuidanceWeeks: draft.testGuidanceWeeks)
    }
}

extension ProgrammeDayPlan {
    func task(_ category: ProgrammeTaskCategory) -> ProgrammeTask? { tasks.first { $0.category == category } }
    func weekly(_ category: ProgrammeTaskCategory) -> ProgrammeTask? { weeklyTasks.first { $0.category == category } }
}
