// ProgrammeTaskEngine.swift
// The 90-Day Programme core. Pure and synchronous, Foundation only, no stored state: every date is
// passed in, and every status and figure is worked out again from records that already exist.
//
// THE ARITHMETIC, IN PLAIN WORDS
//
// Position (ProgrammeState.swift)
//   • Stored: the start DATE (and a stop date if she leaves). Nothing else.
//   • Day  = whole calendar days since the start date, plus one. Day 1 is the start date.
//   • Week = (day - 1) / 7 + 1, counted from the start date. Days 85 to 90 are week 13 (six days).
//   • Phase = days 1-30, 31-60, 61-90. Day 91 onwards is "completed" and the day keeps counting.
//   • No start date = not started. A date before the start = "before start", never a negative day.
//
// Tasks (this file)
//   • The week's schedule lists activities as ELIGIBLE (counted) or OPTIONAL (offered, never
//     counted). The day's facts can then make an activity NOT APPLICABLE (not counted, not shown).
//   • Credit is 1 when the activity's record exists and 0 when it does not. Only hydration has a
//     numeric target, so only hydration is proportional: min(water / goal, 1).
//   • The nutrition check-in is 1 when ANY food group is recorded and 0 otherwise. One group and
//     six groups are the same credit. "n of 6 groups recorded" is reported beside it as a plain
//     fact that no figure reads.
//   • Only the EXISTENCE of a record is read. Never a mood or energy level, a symptom, a length of
//     sleep, a pH value, a test result or a cycle length; and the intimacy field is not read at all.
//   • A counted activity is COMPLETED once it has any credit, SKIPPED when it has none and its day
//     (or, for a weekly one, its programme week) is over, and ELIGIBLE while still open.
//   • An ovulation test is counted only on a date inside the predicted fertile window, and only
//     where the feature exists in this build. A pH reading is counted once per programme week,
//     never in a day. The pregnancy-test category is education only: never counted.
//   • The goal changes the ORDER of the list and which optional activities are offered. It never
//     changes a status or a credit.
//
// Consistency (ProgrammeConsistency.swift)
//   • A day    = sum of credits / number of counted activities that day.
//   • A period = sum of all credits in the period / sum of all counted activities in the period.
//     A ratio of sums, never an average of daily percentages.
//   • Counted means ELIGIBLE, COMPLETED or SKIPPED. OPTIONAL and NOT APPLICABLE add nothing to the
//     top or the bottom. A day with nothing counted adds nothing and has no percentage.
//   • A weekly activity adds one unit to the period holding the first day of its programme week,
//     once it is completed or that week is over.
//   • Period figures stop at the end of yesterday. Today is reported apart, as counts only.
//   • Percentage = credits x 100 / counted, rounded to the nearest whole number, halves up, and
//     offered only when at least 5 activities were counted. Below that: counts only.

import Foundation

// MARK: - Goal

/// What the programme puts first for her. Read from the onboarding answer she already gave
/// (`QuizContent` question "stage"); no second question is asked.
public enum ProgrammeGoalEmphasis: String, CaseIterable, Sendable {
    case understandMyCycle, prepareForPregnancy, tryingToConceive

    /// Maps the stored "stage" answer. `exploring` is understanding her cycle, `preparing` is
    /// preparing, `trying` is trying to conceive. `support`, no answer and any value this build
    /// does not know take the neutral default, understanding her cycle.
    public init(storedStage: String?) {
        switch storedStage {
        case "preparing": self = .prepareForPregnancy
        case "trying": self = .tryingToConceive
        default: self = .understandMyCycle
        }
    }

    /// The order tasks are listed in.
    var order: [ProgrammeTaskCategory] {
        switch self {
        case .understandMyCycle:
            return [.cycleCheckIn, .periodLog, .moodCheckIn, .energyCheckIn, .symptomCheckIn, .sleepCheckIn,
                    .hydrationCheckIn, .nutritionCheckIn, .supplementCheckIn, .lhTest, .phTest,
                    .programmeLesson, .fertilityKitEducation, .weeklyReview, .pregnancyTestRelatedAction]
        case .prepareForPregnancy:
            return [.nutritionCheckIn, .hydrationCheckIn, .sleepCheckIn, .supplementCheckIn, .moodCheckIn,
                    .energyCheckIn, .symptomCheckIn, .cycleCheckIn, .periodLog, .lhTest, .phTest,
                    .programmeLesson, .fertilityKitEducation, .weeklyReview, .pregnancyTestRelatedAction]
        case .tryingToConceive:
            return [.lhTest, .cycleCheckIn, .periodLog, .phTest, .moodCheckIn, .energyCheckIn,
                    .symptomCheckIn, .sleepCheckIn, .hydrationCheckIn, .nutritionCheckIn, .supplementCheckIn,
                    .programmeLesson, .fertilityKitEducation, .weeklyReview, .pregnancyTestRelatedAction]
        }
    }

    /// Optional activities offered in every week for this goal, on top of the week's schedule.
    var extraOptional: [ProgrammeTaskCategory] {
        switch self {
        case .understandMyCycle, .tryingToConceive: return [.cycleCheckIn, .periodLog]
        case .prepareForPregnancy: return []
        }
    }
}

// MARK: - Inputs

/// What the app already knows about one date. Read-only, assembled by the app from its existing
/// repositories. Test records are passed as "one exists", so no result value can reach a rule.
public struct ProgrammeDaySnapshot: Hashable, Sendable {
    /// The daily log for the date, if there is one.
    public var log: DailyLog?
    public var waterGoalMl: Int
    /// A pH reading (manual or scanned) exists somewhere in the date's programme week.
    public var phReadingExistsThisProgrammeWeek: Bool
    /// An ovulation-test result exists for the date.
    public var lhResultExistsForDate: Bool
    /// A period record covers the date.
    public var periodRecordExistsForDate: Bool
    public var cycleSettings: CycleSettings?
    /// The scan features (and with them ovulation-test results) exist in this build.
    public var scanFeaturesAvailable: Bool
    /// A pH reading can be logged. True wherever manual pH entry exists, which is every build.
    public var phLoggingAvailable: Bool
    /// Lesson ids with an explicit "read" record.
    public var completedLessonIDs: Set<String>
    /// Programme weeks with an explicit "reviewed" record.
    public var completedReviewWeeks: Set<Int>
    /// Her stored answer to the onboarding "supplements" question, if any.
    public var supplementsAnswer: String?
    /// Health-data consent is in force. When it is not, nothing is applicable.
    public var consentActive: Bool

    public init(
        log: DailyLog? = nil,
        waterGoalMl: Int = TrackingEngine.defaultWaterGoalMl,
        phReadingExistsThisProgrammeWeek: Bool = false,
        lhResultExistsForDate: Bool = false,
        periodRecordExistsForDate: Bool = false,
        cycleSettings: CycleSettings? = nil,
        scanFeaturesAvailable: Bool = false,
        phLoggingAvailable: Bool = true,
        completedLessonIDs: Set<String> = [],
        completedReviewWeeks: Set<Int> = [],
        supplementsAnswer: String? = nil,
        consentActive: Bool = true
    ) {
        self.log = log
        self.waterGoalMl = waterGoalMl
        self.phReadingExistsThisProgrammeWeek = phReadingExistsThisProgrammeWeek
        self.lhResultExistsForDate = lhResultExistsForDate
        self.periodRecordExistsForDate = periodRecordExistsForDate
        self.cycleSettings = cycleSettings
        self.scanFeaturesAvailable = scanFeaturesAvailable
        self.phLoggingAvailable = phLoggingAvailable
        self.completedLessonIDs = completedLessonIDs
        self.completedReviewWeeks = completedReviewWeeks
        self.supplementsAnswer = supplementsAnswer
        self.consentActive = consentActive
    }
}

// MARK: - Tasks

public enum ProgrammeTaskStatus: String, CaseIterable, Sendable {
    /// Counted and still open: no credit yet, and its day or week is not over.
    case eligible
    /// Counted, and its record exists. Credit is above 0 and at most 1.
    case completed
    /// Offered and acknowledged, never counted.
    case optional
    /// Counted, no credit, and its day or week is over. An internal word, never shown.
    case skipped
    /// Not relevant on this date. Not counted and not shown.
    case notApplicable
}

/// What a completion was read from. A derived completion names its record; an explicit one is a
/// record she made by reading a lesson or finishing a review, kept apart from health data.
public enum ProgrammeCompletionSource: String, CaseIterable, Sendable {
    case logMood, logEnergy, logSymptoms, logSleepMinutes, logWaterMl, logSupplements, logFoodGroups
    case cycleSettings, periodRecord, phReading, lhResult
    case explicitRecord
}

public enum ProgrammeNotApplicableReason: String, CaseIterable, Sendable {
    case featureUnavailable
    case noCycleSettings
    case outsidePredictedFertileWindow
    /// Her onboarding answer says the activity does not apply to her.
    case onboardingAnswer
    /// A weekly activity: it is counted in the programme week, not in a day.
    case countedOncePerProgrammeWeek
    /// Guidance to read, never something to do or to be counted.
    case educationOnly
    case consentWithdrawn
}

public struct ProgrammeTask: Identifiable, Hashable, Sendable {
    /// Stable within a day's list: the category's raw value.
    public let id: String
    public let category: ProgrammeTaskCategory
    public let status: ProgrammeTaskStatus
    /// From 0 to 1. Carried by every task; read by consistency only when `isCounted`.
    public let credit: Double
    /// Set when the task has any credit.
    public let completionSource: ProgrammeCompletionSource?
    /// Set when `status` is `notApplicable`.
    public let notApplicableReason: ProgrammeNotApplicableReason?
    public let destination: ProgrammeDestination

    /// In the consistency denominator.
    public var isCounted: Bool { status == .eligible || status == .completed || status == .skipped }
    /// Fully done, whether counted or optional.
    public var isDone: Bool { credit >= 1 }
}

/// One programme day's tasks.
public struct ProgrammeDayPlan: Hashable, Sendable {
    public let day: Int
    public let week: Int
    public let date: CalendarDate
    /// The day's list, in the goal's order. A weekly activity appears here as not applicable.
    public let tasks: [ProgrammeTask]
    /// The once-a-week activities, with the state of this programme week. Not part of the day.
    public let weeklyTasks: [ProgrammeTask]
    /// Food groups recorded on the date, out of `foodGroupTotal`. A fact for display: nothing is
    /// scored from it.
    public let foodGroupsRecorded: Int
    public let foodGroupTotal: Int

    /// Counted daily activities not yet fully done. The one number a reminder needs.
    public var openCountedTasks: Int { tasks.filter { $0.isCounted && !$0.isDone }.count }
}

// MARK: - Engine

public enum ProgrammeTaskEngine {

    /// The tasks for the programme day falling on `date`, or `nil` when that date is not a
    /// programme day (not started, before the start, after day 90, or stopped).
    public static func plan(
        on date: CalendarDate,
        state: ProgrammeState,
        today: CalendarDate,
        goal: ProgrammeGoalEmphasis,
        snapshot: ProgrammeDaySnapshot,
        content: ProgrammeContent = .draft
    ) -> ProgrammeDayPlan? {
        guard let day = ProgrammeCalendar.activeDay(state, on: date),
              let definition = content.day(day) else { return nil }
        return plan(for: definition, state: state, today: today, goal: goal, snapshot: snapshot)
    }

    /// The tasks for one day definition. `nil` when the programme has no start date.
    public static func plan(
        for definition: ProgrammeDayDefinition,
        state: ProgrammeState,
        today: CalendarDate,
        goal: ProgrammeGoalEmphasis,
        snapshot: ProgrammeDaySnapshot
    ) -> ProgrammeDayPlan? {
        guard let start = state.startedOn else { return nil }
        let date = ProgrammeCalendar.date(ofDay: definition.day, startedOn: start)
        let weekEnd = ProgrammeCalendar.date(
            ofDay: ProgrammeCalendar.dayRange(ofWeek: definition.week).upperBound, startedOn: start)
        let dayIsOver = date < today
        let weekIsOver = weekEnd < today

        var rules = definition.activities
        for extra in goal.extraOptional where !rules.contains(where: { $0.category == extra }) {
            rules.append(ProgrammeActivityRule(extra, .optional))
        }
        let lessonCategory: ProgrammeTaskCategory =
            definition.kind == .testGuidance ? .fertilityKitEducation : .programmeLesson
        rules.append(ProgrammeActivityRule(lessonCategory, .optional))
        if definition.kind == .weeklyReview || definition.kind == .progressReview {
            rules.append(ProgrammeActivityRule(.weeklyReview, .optional))
        }

        var tasks: [ProgrammeTask] = []
        var weeklyTasks: [ProgrammeTask] = []
        for rule in rules {
            let evaluated = task(rule, definition: definition, date: date, snapshot: snapshot,
                                 isOver: rule.category.isWeekly ? weekIsOver : dayIsOver)
            guard rule.category.isWeekly else { tasks.append(evaluated); continue }
            weeklyTasks.append(evaluated)
            tasks.append(evaluated.status == .notApplicable
                ? evaluated
                : make(rule.category, .notApplicable, reason: .countedOncePerProgrammeWeek))
        }

        let order = goal.order
        func rank(_ task: ProgrammeTask) -> Int { order.firstIndex(of: task.category) ?? order.count }
        let recorded = FoodGroup.allCases.filter { snapshot.log?.foodGroups.contains($0.rawValue) ?? false }.count

        return ProgrammeDayPlan(
            day: definition.day,
            week: definition.week,
            date: date,
            tasks: tasks.sorted { rank($0) < rank($1) },
            weeklyTasks: weeklyTasks.sorted { rank($0) < rank($1) },
            foodGroupsRecorded: recorded,
            foodGroupTotal: FoodGroup.allCases.count
        )
    }

    // MARK: Rules

    /// One activity on one date. This is the only place a record is read.
    private static func task(
        _ rule: ProgrammeActivityRule,
        definition: ProgrammeDayDefinition,
        date: CalendarDate,
        snapshot: ProgrammeDaySnapshot,
        isOver: Bool
    ) -> ProgrammeTask {
        let category = rule.category
        guard snapshot.consentActive else { return make(category, .notApplicable, reason: .consentWithdrawn) }

        let log = snapshot.log
        var standing = rule.standing
        let credit: Double
        let source: ProgrammeCompletionSource

        switch category {
        case .moodCheckIn:
            (credit, source) = (log?.mood != nil ? 1 : 0, .logMood)
        case .energyCheckIn:
            (credit, source) = (log?.energy != nil ? 1 : 0, .logEnergy)
        case .sleepCheckIn:
            // Any recorded sleep, including a stored 0. The length is not read.
            (credit, source) = (log?.sleepMinutes != nil ? 1 : 0, .logSleepMinutes)
        case .hydrationCheckIn:
            let goal = snapshot.waterGoalMl > 0 ? snapshot.waterGoalMl : TrackingEngine.defaultWaterGoalMl
            (credit, source) = (min(Double(max(log?.waterMl ?? 0, 0)) / Double(goal), 1), .logWaterMl)
        case .nutritionCheckIn:
            // Done or not done. Never how many groups, and never which.
            (credit, source) = ((log?.foodGroups.isEmpty ?? true) ? 0 : 1, .logFoodGroups)
        case .symptomCheckIn:
            // An empty set means both "none today" and "not looked", so this is never counted.
            standing = .optional
            (credit, source) = ((log?.symptoms.isEmpty ?? true) ? 0 : 1, .logSymptoms)
        case .supplementCheckIn:
            switch snapshot.supplementsAnswer {
            case "yes", "some": break
            case "no": return make(category, .notApplicable, reason: .onboardingAnswer)
            default: standing = .optional
            }
            (credit, source) = ((log?.supplements.isEmpty ?? true) ? 0 : 1, .logSupplements)
        case .cycleCheckIn:
            standing = .optional
            (credit, source) = (snapshot.cycleSettings != nil ? 1 : 0, .cycleSettings)
        case .periodLog:
            // The app never expects a period on a date, so this is never counted.
            standing = .optional
            (credit, source) = (snapshot.periodRecordExistsForDate ? 1 : 0, .periodRecord)
        case .lhTest:
            guard snapshot.scanFeaturesAvailable else { return make(category, .notApplicable, reason: .featureUnavailable) }
            guard let settings = snapshot.cycleSettings else { return make(category, .notApplicable, reason: .noCycleSettings) }
            let info = CycleEngine.cyclePhase(settings: settings, target: date)
            guard info.fertileWindow.contains(info.dayOfCycle) else {
                return make(category, .notApplicable, reason: .outsidePredictedFertileWindow)
            }
            (credit, source) = (snapshot.lhResultExistsForDate ? 1 : 0, .lhResult)
        case .phTest:
            guard snapshot.phLoggingAvailable else { return make(category, .notApplicable, reason: .featureUnavailable) }
            (credit, source) = (snapshot.phReadingExistsThisProgrammeWeek ? 1 : 0, .phReading)
        case .pregnancyTestRelatedAction:
            return make(category, .notApplicable, reason: .educationOnly)
        case .programmeLesson, .fertilityKitEducation:
            standing = .optional
            (credit, source) = (snapshot.completedLessonIDs.contains(definition.lesson.id) ? 1 : 0, .explicitRecord)
        case .weeklyReview:
            standing = .optional
            (credit, source) = (snapshot.completedReviewWeeks.contains(definition.week) ? 1 : 0, .explicitRecord)
        }

        let status: ProgrammeTaskStatus
        if standing == .optional {
            status = .optional
        } else if credit > 0 {
            status = .completed
        } else {
            status = isOver ? .skipped : .eligible
        }
        return make(category, status, credit: credit, source: credit > 0 ? source : nil)
    }

    private static func make(
        _ category: ProgrammeTaskCategory,
        _ status: ProgrammeTaskStatus,
        credit: Double = 0,
        source: ProgrammeCompletionSource? = nil,
        reason: ProgrammeNotApplicableReason? = nil
    ) -> ProgrammeTask {
        ProgrammeTask(id: category.rawValue, category: category, status: status, credit: credit,
                      completionSource: source, notApplicableReason: reason,
                      destination: destination(for: category))
    }

    /// Where each activity is done. Tracker check-ins share the daily log's editor.
    public static func destination(for category: ProgrammeTaskCategory) -> ProgrammeDestination {
        switch category {
        case .cycleCheckIn, .periodLog: return .cycle
        case .sleepCheckIn, .moodCheckIn, .energyCheckIn, .symptomCheckIn, .supplementCheckIn: return .dailyLog
        case .hydrationCheckIn: return .hydration
        case .nutritionCheckIn: return .nutrition
        case .programmeLesson: return .programmeLesson
        case .weeklyReview: return .weeklyReview
        case .lhTest: return .lhTest
        case .phTest: return .phTest
        case .pregnancyTestRelatedAction, .fertilityKitEducation: return .fertilityKitGuide
        }
    }
}
