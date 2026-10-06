import Foundation

// The Weekly Programme Review and the 90-Day Review. Pure and synchronous: every date is passed in
// and every number is counted again from the input. Nothing here is a second calculator:
//
//   • Consistency figures come from `ProgrammeConsistency`, called on the plans as they are.
//   • Recorded days, water, mood and energy come from `WeeklySummaryLogic`, called once for each
//     programme week with that week's first date.
//   • Nutrition check-ins come from `DietPlanFacts`, as a number of days and nothing more.
//   • Sleep, symptoms and lessons are read from the plans, where the task engine has already read
//     the record.
//
// A review states counts. It never calls a count high or low, a count of nought is left out
// instead of being shown, and the nutrition check-in is never given a percentage or ranked.

public enum ProgrammeReviewLogic {

    /// A routine is named as strongest only from this percentage.
    public static let strongestRoutineMinimumPercentage = 50
    /// Days on the water goal in one week before a weekly review mentions them.
    public static let waterGoalDaysWorthNoticing = 4

    // MARK: Availability

    /// The programme weeks that have a review on `today`: every week that has ended, for good.
    /// With a stop date, only the weeks that ended before it.
    public static func availableWeeks(state: ProgrammeState, today: CalendarDate) -> [Int] {
        guard let start = state.startedOn else { return [] }
        return (1...ProgrammeCalendar.totalWeeks).filter { week in
            let last = ProgrammeCalendar.date(
                ofDay: ProgrammeCalendar.dayRange(ofWeek: week).upperBound, startedOn: start)
            return last < today && (state.stoppedOn.map { last < $0 } ?? true)
        }
    }

    /// From day 91, and not for a programme she left.
    public static func isNinetyDayReviewAvailable(state: ProgrammeState, today: CalendarDate) -> Bool {
        if case .completed = ProgrammeCalendar.position(state, on: today) { return true }
        return false
    }

    // MARK: The weekly review

    /// The review of a programme week, or `nil` when that week has no review yet, does not exist,
    /// or consent is not in force.
    public static func weekly(week: Int, input: ProgrammeReviewInput) -> ProgrammeWeeklyReview? {
        guard input.consentActive, let start = input.state.startedOn,
              availableWeeks(state: input.state, today: input.today).contains(week) else { return nil }
        let input = scoped(input, start: start)
        let days = ProgrammeCalendar.dayRange(ofWeek: week)
        let todayDay = ProgrammeCalendar.dayNumber(on: input.today, startedOn: start)
        let summary = weekSummary(week, start: start, input)
        let figure = ProgrammeConsistency.period(input.plans, days: days, todayDay: todayDay)
        let nutrition = DietPlanFacts.programmeWeek(
            week, state: input.state, today: input.today, logsByDate: input.logsByDate)
        let tracked = counts(days: days, summaries: [summary],
                             nutritionCheckIns: nutrition?.daysWithCheckIn ?? 0, start: start, input)

        // Each note has its own minimum. One that is not met is simply not made.
        var noticed: [ProgrammeEvidenceStatement] = []
        if summary.daysLogged == days.count {
            noticed.append(.init(level: .observation, text: ProgrammeReviewCopy.recordedEveryDay))
        }
        if summary.daysOnGoal >= waterGoalDaysWorthNoticing {
            noticed.append(.init(level: .observation,
                                 text: ProgrammeReviewCopy.waterGoalMostDays(summary.daysOnGoal)))
        }
        if week > 1 {
            // Days are set side by side only for two weeks of the same length: week 13 has six,
            // and six beside seven would read as a drop that is only the calendar.
            if let change = summary.deltas.daysLogged, summary.daysLogged > 0,
               days.count == ProgrammeCalendar.dayRange(ofWeek: week - 1).count {
                noticed.append(.init(level: .withinWeekTrend, text: ProgrammeReviewCopy.recordedDaysCompared(
                    thisWeek: summary.daysLogged, weekBefore: summary.daysLogged - change)))
            }
            let before = ProgrammeConsistency.period(
                input.plans, days: ProgrammeCalendar.dayRange(ofWeek: week - 1), todayDay: todayDay)
            if let thisWeek = shownPercentage(figure), let weekBefore = shownPercentage(before) {
                noticed.append(.init(level: .withinWeekTrend, text: ProgrammeReviewCopy.consistencyCompared(
                    thisWeek: thisWeek, weekBefore: weekBefore)))
            }
        }

        // The report of one week's plans is that week's figure for each activity.
        let strongest = leaders(ProgrammeConsistency.report(
            state: input.state, today: input.today, plans: input.plans.filter { $0.week == week }).categories)
        let phase = ProgrammeCalendar.phase(forDay: days.lowerBound)

        return ProgrammeWeeklyReview(
            week: week,
            phase: phase,
            phaseTitle: input.content.phaseTitles[phase],
            themeTitle: input.content.week(week)?.themeTitle,
            firstDate: ProgrammeCalendar.date(ofDay: days.lowerBound, startedOn: start),
            lastDate: ProgrammeCalendar.date(ofDay: days.upperBound, startedOn: start),
            headline: ProgrammeReviewCopy.weekComplete(week),
            consistency: figure,
            consistencyLines: lines(for: figure, nothingTracked: tracked.isEmpty),
            supportLine: hasNothingToShow(figure, tracked) ? ProgrammeReviewCopy.welcomeBack : nil,
            tracked: tracked,
            noticed: noticed,
            isStillLearning: noticed.isEmpty,
            strongestRoutine: strongest.count == 1 ? strongest.first : nil,
            nextFocus: nextFocus(after: week, input)
        )
    }

    // MARK: The 90-day review

    /// The review of the whole programme, or `nil` before day 91, for a programme she left, or
    /// when consent is not in force.
    public static func ninetyDay(_ input: ProgrammeReviewInput) -> ProgrammeNinetyDayReview? {
        guard input.consentActive, let start = input.state.startedOn,
              isNinetyDayReviewAvailable(state: input.state, today: input.today) else { return nil }
        let input = scoped(input, start: start)
        let days = 1...ProgrammeCalendar.totalDays
        let lastDate = ProgrammeCalendar.date(ofDay: days.upperBound, startedOn: start)
        let report = ProgrammeConsistency.report(state: input.state, today: input.today, plans: input.plans)
        let nutrition = DietPlanFacts.history(
            from: start, through: lastDate, today: input.today, logsByDate: input.logsByDate)
        let tracked = counts(
            days: days,
            summaries: (1...ProgrammeCalendar.totalWeeks).map { weekSummary($0, start: start, input) },
            nutritionCheckIns: nutrition.daysWithCheckIn, start: start, input)
        let strongest = leaders(report.categories)

        // A statement across cycles is repeated only when the recorded cycles allow one.
        let crossCycle = CycleHistory.canMakeCrossCycleStatement(input.cycles)
        let patterns = input.patterns.enumerated()
            .filter { crossCycle || $0.element.level < .crossCyclePattern }
            .sorted { ($0.element.level, $0.offset) < ($1.element.level, $1.offset) }
            .map(\.element)

        return ProgrammeNinetyDayReview(
            firstDate: start,
            lastDate: lastDate,
            headline: ProgrammeReviewCopy.ninetyDayTitle,
            tracked: tracked,
            consistency: report.programme.counted > 0 ? report.programme : nil,
            consistencyLines: lines(for: report.programme, nothingTracked: tracked.isEmpty),
            hydration: routine(.hydrationCheckIn, report.categories[.hydrationCheckIn]),
            sleep: routine(.sleepCheckIn, report.categories[.sleepCheckIn]),
            strongestRoutines: strongest,
            patterns: patterns,
            isStillLearning: !crossCycle,
            whatToContinue: strongest.compactMap { ProgrammeReviewCopy.continueWith($0.category) }
                + [ProgrammeReviewCopy.continueClosing],
            supportLine: hasNothingToShow(report.programme, tracked) ? ProgrammeReviewCopy.pickUpYourRoutine : nil
        )
    }

    // MARK: Dates in scope

    /// The input with its records cut down to the programme's own dates: day 1 to day 90, and
    /// never past today. Week 13 has six days, so the seventh date its summary reads is day 91;
    /// and the week before week 1 is before the programme. Neither may add anything.
    ///
    /// Called only for a review that exists, so today is always after the start date.
    private static func scoped(_ input: ProgrammeReviewInput, start: CalendarDate) -> ProgrammeReviewInput {
        let dates = start...min(ProgrammeCalendar.date(ofDay: ProgrammeCalendar.totalDays, startedOn: start), input.today)
        var scoped = input
        scoped.logsByDate = input.logsByDate.filter { dates.contains($0.key) }
        scoped.phReadingDates = input.phReadingDates.filter(dates.contains)
        scoped.lhResultDates = input.lhResultDates.filter(dates.contains)
        return scoped
    }

    // MARK: What was tracked

    /// The existing weekly aggregation, started on the programme week's first date.
    ///
    /// The pH dates go in as one placeholder 0 for each reading. The summary only asks whether a
    /// day's list is empty, to decide whether that day counts as recorded; the average it works
    /// out from the list is never read here.
    private static func weekSummary(_ week: Int, start: CalendarDate, _ input: ProgrammeReviewInput) -> WeeklySummary {
        WeeklySummaryLogic.summary(
            weekStart: ProgrammeCalendar.date(ofDay: ProgrammeCalendar.dayRange(ofWeek: week).lowerBound, startedOn: start),
            logsByDate: input.logsByDate,
            phValuesByDate: Dictionary(grouping: input.phReadingDates) { $0 }
                .mapValues { [Double](repeating: 0, count: $0.count) },
            goalMl: input.waterGoalMl > 0 ? input.waterGoalMl : TrackingEngine.defaultWaterGoalMl)
    }

    /// What was recorded on the given programme days, as counts in the order of the kinds.
    ///
    /// `summaries` holds one summary for each programme week those days make up, and the counts
    /// taken from them are sums over the weeks, so the thirteen weekly reviews add up to the
    /// 90-day review.
    private static func counts(
        days: ClosedRange<Int>,
        summaries: [WeeklySummary],
        nutritionCheckIns: Int,
        start: CalendarDate,
        _ input: ProgrammeReviewInput
    ) -> [ProgrammeReviewCount] {
        let dates = ProgrammeCalendar.date(ofDay: days.lowerBound, startedOn: start)
            ... ProgrammeCalendar.date(ofDay: days.upperBound, startedOn: start)
        let plans = input.plans.filter { days.contains($0.day) }
        func summed(_ value: (WeeklySummary) -> Int) -> Int { summaries.reduce(0) { $0 + value($1) } }
        func planDays(_ credited: (ProgrammeTask) -> Bool) -> Int {
            Set(plans.filter { $0.tasks.contains(where: credited) }.map(\.day)).count
        }

        let found: [ProgrammeReviewCount.Kind: Int] = [
            .daysRecorded: summed(\.daysLogged),
            .nutritionCheckIns: nutritionCheckIns,
            .waterDays: summed { $0.waterByDay.filter { $0 > 0 }.count },
            .waterGoalDays: summed(\.daysOnGoal),
            .sleepNights: planDays { $0.category == .sleepCheckIn && $0.credit > 0 },
            .moodCheckIns: summed { $0.moodTallies.reduce(0) { $0 + $1.count } },
            .energyCheckIns: summed { $0.energyTallies.reduce(0) { $0 + $1.count } },
            .symptomDays: planDays { $0.category == .symptomCheckIn && $0.credit > 0 },
            // A start she recorded herself. The one copied from her settings is not a record.
            .periodStarts: input.cycles.filter { $0.source == .recorded && dates.contains($0.start) }.count,
            .phReadings: input.phReadingDates.filter(dates.contains).count,
            .lhResults: input.lhResultDates.filter(dates.contains).count,
            .lessonsRead: planDays {
                ($0.category == .programmeLesson || $0.category == .fertilityKitEducation) && $0.isDone
            },
        ]
        return ProgrammeReviewCount.Kind.allCases.compactMap { kind in
            guard let count = found[kind], count > 0 else { return nil }
            return ProgrammeReviewCount(
                kind: kind, count: count,
                text: ProgrammeReviewCopy.tracked(kind, count, ofDays: days.count),
                destination: destination(for: kind))
        }
    }

    /// Where each kind of record is made.
    private static func destination(for kind: ProgrammeReviewCount.Kind) -> ProgrammeDestination {
        switch kind {
        case .daysRecorded, .sleepNights, .moodCheckIns, .energyCheckIns, .symptomDays: return .dailyLog
        case .nutritionCheckIns: return .nutrition
        case .waterDays, .waterGoalDays: return .hydration
        case .periodStarts: return .cycle
        case .phReadings: return .phTest
        case .lhResults: return .lhTest
        case .lessonsRead: return .programmeLesson
        }
    }

    // MARK: Figures in words

    /// A percentage a review will state: there is one, and it is above nought. A little credit
    /// over many activities still rounds to nought, and that is never shown.
    private static func shownPercentage(_ figure: ProgrammeConsistencyFigure) -> Int? {
        figure.percentage.flatMap { $0 > 0 ? $0 : nil }
    }

    /// Nothing counted: no line. Counted with no credit: the one neutral line, and only when
    /// nothing was tracked in the period either. The schedule leaves the nutrition check-in,
    /// symptoms, period starts and lessons uncounted, so a period can hold records and no credit;
    /// it then has no line, and is never said to have nothing recorded. Otherwise the counts,
    /// with the percentage in front of them when there is one.
    private static func lines(for figure: ProgrammeConsistencyFigure, nothingTracked: Bool = false) -> [String] {
        guard figure.counted > 0 else { return [] }
        if figure.nothingRecorded { return nothingTracked ? [ProgrammeReviewCopy.nothingRecorded] : [] }
        let counts = ProgrammeReviewCopy.activitiesCompleted(
            figure.completed, of: figure.counted, partlyCompleted: figure.partlyCompleted)
        return (shownPercentage(figure).map { [ProgrammeReviewCopy.percentage($0)] } ?? []) + [counts]
    }

    /// A fully missed period: no credit and nothing tracked. A record that no figure counts is
    /// still something to show.
    private static func hasNothingToShow(_ figure: ProgrammeConsistencyFigure, _ tracked: [ProgrammeReviewCount]) -> Bool {
        figure.credit == 0 && tracked.isEmpty
    }

    // MARK: Routines

    /// An activity's figure under its name. `nil` when the activity has no name to go by, or its
    /// figure has no credit to state.
    private static func routine(
        _ category: ProgrammeTaskCategory,
        _ figure: ProgrammeConsistencyFigure?
    ) -> ProgrammeReviewRoutine? {
        guard let figure, figure.credit > 0, let name = ProgrammeReviewCopy.routineName(for: category) else { return nil }
        return ProgrammeReviewRoutine(category: category, name: name, figure: figure,
                                      text: ProgrammeReviewCopy.onOneLine(lines(for: figure)))
    }

    /// The activities that share the highest percentage, among those with a percentage of at least
    /// `strongestRoutineMinimumPercentage`, in the order of the category list. The nutrition
    /// check-in is never one of them: nutrition is a record, and a record is not ranked.
    private static func leaders(_ figures: [ProgrammeTaskCategory: ProgrammeConsistencyFigure]) -> [ProgrammeReviewRoutine] {
        let candidates = ProgrammeTaskCategory.allCases.filter { category in
            category != .nutritionCheckIn
                && (figures[category]?.percentage ?? 0) >= strongestRoutineMinimumPercentage
        }
        guard let highest = candidates.compactMap({ figures[$0]?.percentage }).max() else { return [] }
        return candidates.filter { figures[$0]?.percentage == highest }.compactMap { routine($0, figures[$0]) }
    }

    // MARK: Next week

    /// The following week's theme and nutrition focus, and the first three of its scheduled
    /// activities in her goal's order. An activity the plans already show as not for her (the
    /// feature is absent, her onboarding answer rules it out, or it is reading only) is left out.
    /// The goal changes the order and no wording.
    private static func nextFocus(after week: Int, _ input: ProgrammeReviewInput) -> ProgrammeReviewNextFocus? {
        guard let next = input.content.week(week + 1) else { return nil }
        let notForHer: Set<ProgrammeNotApplicableReason> = [.featureUnavailable, .onboardingAnswer, .educationOnly]
        let leftOut = Set(input.plans.flatMap { $0.tasks + $0.weeklyTasks }
            .filter { $0.notApplicableReason.map(notForHer.contains) ?? false }
            .map(\.category))
        let order = input.goal.order
        func rank(_ category: ProgrammeTaskCategory) -> Int { order.firstIndex(of: category) ?? order.count }
        let names = next.activities.map(\.category)
            .filter { !leftOut.contains($0) }
            .sorted { rank($0) < rank($1) }
            .compactMap(ProgrammeReviewCopy.routineName(for:))
        return ProgrammeReviewNextFocus(
            week: next.number,
            themeTitle: next.themeTitle,
            purpose: next.purpose,
            nutritionFocusTitle: next.nutritionFocus.title,
            leadingActivities: Array(names.prefix(3)))
    }
}
