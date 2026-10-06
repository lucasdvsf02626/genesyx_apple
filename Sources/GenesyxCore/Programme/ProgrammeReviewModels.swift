import Foundation

// The Weekly Programme Review and the 90-Day Review: value types only. The rules that fill them
// are in `ProgrammeReviewLogic.swift` and every sentence is in `ProgrammeReviewCopy.swift`.
//
// A review holds counts, consistency figures and wording. It cannot hold a test value or a
// classification, because only the dates of readings and results come in, and nothing about a
// pregnancy test comes in at all.

// MARK: - Input

/// Everything a review is worked out from, as plain values. The app fills it from the plan service
/// and its repositories; a review never sees a repository.
public struct ProgrammeReviewInput: Sendable {
    public var state: ProgrammeState
    public var today: CalendarDate
    /// Changes the order of next week's activities and nothing else.
    public var goal: ProgrammeGoalEmphasis
    /// Health-data consent is in force. When it is not, there is no review.
    public var consentActive: Bool
    /// One plan per programme day from day 1 to today, as the task engine produced them.
    public var plans: [ProgrammeDayPlan]
    public var logsByDate: [CalendarDate: DailyLog]
    public var waterGoalMl: Int
    /// One entry per visible pH reading: its date and nothing else.
    public var phReadingDates: [CalendarDate]
    /// One entry per visible ovulation-test result: its date and nothing else. Empty in a build
    /// without the scan features, where a count would lead to a screen that is not there.
    public var lhResultDates: [CalendarDate]
    public var cycles: [DerivedCycle]
    /// Pattern statements from `FertilityPicturePatterns`. Read by the 90-day review only, which
    /// repeats them as they are: they speak about the day they were produced for, not day 90.
    public var patterns: [ProgrammeEvidenceStatement]
    public var content: ProgrammeContent

    public init(
        state: ProgrammeState,
        today: CalendarDate,
        goal: ProgrammeGoalEmphasis = .understandMyCycle,
        consentActive: Bool = true,
        plans: [ProgrammeDayPlan] = [],
        logsByDate: [CalendarDate: DailyLog] = [:],
        waterGoalMl: Int = TrackingEngine.defaultWaterGoalMl,
        phReadingDates: [CalendarDate] = [],
        lhResultDates: [CalendarDate] = [],
        cycles: [DerivedCycle] = [],
        patterns: [ProgrammeEvidenceStatement] = [],
        content: ProgrammeContent = .draft
    ) {
        self.state = state
        self.today = today
        self.goal = goal
        self.consentActive = consentActive
        self.plans = plans
        self.logsByDate = logsByDate
        self.waterGoalMl = waterGoalMl
        self.phReadingDates = phReadingDates
        self.lhResultDates = lhResultDates
        self.cycles = cycles
        self.patterns = patterns
        self.content = content
    }
}

// MARK: - Parts of a review

/// One line of "what you tracked": how many times something was recorded, and where it is recorded.
public struct ProgrammeReviewCount: Identifiable, Hashable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case daysRecorded, nutritionCheckIns, waterDays, waterGoalDays, sleepNights
        case moodCheckIns, energyCheckIns, symptomDays, periodStarts, phReadings, lhResults, lessonsRead
    }

    public let kind: Kind
    /// Always 1 or more: a count of nought is left out, never shown.
    public let count: Int
    public let text: String
    public let destination: ProgrammeDestination

    public var id: String { kind.rawValue }
}

/// One activity's consistency, named.
public struct ProgrammeReviewRoutine: Hashable, Sendable {
    public let category: ProgrammeTaskCategory
    public let name: String
    public let figure: ProgrammeConsistencyFigure
    /// The figure in words, on one line.
    public let text: String
}

/// What the following programme week is about.
public struct ProgrammeReviewNextFocus: Hashable, Sendable {
    public let week: Int
    public let themeTitle: String
    public let purpose: String
    public let nutritionFocusTitle: String
    /// Up to three routine names from that week's schedule, in her goal's order.
    public let leadingActivities: [String]
}

// MARK: - The reviews

/// The review of one programme week that has ended.
public struct ProgrammeWeeklyReview: Hashable, Sendable {
    public let week: Int
    /// The phase the week's first day falls in.
    public let phase: ProgrammePhase
    public let phaseTitle: String?
    public let themeTitle: String?
    public let firstDate: CalendarDate
    public let lastDate: CalendarDate
    public let headline: String
    public let consistency: ProgrammeConsistencyFigure
    /// The figure in words, and what the screen shows of it. Empty when nothing was counted in
    /// the week, and when nothing counted was done but `tracked` holds other records.
    public let consistencyLines: [String]
    /// Set for a fully missed week: no credit and nothing in `tracked`.
    public let supportLine: String?
    public let tracked: [ProgrammeReviewCount]
    /// Levels 1 and 2 only: an observation, or a trend inside or beside this one week.
    public let noticed: [ProgrammeEvidenceStatement]
    /// `noticed` is empty: the screen shows `ProgrammeEvidenceCopy.stillLearning` in its place.
    public let isStillLearning: Bool
    public let strongestRoutine: ProgrammeReviewRoutine?
    /// `nil` for week 13, which has no following week.
    public let nextFocus: ProgrammeReviewNextFocus?

    /// Every string this review carries, for the guard tests. Section titles are fixed strings in
    /// `ProgrammeReviewCopy`, and the screen formats the dates.
    public var surfaces: [String] {
        var all = [headline] + [phaseTitle, themeTitle, supportLine].compactMap { $0 }
        all += consistencyLines + tracked.map(\.text)
        all += isStillLearning ? [ProgrammeEvidenceCopy.stillLearning] : noticed.map(\.text)
        if let strongestRoutine { all += [strongestRoutine.name, strongestRoutine.text] }
        if let nextFocus {
            all += [nextFocus.themeTitle, nextFocus.purpose, nextFocus.nutritionFocusTitle] + nextFocus.leadingActivities
        }
        return all
    }
}

/// The review of the whole programme, from day 91.
public struct ProgrammeNinetyDayReview: Hashable, Sendable {
    /// Day 1.
    public let firstDate: CalendarDate
    /// Day 90.
    public let lastDate: CalendarDate
    public let headline: String
    public let tracked: [ProgrammeReviewCount]
    /// `nil` when nothing was counted.
    public let consistency: ProgrammeConsistencyFigure?
    /// As for a week: empty when nothing counted was done but `tracked` holds other records.
    public let consistencyLines: [String]
    /// The hydration check-in over the programme, when it was counted and has something to state.
    public let hydration: ProgrammeReviewRoutine?
    /// The sleep check-in over the programme, on the same terms.
    public let sleep: ProgrammeReviewRoutine?
    /// Every routine that shares the highest percentage. Empty when none qualifies.
    public let strongestRoutines: [ProgrammeReviewRoutine]
    /// Supported statements, lowest level first. Level 4 only with enough recorded cycles. Can be
    /// empty while `isStillLearning` is false: the screen then has no Patterns section to show.
    public let patterns: [ProgrammeEvidenceStatement]
    /// Nothing can be said across cycles yet: the screen shows `ProgrammeEvidenceCopy.stillLearning`
    /// beside whatever `patterns` holds.
    public let isStillLearning: Bool
    public let whatToContinue: [String]
    /// Set for a fully missed programme: no credit and nothing in `tracked`.
    public let supportLine: String?

    /// Every string this review carries, for the guard tests. Section titles are fixed strings in
    /// `ProgrammeReviewCopy`, and the screen formats the dates.
    public var surfaces: [String] {
        var all = [headline] + tracked.map(\.text) + consistencyLines
        for routine in [hydration, sleep].compactMap({ $0 }) + strongestRoutines {
            all += [routine.name, routine.text]
        }
        all += patterns.map(\.text)
        if isStillLearning { all.append(ProgrammeEvidenceCopy.stillLearning) }
        return all + whatToContinue + [supportLine].compactMap { $0 }
    }
}
