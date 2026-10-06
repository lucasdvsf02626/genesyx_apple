import Foundation

// My Fertility Picture: one summary of what she has recorded and what the app estimates, assembled
// from plain values. Pure: today and the calendar are passed in, and nothing here reads a store.
//
// A row exists only when its data does. There is no placeholder and no zero. The one row not made
// from her data is the way to the pregnancy test screen: it is there whenever that screen is, so
// it says nothing about what she has saved on it. Nothing is judged and nothing is concluded from
// a value. Three things are kept in three places and never merged: the estimated fertile window
// (current cycle, labelled as an estimate), an ovulation test result (testing, the result of one
// test), and ovulation having happened, which the picture never states and has no row for. The
// intimacy field of the daily log is not read.

// MARK: - Input

/// Everything the picture is made from. The app fills it from its existing repositories.
public struct FertilityPictureInput: Sendable {
    public var today: CalendarDate
    /// Maps a record's `recordedAt` to her local date.
    public var calendar: Calendar
    /// Health-data consent is in force. When it is not, the picture holds nothing. It has to be
    /// stated: left out, it is taken as not in force.
    public var consentActive: Bool
    public var cycleSettings: CycleSettings?
    /// Her recorded cycle history, in start order, as `CycleHistory.cycles(from:)` returns it.
    public var cycles: [DerivedCycle]
    public var logsByDate: [CalendarDate: DailyLog]
    public var waterGoalMl: Int
    public var hydrationUnit: HydrationUnit
    public var glassMl: Int
    /// The readings she can see.
    public var phReadings: [PhReading]
    /// The results she can see.
    public var lhResults: [LhResult]
    /// The ovulation and pregnancy test screens exist in this build.
    public var scanFeaturesAvailable: Bool
    public var phLoggingAvailable: Bool
    public var programmeState: ProgrammeState
    /// From `ProgrammeConsistency.report`. Nil without a programme.
    public var consistency: ProgrammeConsistencyReport?
    public var content: ProgrammeContent

    public init(
        today: CalendarDate,
        calendar: Calendar,
        consentActive: Bool = false,
        cycleSettings: CycleSettings? = nil,
        cycles: [DerivedCycle] = [],
        logsByDate: [CalendarDate: DailyLog] = [:],
        waterGoalMl: Int = TrackingEngine.defaultWaterGoalMl,
        hydrationUnit: HydrationUnit = .glasses,
        glassMl: Int = HydrationUnit.mlPerGlass,
        phReadings: [PhReading] = [],
        lhResults: [LhResult] = [],
        scanFeaturesAvailable: Bool = false,
        phLoggingAvailable: Bool = true,
        programmeState: ProgrammeState = .notStarted,
        consistency: ProgrammeConsistencyReport? = nil,
        content: ProgrammeContent = .draft
    ) {
        self.today = today
        self.calendar = calendar
        self.consentActive = consentActive
        self.cycleSettings = cycleSettings
        self.cycles = cycles
        self.logsByDate = logsByDate
        self.waterGoalMl = waterGoalMl
        self.hydrationUnit = hydrationUnit
        self.glassMl = glassMl
        self.phReadings = phReadings
        self.lhResults = lhResults
        self.scanFeaturesAvailable = scanFeaturesAvailable
        self.phLoggingAvailable = phLoggingAvailable
        self.programmeState = programmeState
        self.consistency = consistency
        self.content = content
    }

    /// The local date of a record, on her calendar.
    func localDate(_ recordedAt: Date) -> CalendarDate {
        CalendarDate.today(calendar, now: recordedAt)
    }

    /// The readings every pH row and count is made from. A legacy urine reading is not one.
    var vaginalReadings: [PhReading] {
        phReadings.filter { $0.measurementType == .vaginal }
    }

    /// The ovulation test results that can be named or counted.
    var readableLhResults: [LhResult] {
        lhResults.filter { FertilityPictureCopy.shownLhClassifications.contains($0.classification) }
    }
}

// MARK: - Model

/// Where a row leads. Every row but one uses the programme's closed list. The pregnancy test screen
/// has no entry in that list (the programme never sends her there), so it is named here.
public enum FertilityPictureDestination: Hashable, Sendable {
    case programme(ProgrammeDestination)
    case pregnancyTestScreen
}

public enum FertilityPictureSectionKind: String, CaseIterable, Sendable {
    case currentCycle, testing, everydayHealth, programme, patterns
}

public enum FertilityPictureRowKind: String, CaseIterable, Sendable {
    case estimatedCycleDay, estimatedPhase, estimatedFertileWindow, recordedCycleDay
    case latestLhResult, latestPhReading, phReadingsLast30Days, pregnancyTestRecords
    case lastSleep, waterToday, foodGroupsToday, latestMood, latestEnergy, symptomsToday
    case programmeDay, programmeToday, programmeWeek, programmeOverall
    case pattern, stillLearning
}

public struct FertilityPictureRow: Identifiable, Hashable, Sendable {
    /// The kind's raw value. Pattern rows are numbered: the kind, a hyphen and the position.
    public let id: String
    public let kind: FertilityPictureRowKind
    public let label: String
    public let value: String?
    public let detail: String?
    /// When the record is from. The screen formats it.
    public let date: CalendarDate?
    /// The estimated fertile window only.
    public let dateRange: ClosedRange<CalendarDate>?
    /// Pattern rows only.
    public let evidenceLevel: ProgrammeEvidenceLevel?
    public let destination: FertilityPictureDestination

    init(
        _ kind: FertilityPictureRowKind,
        id: String? = nil,
        label: String,
        value: String? = nil,
        detail: String? = nil,
        date: CalendarDate? = nil,
        dateRange: ClosedRange<CalendarDate>? = nil,
        evidenceLevel: ProgrammeEvidenceLevel? = nil,
        destination: FertilityPictureDestination
    ) {
        self.id = id ?? kind.rawValue
        self.kind = kind
        self.label = label
        self.value = value
        self.detail = detail
        self.date = date
        self.dateRange = dateRange
        self.evidenceLevel = evidenceLevel
        self.destination = destination
    }
}

public struct FertilityPictureSection: Identifiable, Hashable, Sendable {
    public let kind: FertilityPictureSectionKind
    public let title: String
    public let note: String?
    /// Never empty.
    public let rows: [FertilityPictureRow]

    public var id: String { kind.rawValue }
}

public struct FertilityPicture: Hashable, Sendable {
    /// In the order of `FertilityPictureSectionKind`. A section with no rows is absent.
    public let sections: [FertilityPictureSection]
    /// Consent is not in force, so nothing was assembled.
    public let isWithheldForConsent: Bool

    /// Every string the picture would show, for the copy guard.
    public var surfaces: [String] {
        sections.flatMap { section in
            [section.title] + [section.note].compactMap { $0 }
                + section.rows.flatMap { [$0.label] + [$0.value, $0.detail].compactMap { $0 } }
        }
    }
}

// MARK: - Assembly

public enum FertilityPictureLogic {

    /// How far back "recent" reaches, in calendar days ending today.
    public static let recentDays = 30

    public static func picture(_ input: FertilityPictureInput) -> FertilityPicture {
        // Existing screens keep showing what is on the phone after consent is withdrawn. This
        // summary is new processing, so it holds nothing.
        guard input.consentActive else { return FertilityPicture(sections: [], isWithheldForConsent: true) }

        let cycle = currentCycleRows(input)
        let testing = testingRows(input)
        let sections = [
            section(.currentCycle, title: FertilityPictureCopy.currentCycleTitle,
                    note: cycle.contains { $0.kind == .estimatedCycleDay } ? FertilityPictureCopy.estimateNote : nil,
                    rows: cycle),
            section(.testing, title: FertilityPictureCopy.testingTitle,
                    note: testing.contains { $0.kind == .latestLhResult } ? LhScanCopy.resultNote : nil,
                    rows: testing),
            section(.everydayHealth, title: FertilityPictureCopy.everydayHealthTitle, rows: everydayHealthRows(input)),
            section(.programme, title: FertilityPictureCopy.programmeTitle, rows: programmeRows(input)),
            section(.patterns, title: FertilityPictureCopy.patternsTitle, rows: patternRows(input)),
        ]
        return FertilityPicture(sections: sections.compactMap { $0 }, isWithheldForConsent: false)
    }

    private static func section(
        _ kind: FertilityPictureSectionKind,
        title: String,
        note: String? = nil,
        rows: [FertilityPictureRow]
    ) -> FertilityPictureSection? {
        rows.isEmpty ? nil : FertilityPictureSection(kind: kind, title: title, note: note, rows: rows)
    }

    // MARK: Current cycle

    /// The estimate from her settings and the count from her recorded history are separate rows.
    /// They can show different days, and neither replaces the other.
    private static func currentCycleRows(_ input: FertilityPictureInput) -> [FertilityPictureRow] {
        var rows: [FertilityPictureRow] = []
        let cycleScreen: FertilityPictureDestination = .programme(.cycle)

        if let settings = input.cycleSettings {
            let info = CycleEngine.cyclePhase(settings: settings, target: input.today)
            rows.append(FertilityPictureRow(
                .estimatedCycleDay, label: FertilityPictureCopy.estimatedCycleDay,
                value: LhScanCopy.cycleDayLabel(info.dayOfCycle), destination: cycleScreen))
            if let phase = CycleContent.phaseLabel[info.phase] {
                rows.append(FertilityPictureRow(
                    .estimatedPhase, label: FertilityPictureCopy.estimatedPhase, value: phase, destination: cycleScreen))
            }
            // A window that would start before day 1 comes from settings outside the supported
            // range. Nothing is made up in its place.
            let window = info.fertileWindow
            if window.startDay >= 1 {
                // Once this cycle's window has passed, the next cycle's is the one still to come.
                let shift = info.dayOfCycle > window.endDay ? settings.cycleLength : 0
                let cycleStart = input.today.minusDays(info.dayOfCycle - 1).plusDays(shift)
                rows.append(FertilityPictureRow(
                    .estimatedFertileWindow, label: FertilityPictureCopy.estimatedFertileWindow,
                    dateRange: cycleStart.plusDays(window.startDay - 1)...cycleStart.plusDays(window.endDay - 1),
                    destination: cycleScreen))
            }
        }

        // A cycle opened by the seeded record was not recorded by her, so it is not shown as one.
        if let cycle = CycleHistory.cycle(containing: input.today, in: input.cycles), cycle.source == .recorded,
           let day = CycleHistory.cycleDay(on: input.today, in: input.cycles) {
            rows.append(FertilityPictureRow(
                .recordedCycleDay, label: FertilityPictureCopy.recordedCycleDay,
                value: LhScanCopy.cycleDayLabel(day), date: cycle.start, destination: cycleScreen))
        }
        return rows
    }

    // MARK: Testing

    private static func testingRows(_ input: FertilityPictureInput) -> [FertilityPictureRow] {
        var rows: [FertilityPictureRow] = []

        // The classification's title and the date. Never a signal, a ratio, a confidence or the
        // cycle day saved with the result.
        if input.scanFeaturesAvailable,
           let latest = input.readableLhResults.max(by: { ($0.recordedAt, $0.id) < ($1.recordedAt, $1.id) }) {
            rows.append(FertilityPictureRow(
                .latestLhResult, label: FertilityPictureCopy.latestLhResult,
                value: LhScanCopy.title(for: latest.classification), date: input.localDate(latest.recordedAt),
                destination: .programme(.lhTest)))
        }

        // The number and its band label, as the pH screen shows them. No sentence about either.
        let readings = input.vaginalReadings
        if input.phLoggingAvailable,
           let latest = readings.max(by: { ($0.recordedAt, $0.id) < ($1.recordedAt, $1.id) }) {
            let phScreen: FertilityPictureDestination = .programme(.phTest)
            rows.append(FertilityPictureRow(
                .latestPhReading, label: FertilityPictureCopy.latestPhReading,
                value: FertilityPictureCopy.phValue(latest.phValue), detail: PhStatus.classify(latest.phValue).label,
                date: input.localDate(latest.recordedAt), destination: phScreen))
            // No count is shown when none falls in the recent days: there is no row for nothing.
            let recent = input.today.minusDays(recentDays - 1)...input.today
            let count = readings.filter { recent.contains(input.localDate($0.recordedAt)) }.count
            if count > 0 {
                rows.append(FertilityPictureRow(
                    .phReadingsLast30Days, label: FertilityPictureCopy.phReadingsRecent, value: String(count),
                    destination: phScreen))
            }
        }

        // The row says only that the screen can be opened: no result, no count, no date, and no
        // wording of its own. It is there whenever the screen is, as the screen's own button is:
        // shown only once a result is saved, the row itself would say that she has taken a test.
        if input.scanFeaturesAvailable {
            rows.append(FertilityPictureRow(
                .pregnancyTestRecords, label: HcgScanCopy.cardTitle, detail: HcgScanCopy.showHistory,
                destination: .pregnancyTestScreen))
        }
        return rows
    }

    // MARK: Everyday health

    private static func everydayHealthRows(_ input: FertilityPictureInput) -> [FertilityPictureRow] {
        var rows: [FertilityPictureRow] = []
        let today = input.logsByDate[input.today]
        let dailyLog: FertilityPictureDestination = .programme(.dailyLog)

        /// The most recent of the recent days whose log holds this field.
        func latest<Value>(_ field: (DailyLog) -> Value?) -> (date: CalendarDate, value: Value)? {
            for daysAgo in 0..<recentDays {
                let date = input.today.minusDays(daysAgo)
                if let value = input.logsByDate[date].flatMap(field) { return (date, value) }
            }
            return nil
        }

        // A stored 0 is a night she entered, so it is shown.
        if let sleep = latest({ $0.sleepMinutes }) {
            rows.append(FertilityPictureRow(
                .lastSleep, label: FertilityPictureCopy.lastSleep,
                value: SleepInsightLogic.durationLabel(sleep.value), date: sleep.date, destination: dailyLog))
        }
        if let water = today?.waterMl, water > 0 {
            let goal = input.waterGoalMl > 0 ? input.waterGoalMl : TrackingEngine.defaultWaterGoalMl
            rows.append(FertilityPictureRow(
                .waterToday, label: FertilityPictureCopy.waterToday,
                value: HydrationFormat.progress(ml: water, goalMl: goal, unit: input.hydrationUnit, glassMl: input.glassMl),
                destination: .programme(.hydration)))
        }
        // How many of the six groups she recorded: a fact, never a share and never a mark.
        let groups = NutritionDaySignal.knownFoodGroups(today?.foodGroups ?? [])
        if groups > 0, let line = NutritionDaySignal.summaryLine(supplements: 0, foodGroups: groups) {
            rows.append(FertilityPictureRow(
                .foodGroupsToday, label: FertilityPictureCopy.foodGroups, value: line, destination: .programme(.nutrition)))
        }
        if let mood = latest({ $0.mood }) {
            rows.append(FertilityPictureRow(
                .latestMood, label: FertilityPictureCopy.latestMood, value: mood.value.label, date: mood.date,
                destination: dailyLog))
        }
        if let energy = latest({ $0.energy }) {
            rows.append(FertilityPictureRow(
                .latestEnergy, label: FertilityPictureCopy.latestEnergy,
                value: FertilityPictureCopy.energyLabel(energy.value), date: energy.date, destination: dailyLog))
        }
        if let symptoms = today?.symptoms, !symptoms.isEmpty {
            rows.append(FertilityPictureRow(
                .symptomsToday, label: FertilityPictureCopy.symptomsToday, value: String(symptoms.count),
                destination: dailyLog))
        }
        return rows
    }

    // MARK: Programme

    private static func programmeRows(_ input: FertilityPictureInput) -> [FertilityPictureRow] {
        var rows: [FertilityPictureRow] = []
        let progress: FertilityPictureDestination = .programme(.programmeProgress)

        switch ProgrammeCalendar.position(input.programmeState, on: input.today) {
        case .active(let day, _, let phase):
            rows.append(FertilityPictureRow(
                .programmeDay, label: FertilityPictureCopy.programmeDay,
                value: FertilityPictureCopy.dayOfProgramme(day), detail: input.content.phaseTitles[phase],
                destination: progress))
            if let today = input.consistency?.today, today.total > 0 {
                rows.append(FertilityPictureRow(
                    .programmeToday, label: FertilityPictureCopy.today,
                    value: FertilityPictureCopy.activitiesCompletedToday(today.completed, of: today.total),
                    destination: progress))
            }
            if let week = input.consistency?.week,
               let row = consistencyRow(.programmeWeek, label: FertilityPictureCopy.thisProgrammeWeek, week) {
                rows.append(row)
            }
        case .completed:
            rows.append(FertilityPictureRow(
                .programmeDay, label: FertilityPictureCopy.programmeDay,
                value: FertilityPictureCopy.programmeCompleted, destination: progress))
            if let programme = input.consistency?.programme,
               let row = consistencyRow(.programmeOverall, label: FertilityPictureCopy.programmeConsistency, programme) {
                rows.append(row)
            }
        case .notStarted, .beforeStart, .stopped:
            break
        }
        return rows
    }

    /// A consistency figure as the calculator gave it, in the words the Programme Reviews state
    /// the same figure in: the percentage with the counts it came from beside it, partly completed
    /// activities included; the counts alone where the percentage is withheld or comes to nought
    /// (a little credit over many activities rounds to nought, and that is never shown); and no
    /// row where nothing was counted, or where activities were counted and none has any credit.
    /// The reviews have no line for that figure either: a missed week is not shown as a nought.
    private static func consistencyRow(
        _ kind: FertilityPictureRowKind,
        label: String,
        _ figure: ProgrammeConsistencyFigure
    ) -> FertilityPictureRow? {
        guard figure.counted > 0, !figure.nothingRecorded else { return nil }
        let counts = ProgrammeReviewCopy.activitiesCompleted(
            figure.completed, of: figure.counted, partlyCompleted: figure.partlyCompleted)
        let destination: FertilityPictureDestination = .programme(.programmeProgress)
        guard let percentage = figure.percentage, percentage > 0 else {
            return FertilityPictureRow(kind, label: label, value: counts, destination: destination)
        }
        return FertilityPictureRow(
            kind, label: label, value: ProgrammeReviewCopy.percentage(percentage), detail: counts,
            destination: destination)
    }

    // MARK: Patterns

    /// Each supported statement, then the owner's sentence once, in place of what cannot yet be
    /// said across cycles.
    private static func patternRows(_ input: FertilityPictureInput) -> [FertilityPictureRow] {
        var rows = FertilityPicturePatterns.statements(input).enumerated().map { index, statement in
            FertilityPictureRow(
                .pattern, id: FertilityPictureRowKind.pattern.rawValue + "-" + String(index),
                label: ProgrammeEvidenceCopy.title(for: statement.level), value: statement.text,
                evidenceLevel: statement.level, destination: .programme(.insights))
        }
        if FertilityPicturePatterns.isStillLearning(input) {
            rows.append(FertilityPictureRow(
                .stillLearning, label: ProgrammeEvidenceCopy.title(for: .crossCyclePattern),
                value: ProgrammeEvidenceCopy.stillLearning, destination: .programme(.dailyLog)))
        }
        return rows
    }
}
