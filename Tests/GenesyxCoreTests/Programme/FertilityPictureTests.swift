import XCTest
@testable import GenesyxCore

/// Shared set-up for the three My Fertility Picture test files.
enum FertilityPictureFixtures {

    static let today = CalendarDate(2026, 6, 23)

    static let utc = calendar(secondsFromGMT: 0)
    /// Two hours ahead of UTC all year, so a late evening and the small hours fall either side of
    /// its midnight.
    static let plusTwo = calendar(secondsFromGMT: 2 * 60 * 60)

    private static func calendar(secondsFromGMT: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: secondsFromGMT)!
        return calendar
    }

    /// A moment on a calendar date, as that calendar's wall clock reads it.
    static func instant(_ date: CalendarDate, hour: Int = 12, minute: Int = 0, in calendar: Calendar = utc) -> Date {
        calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day, hour: hour, minute: minute))!
    }

    /// Consent given, nothing recorded, no cycle settings, no programme.
    static func input(today: CalendarDate = today, calendar: Calendar = utc) -> FertilityPictureInput {
        FertilityPictureInput(today: today, calendar: calendar, consentActive: true)
    }

    /// Cycles of these lengths, earliest first, then an open cycle starting on `latestStart`. Every
    /// start is one she recorded, unless `seedingFirst` marks the earliest as the seeded record.
    static func cycles(lengths: [Int] = [], latestStart: CalendarDate, seedingFirst: Bool = false) -> [DerivedCycle] {
        var starts = [latestStart]
        for length in lengths.reversed() { starts.insert(starts[0].minusDays(length), at: 0) }
        return CycleHistory.cycles(from: starts.enumerated().map { index, start in
            StoredPeriodRecord(
                period: PeriodRecord(startDate: start, source: seedingFirst && index == 0 ? .seeded : .recorded),
                updatedAt: Date(timeIntervalSince1970: 0), pendingSync: false)
        })
    }

    static func ph(_ value: Double, daysAgo: Int, type: PhMeasurementType = .vaginal) -> PhReading {
        PhReading(id: "ph-\(daysAgo)-\(type.rawValue)", phValue: value, recordedAt: instant(today.minusDays(daysAgo)),
                  measurementType: type)
    }

    static func lh(
        _ classification: LhClassification,
        daysAgo: Int,
        hour: Int = 12,
        id: String? = nil,
        cycleDay: Int? = nil,
        scan: LhScanMeasurement? = nil
    ) -> LhResult {
        LhResult(id: id ?? "lh-\(daysAgo)-\(hour)", recordedAt: instant(today.minusDays(daysAgo), hour: hour),
                 cycleDay: cycleDay, classification: classification, scan: scan)
    }

    /// A scan whose every number is easy to find again if it leaks into a string.
    static let measurement = LhScanMeasurement(
        testSignal: 0.7341, controlSignal: 0.3912, testControlRatio: 1.8766, confidence: 0.9123,
        scannerVersion: "9.8.7", configurationID: "cfg-55", configurationVersion: "4")

    /// A log on each of these days, holding a mood and nothing else.
    static func logs(daysAgo: [Int]) -> [CalendarDate: DailyLog] {
        Dictionary(uniqueKeysWithValues: daysAgo.map { (today.minusDays($0), DailyLog(mood: .good)) })
    }

    /// A figure from the real calculator: `completed` activities done, one more for each credit in
    /// `partly` (water short of its goal), and the rest of `counted` left undone on days that are
    /// over.
    static func figure(completed: Int, partly: [Double] = [], of counted: Int) -> ProgrammeConsistencyFigure {
        func task(credit: Double) -> ProgrammeTask {
            ProgrammeTask(id: ProgrammeTaskCategory.hydrationCheckIn.rawValue, category: .hydrationCheckIn,
                          status: credit > 0 ? .completed : .skipped, credit: credit, completionSource: nil,
                          notApplicableReason: nil, destination: .hydration)
        }
        let credits = Array(repeating: 1.0, count: completed) + partly
            + Array(repeating: 0.0, count: counted - completed - partly.count)
        return ProgrammeConsistency.figure(for: credits.map(task))
    }

    static func report(
        today: ProgrammeTodayProgress? = nil,
        week: ProgrammeConsistencyFigure? = nil,
        programme: ProgrammeConsistencyFigure? = nil
    ) -> ProgrammeConsistencyReport {
        let nothing = ProgrammeConsistency.figure(for: [])
        return ProgrammeConsistencyReport(today: today, week: week ?? nothing, trailing30Days: nothing, phases: [:],
                                          programme: programme ?? nothing, categories: [:])
    }

    /// Everything recorded. Estimated cycle day 18 of a 28-day cycle; four recorded starts, the
    /// latest 17 days ago, closing cycles of 27, 30 and 28 days; a log on each of the last twelve
    /// days; four pH readings and three ovulation test results in the current cycle; the scan
    /// features in the build; programme day 23.
    static var rich: FertilityPictureInput {
        let start = today.minusDays(17)
        var input = self.input()
        input.cycleSettings = CycleSettings(lastPeriodDate: start, cycleLength: 28, periodLength: 5)
        input.cycles = cycles(lengths: [27, 30, 28], latestStart: start)
        input.logsByDate = Dictionary(uniqueKeysWithValues: (0..<12).map {
            (today.minusDays($0), DailyLog(mood: .good, energy: .normal, sleepMinutes: 445, waterMl: 1500))
        })
        input.logsByDate[today] = DailyLog(
            mood: .okay, energy: .high, symptoms: ["cramps", "headache"], sleepMinutes: 400, supplements: ["folate"],
            notes: "A note", waterMl: 500, foodGroups: ["vegetables", "fruit", "protein"])
        input.phReadings = [ph(4.7, daysAgo: 1), ph(4.2, daysAgo: 3), ph(4.4, daysAgo: 5), ph(5.3, daysAgo: 8),
                            ph(6.1, daysAgo: 2, type: .urine)]
        input.lhResults = [lh(.low, daysAgo: 9), lh(.low, daysAgo: 8),
                           lh(.positive, daysAgo: 7, cycleDay: 11, scan: measurement)]
        input.scanFeaturesAvailable = true
        input.programmeState = ProgrammeState(startedOn: today.minusDays(22))
        input.consistency = report(today: ProgrammeTodayProgress(completed: 2, partlyCompleted: 1, total: 5),
                                   week: figure(completed: 29, of: 37), programme: figure(completed: 60, of: 80))
        return input
    }

    /// A little recorded: a mood two days ago and one pH reading. No settings, no programme.
    static var sparse: FertilityPictureInput {
        var input = self.input()
        input.logsByDate = [today.minusDays(2): DailyLog(mood: .low)]
        input.phReadings = [ph(4.4, daysAgo: 4)]
        return input
    }
}

final class FertilityPictureTests: XCTestCase {

    private typealias F = FertilityPictureFixtures
    private let today = F.today

    private func input(_ change: (inout FertilityPictureInput) -> Void = { _ in }) -> FertilityPictureInput {
        var input = F.input()
        change(&input)
        return input
    }

    private func picture(_ input: FertilityPictureInput) -> FertilityPicture {
        FertilityPictureLogic.picture(input)
    }

    private func rows(_ input: FertilityPictureInput) -> [FertilityPictureRow] {
        picture(input).sections.flatMap(\.rows)
    }

    private func kinds(_ input: FertilityPictureInput) -> [FertilityPictureRowKind] {
        rows(input).map(\.kind)
    }

    private func row(_ kind: FertilityPictureRowKind, _ input: FertilityPictureInput) -> FertilityPictureRow? {
        rows(input).first { $0.kind == kind }
    }

    private func section(_ kind: FertilityPictureSectionKind, _ input: FertilityPictureInput) -> FertilityPictureSection? {
        picture(input).sections.first { $0.kind == kind }
    }

    private func settings(onCycleDay day: Int, cycleLength: Int = 28) -> CycleSettings {
        CycleSettings(lastPeriodDate: today.minusDays(day - 1), cycleLength: cycleLength, periodLength: 5)
    }

    // ── The whole picture ──

    func testNothingRecordedLeavesOnlyTheStillLearningRow() {
        let picture = picture(F.input())
        XCTAssertFalse(picture.isWithheldForConsent)
        XCTAssertEqual(picture.sections.map(\.kind), [.patterns])
        XCTAssertEqual(picture.sections[0].title, "Patterns")
        XCTAssertNil(picture.sections[0].note)

        let rows = picture.sections[0].rows
        XCTAssertEqual(rows.map(\.kind), [.stillLearning])
        XCTAssertEqual(rows[0].id, "stillLearning")
        XCTAssertEqual(rows[0].value, ProgrammeEvidenceCopy.stillLearning)
        XCTAssertEqual(rows[0].destination, .programme(.dailyLog))
        XCTAssertNil(rows[0].evidenceLevel)
        XCTAssertNil(rows[0].detail)
        XCTAssertNil(rows[0].date)
    }

    func testWithoutConsentThePictureHoldsNothing() {
        var withdrawn = F.rich
        withdrawn.consentActive = false
        let picture = picture(withdrawn)
        XCTAssertTrue(picture.sections.isEmpty)
        XCTAssertTrue(picture.isWithheldForConsent)
        XCTAssertTrue(picture.surfaces.isEmpty)

        // Consent has to be stated: an input that says nothing about it is withheld too.
        let unstated = FertilityPictureInput(today: today, calendar: F.utc)
        XCTAssertTrue(self.picture(unstated).isWithheldForConsent)
    }

    func testEachSectionAppearsOnlyWithItsOwnData() {
        XCTAssertEqual(picture(F.rich).sections.map(\.kind), FertilityPictureSectionKind.allCases)
        XCTAssertEqual(picture(F.rich).sections.map(\.title),
                       ["Current cycle", "Testing", "Everyday health", "Programme", "Patterns"])

        func sections(_ change: (inout FertilityPictureInput) -> Void) -> [FertilityPictureSectionKind] {
            picture(input(change)).sections.map(\.kind)
        }
        XCTAssertEqual(sections { $0.cycleSettings = self.settings(onCycleDay: 3) }, [.currentCycle, .patterns])
        XCTAssertEqual(sections { $0.phReadings = [F.ph(4.4, daysAgo: 0)] }, [.testing, .patterns])
        XCTAssertEqual(sections { $0.logsByDate = [self.today: DailyLog(mood: .good)] }, [.everydayHealth, .patterns])
        XCTAssertEqual(sections { $0.programmeState = ProgrammeState(startedOn: self.today) }, [.programme, .patterns])
    }

    func testNoRowIsEmptyAndNothingMissingIsShownAsZero() {
        // A log with nothing in it, and a reading too old for the thirty-day count.
        let hollow = input {
            $0.logsByDate = [self.today: DailyLog()]
            $0.phReadings = [F.ph(4.4, daysAgo: 40)]
        }
        XCTAssertEqual(kinds(hollow), [.latestPhReading, .stillLearning])

        for input in [F.rich, F.sparse, F.input(), hollow] {
            let picture = picture(input)
            for section in picture.sections {
                XCTAssertFalse(section.rows.isEmpty, section.kind.rawValue)
                XCTAssertFalse(section.title.isEmpty)
                XCTAssertEqual(section.id, section.kind.rawValue)
            }
            let rows = picture.sections.flatMap(\.rows)
            XCTAssertEqual(Set(rows.map(\.id)).count, rows.count, "row ids must be unique")
            for row in rows {
                XCTAssertFalse(row.label.isEmpty, row.id)
                XCTAssertNotEqual(row.value, "0", row.id)
                XCTAssertNotEqual(row.value, "", row.id)
                XCTAssertNotEqual(row.detail, "", row.id)
                XCTAssertTrue(row.value != nil || row.detail != nil || row.dateRange != nil, "\(row.id) shows nothing")
            }
            XCTAssertFalse(picture.surfaces.contains { $0.trimmingCharacters(in: .whitespaces).isEmpty })
        }
    }

    func testSurfacesListEveryStringOfEverySection() {
        let picture = picture(input {
            $0.cycleSettings = self.settings(onCycleDay: 3)
            $0.logsByDate = [self.today: DailyLog(mood: .good)]
        })
        XCTAssertEqual(picture.surfaces, [
            "Current cycle", FertilityPictureCopy.estimateNote,
            "Estimated cycle day", "Cycle day 3", "Estimated phase", "Period", "Estimated fertile window",
            "Everyday health", "Latest mood", "Good",
            "Patterns", "Cross-cycle pattern", ProgrammeEvidenceCopy.stillLearning,
        ])
    }

    // ── Current cycle ──

    func testEstimatedDayAndPhaseAreTheCycleEnginesOwn() {
        for cycleDay in [1, 3, 9, 14, 15, 20, 28] {
            let settings = settings(onCycleDay: cycleDay)
            let info = CycleEngine.cyclePhase(settings: settings, target: today)
            let input = input { $0.cycleSettings = settings }

            XCTAssertEqual(info.dayOfCycle, cycleDay)
            XCTAssertEqual(row(.estimatedCycleDay, input)?.label, "Estimated cycle day")
            XCTAssertEqual(row(.estimatedCycleDay, input)?.value, "Cycle day \(cycleDay)")
            XCTAssertEqual(row(.estimatedPhase, input)?.label, "Estimated phase")
            XCTAssertEqual(row(.estimatedPhase, input)?.value, CycleContent.phaseLabel[info.phase])
            XCTAssertEqual(section(.currentCycle, input)?.note, "Estimated from your cycle settings. An estimate is not a record.")
            XCTAssertTrue(rows(input).filter { $0.kind != .stillLearning }.allSatisfy { $0.destination == .programme(.cycle) })
        }
        XCTAssertEqual(row(.estimatedPhase, input { $0.cycleSettings = self.settings(onCycleDay: 3) })?.value, "Period")
        XCTAssertEqual(row(.estimatedPhase, input { $0.cycleSettings = self.settings(onCycleDay: 9) })?.value, "Follicular Phase")
        XCTAssertEqual(row(.estimatedPhase, input { $0.cycleSettings = self.settings(onCycleDay: 14) })?.value, "Ovulatory Phase")
        XCTAssertEqual(row(.estimatedPhase, input { $0.cycleSettings = self.settings(onCycleDay: 20) })?.value, "Luteal Phase")
    }

    /// A 28-day cycle puts the estimated window on cycle days 9 to 15.
    func testEstimatedFertileWindowIsGivenAsDates() {
        func window(onCycleDay day: Int) -> ClosedRange<CalendarDate>? {
            let row = row(.estimatedFertileWindow, input { $0.cycleSettings = self.settings(onCycleDay: day) })
            XCTAssertEqual(row?.label, "Estimated fertile window")
            XCTAssertNil(row?.value)
            XCTAssertNil(row?.detail)
            XCTAssertNil(row?.date)
            return row?.dateRange
        }
        // Before it: this cycle's window, still to come.
        XCTAssertEqual(window(onCycleDay: 3), today.plusDays(6)...today.plusDays(12))
        // Inside it.
        XCTAssertEqual(window(onCycleDay: 11), today.minusDays(2)...today.plusDays(4))
        // Its last day is still this cycle's window.
        XCTAssertEqual(window(onCycleDay: 15), today.minusDays(6)...today)
        // Past it: the next cycle's, both dates one cycle length on.
        XCTAssertEqual(window(onCycleDay: 16), today.plusDays(21)...today.plusDays(27))
        XCTAssertEqual(window(onCycleDay: 20), today.plusDays(17)...today.plusDays(23))
        // One cycle length on is her own: a 30-day cycle puts the window on cycle days 11 to 17.
        XCTAssertEqual(row(.estimatedFertileWindow, input { $0.cycleSettings = self.settings(onCycleDay: 20, cycleLength: 30) })?.dateRange,
                       today.plusDays(21)...today.plusDays(27))
    }

    func testAWindowThatWouldStartBeforeDayOneDropsOnlyThatRow() {
        // 18 days: the engine's window would start on day -1. 20 days: it starts on day 1.
        XCTAssertEqual(CycleEngine.cyclePhase(settings: settings(onCycleDay: 2, cycleLength: 18), target: today).fertileWindow.startDay, -1)
        XCTAssertEqual(kinds(input { $0.cycleSettings = self.settings(onCycleDay: 2, cycleLength: 18) }),
                       [.estimatedCycleDay, .estimatedPhase, .stillLearning])
        XCTAssertEqual(kinds(input { $0.cycleSettings = self.settings(onCycleDay: 2, cycleLength: 19) }),
                       [.estimatedCycleDay, .estimatedPhase, .stillLearning])
        XCTAssertEqual(row(.estimatedFertileWindow, input { $0.cycleSettings = self.settings(onCycleDay: 2, cycleLength: 20) })?.dateRange,
                       today.minusDays(1)...today.plusDays(5))
    }

    func testRecordedCycleDayNeedsACycleSheRecordedThatContainsToday() {
        let recorded = input { $0.cycles = F.cycles(lengths: [29], latestStart: self.today.minusDays(11)) }
        let row = row(.recordedCycleDay, recorded)
        XCTAssertEqual(row?.label, "Recorded cycle day")
        XCTAssertEqual(row?.value, "Cycle day 12")
        XCTAssertEqual(row?.date, today.minusDays(11))
        XCTAssertEqual(row?.destination, .programme(.cycle))

        // History without settings shows the recorded row alone, with no note about an estimate.
        XCTAssertEqual(section(.currentCycle, recorded)?.rows.map(\.kind), [.recordedCycleDay])
        XCTAssertNil(section(.currentCycle, recorded)?.note)

        // A cycle opened by the seeded record is not shown as recorded.
        let seeded = input { $0.cycles = F.cycles(latestStart: self.today.minusDays(11), seedingFirst: true) }
        XCTAssertNil(section(.currentCycle, seeded))

        // Today is before her first recorded start.
        let beforeFirst = input { $0.cycles = F.cycles(latestStart: self.today.plusDays(2)) }
        XCTAssertNil(section(.currentCycle, beforeFirst))
    }

    func testTheEstimateAndTheRecordAreSeparateRowsAndCanDisagree() {
        let both = input {
            $0.cycleSettings = self.settings(onCycleDay: 20)
            $0.cycles = F.cycles(latestStart: self.today.minusDays(11))
        }
        XCTAssertEqual(section(.currentCycle, both)?.rows.map(\.kind),
                       [.estimatedCycleDay, .estimatedPhase, .estimatedFertileWindow, .recordedCycleDay])
        XCTAssertEqual(row(.estimatedCycleDay, both)?.value, "Cycle day 20")
        XCTAssertEqual(row(.recordedCycleDay, both)?.value, "Cycle day 12")
        XCTAssertEqual(row(.recordedCycleDay, both)?.date, today.minusDays(11))
        XCTAssertNil(row(.estimatedCycleDay, both)?.date)
    }

    // ── Testing: ovulation tests ──

    func testTheLatestOvulationTestWinsByTime() {
        let input = input {
            $0.scanFeaturesAvailable = true
            $0.lhResults = [F.lh(.positive, daysAgo: 3), F.lh(.low, daysAgo: 1, hour: 8), F.lh(.rising, daysAgo: 1, hour: 7)]
        }
        let row = row(.latestLhResult, input)
        XCTAssertEqual(row?.label, "Latest ovulation test")
        XCTAssertEqual(row?.value, "Low LH")
        XCTAssertNil(row?.detail)
        XCTAssertEqual(row?.date, today.minusDays(1))
        XCTAssertEqual(row?.destination, .programme(.lhTest))
        XCTAssertEqual(section(.testing, input)?.note, LhScanCopy.resultNote)

        // Two results at the same moment: the id decides, whatever order they arrive in.
        let tied = [F.lh(.low, daysAgo: 1, id: "a"), F.lh(.invalid, daysAgo: 1, id: "b")]
        for results in [tied, tied.reversed()] {
            let input = self.input { $0.scanFeaturesAvailable = true; $0.lhResults = results }
            XCTAssertEqual(self.row(.latestLhResult, input)?.value, "Test invalid")
        }
    }

    func testTheOvulationTestValueIsTheScanScreensOwnTitle() {
        for classification in [LhClassification.low, .rising, .positive, .invalid] {
            let input = input { $0.scanFeaturesAvailable = true; $0.lhResults = [F.lh(classification, daysAgo: 0)] }
            XCTAssertEqual(row(.latestLhResult, input)?.value, LhScanCopy.title(for: classification))
        }
    }

    func testAnUnreadableOvulationTestIsSkipped() {
        let behind = input {
            $0.scanFeaturesAvailable = true
            $0.lhResults = [F.lh(.low, daysAgo: 3), F.lh(.unreadable, daysAgo: 1)]
        }
        XCTAssertEqual(row(.latestLhResult, behind)?.value, "Low LH")
        XCTAssertEqual(row(.latestLhResult, behind)?.date, today.minusDays(3))

        let alone = input { $0.scanFeaturesAvailable = true; $0.lhResults = [F.lh(.unreadable, daysAgo: 1)] }
        XCTAssertEqual(section(.testing, alone)?.rows.map(\.kind), [.pregnancyTestRecords])
        XCTAssertNil(section(.testing, alone)?.note)
    }

    func testTheOvulationTestRowNeedsTheScanFeatures() {
        let input = input {
            $0.lhResults = [F.lh(.positive, daysAgo: 1)]
            $0.phReadings = [F.ph(4.4, daysAgo: 0)]
        }
        XCTAssertNil(row(.latestLhResult, input))
        // And its note goes with it.
        XCTAssertNotNil(section(.testing, input))
        XCTAssertNil(section(.testing, input)?.note)
    }

    func testNoMeasurementReachesAnyString() {
        let input = input {
            $0.scanFeaturesAvailable = true
            $0.lhResults = [F.lh(.positive, daysAgo: 0, cycleDay: 17, scan: F.measurement)]
        }
        let surfaces = picture(input).surfaces
        XCTAssertTrue(surfaces.contains("LH surge detected"))
        // With one result and nothing else recorded, no string holds a number at all: not the
        // signals, the ratio, the confidence, the scanner version or the saved cycle day.
        XCTAssertFalse(surfaces.joined().contains(where: \.isNumber), surfaces.joined(separator: " | "))

        let rich = picture(F.rich).surfaces.joined(separator: " | ")
        for leaked in ["7341", "3912", "8766", "9123", "9.8.7", "cfg", "Cycle day 11"] {
            XCTAssertFalse(rich.contains(leaked), leaked)
        }
    }

    // ── Testing: pH ──

    func testTheLatestPhReadingShowsItsValueAndBandLabelOnly() {
        for (value, shown, band) in [(3.8, "3.8", "Healthy"), (4.5, "4.5", "Healthy"), (4.6, "4.6", "Elevated"), (5.0, "5.0", "Elevated")] {
            let input = input { $0.phReadings = [F.ph(4.0, daysAgo: 6), F.ph(value, daysAgo: 2)] }
            let row = row(.latestPhReading, input)
            XCTAssertEqual(row?.label, "Latest pH reading")
            XCTAssertEqual(row?.value, shown)
            XCTAssertEqual(row?.detail, band)
            XCTAssertEqual(row?.date, today.minusDays(2))
            XCTAssertEqual(row?.destination, .programme(.phTest))
            // A reading on its own brings no note and no sentence.
            XCTAssertNil(section(.testing, input)?.note)
            XCTAssertEqual(section(.testing, input)?.rows.map(\.kind), [.latestPhReading, .phReadingsLast30Days])
        }
    }

    func testUrineReadingsAreIgnored() {
        XCTAssertNil(section(.testing, input { $0.phReadings = [F.ph(6.2, daysAgo: 0, type: .urine)] }))

        let mixed = input { $0.phReadings = [F.ph(6.2, daysAgo: 0, type: .urine), F.ph(4.3, daysAgo: 5)] }
        XCTAssertEqual(row(.latestPhReading, mixed)?.value, "4.3")
        XCTAssertEqual(row(.phReadingsLast30Days, mixed)?.value, "1")
    }

    func testPhRowsNeedPhLogging() {
        let input = input { $0.phLoggingAvailable = false; $0.phReadings = [F.ph(4.3, daysAgo: 0)] }
        XCTAssertNil(section(.testing, input))
    }

    func testTheThirtyDayCountRunsFromTwentyNineDaysAgoToToday() {
        XCTAssertEqual(FertilityPictureLogic.recentDays, 30)
        XCTAssertTrue(FertilityPictureCopy.phReadingsRecent.contains("\(FertilityPictureLogic.recentDays) days"))

        let input = input {
            $0.phReadings = [F.ph(4.4, daysAgo: 0), F.ph(4.4, daysAgo: 29), F.ph(4.4, daysAgo: 30), F.ph(4.4, daysAgo: -1)]
        }
        let row = row(.phReadingsLast30Days, input)
        XCTAssertEqual(row?.label, "pH readings in the last 30 days")
        XCTAssertEqual(row?.value, "2")
        XCTAssertNil(row?.date)
        XCTAssertEqual(row?.destination, .programme(.phTest))

        // Nothing in the thirty days: the reading is still her latest, and no count of none is shown.
        XCTAssertEqual(kinds(self.input { $0.phReadings = [F.ph(4.4, daysAgo: 30)] }), [.latestPhReading, .stillLearning])
    }

    func testARecordsDateIsReadOnTheInputsCalendar() {
        let lateEvening = F.instant(CalendarDate(2026, 6, 22), hour: 23, minute: 30, in: F.plusTwo)
        let smallHours = F.instant(CalendarDate(2026, 6, 23), hour: 0, minute: 30, in: F.plusTwo)
        XCTAssertEqual(smallHours.timeIntervalSince(lateEvening), 60 * 60)

        func dates(_ instant: Date, _ calendar: Calendar) -> [CalendarDate?] {
            var input = F.input(calendar: calendar)
            input.scanFeaturesAvailable = true
            input.phReadings = [PhReading(phValue: 4.4, recordedAt: instant)]
            input.lhResults = [LhResult(recordedAt: instant, classification: .low)]
            return [row(.latestPhReading, input)?.date, row(.latestLhResult, input)?.date]
        }
        // An hour apart, and either side of midnight where she is.
        XCTAssertEqual(dates(lateEvening, F.plusTwo), [CalendarDate(2026, 6, 22), CalendarDate(2026, 6, 22)])
        XCTAssertEqual(dates(smallHours, F.plusTwo), [CalendarDate(2026, 6, 23), CalendarDate(2026, 6, 23)])
        // The same two moments are both the 22nd on a calendar two hours behind hers.
        XCTAssertEqual(dates(lateEvening, F.utc), [CalendarDate(2026, 6, 22), CalendarDate(2026, 6, 22)])
        XCTAssertEqual(dates(smallHours, F.utc), [CalendarDate(2026, 6, 22), CalendarDate(2026, 6, 22)])
    }

    // ── Testing: the pregnancy test screen ──

    /// The row is a way to the screen and nothing else. It is there whenever the screen is,
    /// whether or not anything has been saved on it, as the screen's own button is. A row shown
    /// only once a result is saved would tell anyone who sees the summary that she has taken a test.
    func testThePregnancyTestRowIsThereWheneverTheScreenIs() {
        XCTAssertNil(section(.testing, F.input()))

        let input = input { $0.scanFeaturesAvailable = true }
        XCTAssertEqual(section(.testing, input)?.rows.map(\.kind), [.pregnancyTestRecords])
        XCTAssertNil(section(.testing, input)?.note)
        // Nothing she has recorded changes it.
        XCTAssertEqual(row(.pregnancyTestRecords, input), row(.pregnancyTestRecords, F.rich))

        var withoutScreens = F.rich
        withoutScreens.scanFeaturesAvailable = false
        XCTAssertNil(row(.pregnancyTestRecords, withoutScreens))
    }

    func testThePregnancyTestRowSaysOnlyThatTheScreenCanBeOpened() throws {
        XCTAssertEqual(HcgScanCopy.cardTitle, "Pregnancy Test")
        XCTAssertEqual(HcgScanCopy.showHistory, "Show saved results")

        for input in [F.rich, self.input { $0.scanFeaturesAvailable = true }] {
            let row = try XCTUnwrap(row(.pregnancyTestRecords, input))
            XCTAssertEqual(row, FertilityPictureRow(
                .pregnancyTestRecords, id: "pregnancyTestRecords", label: "Pregnancy Test", value: nil,
                detail: "Show saved results", date: nil, dateRange: nil, evidenceLevel: nil,
                destination: .pregnancyTestScreen))
            // No other row leads there.
            XCTAssertEqual(rows(input).filter { $0.destination == .pregnancyTestScreen }, [row])
        }
    }

    /// The input has no field for anything about her pregnancy test records: not a result, a
    /// count or a date, and not whether any exist. Nothing about them can reach the picture.
    func testTheInputHoldsNothingAboutPregnancyTestRecords() {
        let fields = Mirror(reflecting: F.rich).children.compactMap(\.label)
        XCTAssertEqual(fields, [
            "today", "calendar", "consentActive", "cycleSettings", "cycles", "logsByDate", "waterGoalMl",
            "hydrationUnit", "glassMl", "phReadings", "lhResults",
            "scanFeaturesAvailable", "phLoggingAvailable", "programmeState", "consistency", "content",
        ])
        for field in fields {
            XCTAssertFalse(field.lowercased().contains("pregnan"), field)
            XCTAssertFalse(field.lowercased().contains("hcg"), field)
        }
    }

    func testTheRowAddsExactlyTwoStringsToThePicture() throws {
        // With no ovulation test results, the scan features bring this row and nothing else.
        var with = F.rich
        with.lhResults = []
        var without = with
        without.scanFeaturesAvailable = false

        var added = picture(with).surfaces
        for surface in picture(without).surfaces {
            added.remove(at: try XCTUnwrap(added.firstIndex(of: surface), surface))
        }
        XCTAssertEqual(added, ["Pregnancy Test", "Show saved results"])
        XCTAssertEqual(rows(with).filter { $0.kind != .pregnancyTestRecords }, rows(without))
    }

    // ── Everyday health ──

    func testEachEverydayRowComesFromItsOwnField() {
        func health(_ log: DailyLog) -> [FertilityPictureRow] {
            section(.everydayHealth, input { $0.logsByDate = [self.today: log] })?.rows ?? []
        }
        func only(_ log: DailyLog, file: StaticString = #filePath, line: UInt = #line) -> FertilityPictureRow? {
            let rows = health(log)
            XCTAssertEqual(rows.count, 1, file: file, line: line)
            return rows.first
        }
        let sleep = only(DailyLog(sleepMinutes: 445))
        XCTAssertEqual([sleep?.id, sleep?.label, sleep?.value], ["lastSleep", "Last recorded sleep", "7h 25m"])
        XCTAssertEqual(sleep?.destination, .programme(.dailyLog))

        let water = only(DailyLog(waterMl: 500))
        XCTAssertEqual([water?.id, water?.label], ["waterToday", "Water today"])
        XCTAssertEqual(water?.destination, .programme(.hydration))

        let food = only(DailyLog(foodGroups: ["fruit"]))
        XCTAssertEqual([food?.id, food?.label, food?.value], ["foodGroupsToday", "Food groups", "1 of 6 food groups today"])
        XCTAssertEqual(food?.destination, .programme(.nutrition))

        let mood = only(DailyLog(mood: .okay))
        XCTAssertEqual([mood?.id, mood?.label, mood?.value], ["latestMood", "Latest mood", "Okay"])
        XCTAssertEqual(mood?.destination, .programme(.dailyLog))

        let energy = only(DailyLog(energy: .high))
        XCTAssertEqual([energy?.id, energy?.label, energy?.value], ["latestEnergy", "Latest energy", "High"])
        XCTAssertEqual(energy?.destination, .programme(.dailyLog))

        let symptoms = only(DailyLog(symptoms: ["cramps"]))
        XCTAssertEqual([symptoms?.id, symptoms?.label, symptoms?.value], ["symptomsToday", "Symptoms recorded today", "1"])
        XCTAssertEqual(symptoms?.destination, .programme(.dailyLog))

        // Supplements and notes have no row here.
        XCTAssertEqual(health(DailyLog(supplements: ["folate"], notes: "A note")), [])

        XCTAssertEqual(section(.everydayHealth, F.rich)?.rows.map(\.kind),
                       [.lastSleep, .waterToday, .foodGroupsToday, .latestMood, .latestEnergy, .symptomsToday])
        XCTAssertEqual(EnergyLevel.allCases.map(FertilityPictureCopy.energyLabel), ["Low", "Normal", "High"])
    }

    func testSleepMoodAndEnergyComeFromTheMostRecentDayThatHasThem() {
        let input = input {
            $0.logsByDate = [
                self.today: DailyLog(waterMl: 250),
                self.today.minusDays(3): DailyLog(mood: .good, energy: .high, sleepMinutes: 400),
                self.today.minusDays(10): DailyLog(mood: .low, energy: .low, sleepMinutes: 300),
            ]
        }
        XCTAssertEqual(row(.lastSleep, input)?.value, "6h 40m")
        XCTAssertEqual(row(.latestMood, input)?.value, "Good")
        XCTAssertEqual(row(.latestEnergy, input)?.value, "High")
        for kind in [FertilityPictureRowKind.lastSleep, .latestMood, .latestEnergy] {
            XCTAssertEqual(row(kind, input)?.date, today.minusDays(3))
        }

        // Each field finds its own day. A night entered as 0 is a record.
        let apart = self.input {
            $0.logsByDate = [
                self.today.minusDays(2): DailyLog(mood: .great),
                self.today.minusDays(5): DailyLog(sleepMinutes: 0),
            ]
        }
        XCTAssertEqual(row(.lastSleep, apart)?.value, "0h")
        XCTAssertEqual(row(.lastSleep, apart)?.date, today.minusDays(5))
        XCTAssertEqual(row(.latestMood, apart)?.date, today.minusDays(2))
        XCTAssertNil(row(.latestEnergy, apart))
    }

    func testARecordOlderThanThirtyDaysIsNotShown() {
        let log = DailyLog(mood: .good, energy: .normal, sleepMinutes: 420)
        let inside = input { $0.logsByDate = [self.today.minusDays(29): log] }
        XCTAssertEqual(section(.everydayHealth, inside)?.rows.map(\.date),
                       [today.minusDays(29), today.minusDays(29), today.minusDays(29)])

        // The thirty-first day back, counting today.
        XCTAssertNil(section(.everydayHealth, input { $0.logsByDate = [self.today.minusDays(30): log] }))
        // Nor a day that has not happened yet.
        XCTAssertNil(section(.everydayHealth, input { $0.logsByDate = [self.today.plusDays(1): log] }))
    }

    func testWaterTodayUsesTheExistingProgressFormatInHerUnit() {
        func water(_ change: (inout FertilityPictureInput) -> Void = { _ in }) -> String? {
            row(.waterToday, input { $0.logsByDate = [self.today: DailyLog(waterMl: 500)]; change(&$0) })?.value
        }
        XCTAssertEqual(water(), "2 / 9.6 glasses")
        XCTAssertEqual(water(), HydrationFormat.progress(ml: 500, goalMl: TrackingEngine.defaultWaterGoalMl, unit: .glasses))
        XCTAssertEqual(water { $0.hydrationUnit = .milliliters }, "500 / 2400 ml")
        XCTAssertEqual(water { $0.hydrationUnit = .cups },
                       HydrationFormat.progress(ml: 500, goalMl: 2400, unit: .cups))
        XCTAssertEqual(water { $0.glassMl = 500; $0.waterGoalMl = 3000 }, "1 / 6 glasses")
        // No usable goal: the app's constant.
        XCTAssertEqual(water { $0.waterGoalMl = 0; $0.hydrationUnit = .milliliters }, "500 / 2400 ml")

        // Today's amount only, and only above nothing.
        XCTAssertNil(row(.waterToday, input { $0.logsByDate = [self.today.minusDays(1): DailyLog(waterMl: 500)] }))
        XCTAssertNil(row(.waterToday, input { $0.logsByDate = [self.today: DailyLog(mood: .good, waterMl: 0)] }))
    }

    func testFoodGroupsAreStatedAsACountAndNeverAsAShare() {
        func food(_ groups: Set<String>) -> FertilityPictureInput {
            input { $0.logsByDate = [self.today: DailyLog(foodGroups: groups)] }
        }
        XCTAssertEqual(row(.foodGroupsToday, food(["vegetables", "fruit", "protein", "her-own-group"]))?.value,
                       "3 of 6 food groups today")
        XCTAssertEqual(row(.foodGroupsToday, food(Set(FoodGroup.allCases.map(\.rawValue))))?.value, "6 of 6 food groups today")
        XCTAssertNil(row(.foodGroupsToday, food(["vegetables"]))?.detail)

        // A group of her own that the tracker does not know is not counted, so there is no row.
        XCTAssertNil(section(.everydayHealth, food(["her-own-group"])))
        // Yesterday's groups are not today's.
        XCTAssertNil(row(.foodGroupsToday, input { $0.logsByDate = [self.today.minusDays(1): DailyLog(foodGroups: ["fruit"])] }))

        for input in [F.rich, food(["vegetables", "fruit"])] {
            let health = section(.everydayHealth, input)?.rows ?? []
            XCTAssertFalse(health.contains { ($0.value ?? "").contains("%") || ($0.detail ?? "").contains("%") })
        }
    }

    func testSymptomsTodayShowACount() {
        XCTAssertEqual(row(.symptomsToday, input { $0.logsByDate = [self.today: DailyLog(symptoms: ["cramps", "headache", "bloating"])] })?.value, "3")
        XCTAssertNil(row(.symptomsToday, input { $0.logsByDate = [self.today.minusDays(1): DailyLog(symptoms: ["cramps"])] }))
    }

    // ── Programme ──

    func testAnActiveProgrammeShowsTheDayThePhaseTodayAndTheWeek() {
        let input = input {
            $0.programmeState = ProgrammeState(startedOn: self.today.minusDays(22))
            $0.consistency = F.report(today: ProgrammeTodayProgress(completed: 2, partlyCompleted: 1, total: 5),
                                      week: F.figure(completed: 29, of: 37), programme: F.figure(completed: 60, of: 80))
        }
        let rows = section(.programme, input)?.rows ?? []
        XCTAssertEqual(rows.map(\.kind), [.programmeDay, .programmeToday, .programmeWeek])
        XCTAssertTrue(rows.allSatisfy { $0.destination == .programme(.programmeProgress) })

        XCTAssertEqual(rows.map(\.label), ["Programme day", "Today", "This programme week"])
        XCTAssertEqual(rows.map(\.value), ["Day 23 of 90", "2 of 5 activities completed today", "78%"])
        XCTAssertEqual(rows.map(\.detail), [ProgrammeContent.draft.phaseTitles[.buildTheFoundation], nil,
                                             "29 of 37 activities completed"])
        XCTAssertNotNil(rows[0].detail)

        // The phase title follows the day.
        for (daysIn, phase) in [(29, ProgrammePhase.buildTheFoundation), (30, .discoverYourPatterns), (60, .personaliseAndSustain)] {
            let input = self.input { $0.programmeState = ProgrammeState(startedOn: self.today.minusDays(daysIn)) }
            XCTAssertEqual(row(.programmeDay, input)?.value, "Day \(daysIn + 1) of 90")
            XCTAssertEqual(row(.programmeDay, input)?.detail, ProgrammeContent.draft.phaseTitles[phase])
        }
    }

    func testTheWeekShowsCountsAloneWhereThePercentageIsWithheld() {
        func programme(_ report: ProgrammeConsistencyReport?) -> [FertilityPictureRow] {
            section(.programme, input {
                $0.programmeState = ProgrammeState(startedOn: self.today.minusDays(22))
                $0.consistency = report
            })?.rows ?? []
        }
        // Four counted is below the calculator's minimum of five.
        let below = programme(F.report(week: F.figure(completed: 2, of: 4)))
        XCTAssertEqual(below.map(\.kind), [.programmeDay, .programmeWeek])
        XCTAssertEqual(below.last?.value, "2 of 4 activities completed")
        XCTAssertNil(below.last?.detail)

        let atMinimum = programme(F.report(week: F.figure(completed: 2, of: 5)))
        XCTAssertEqual(atMinimum.last?.value, "40%")
        XCTAssertEqual(atMinimum.last?.detail, "2 of 5 activities completed")

        // Counted and none done: no row, as the Programme Reviews have no line for it. A missed
        // week is never shown as a count of nought, with a percentage or without one.
        let noneDone = F.figure(completed: 0, of: 6)
        XCTAssertTrue(noneDone.nothingRecorded)
        XCTAssertEqual(noneDone.percentage, 0)
        XCTAssertEqual(programme(F.report(week: noneDone)).map(\.kind), [.programmeDay])
        XCTAssertNil(F.figure(completed: 0, of: 4).percentage)
        XCTAssertEqual(programme(F.report(week: F.figure(completed: 0, of: 4))).map(\.kind), [.programmeDay])

        // A little credit over many activities still rounds to nought: one glass of water in a
        // week of thirty activities. The counts, and no percentage.
        let oneGlass = F.figure(completed: 0, partly: [0.1], of: 30)
        XCTAssertEqual(oneGlass.percentage, 0)
        XCTAssertFalse(oneGlass.nothingRecorded)
        let littleCredit = programme(F.report(week: oneGlass))
        XCTAssertEqual(littleCredit.map(\.kind), [.programmeDay, .programmeWeek])
        XCTAssertEqual(littleCredit.last?.value, "1 of 30 activities partly completed")
        XCTAssertNil(littleCredit.last?.detail)
        XCTAssertFalse(littleCredit.contains { (($0.value ?? "") + ($0.detail ?? "")).contains("%") })
        // One per cent is the least that is shown.
        XCTAssertEqual(programme(F.report(week: F.figure(completed: 0, partly: [0.2], of: 30))).last?.value, "1%")

        // Nothing counted, nothing planned for today, or no report at all: the day alone.
        XCTAssertEqual(programme(F.report()).map(\.kind), [.programmeDay])
        XCTAssertEqual(programme(F.report(today: ProgrammeTodayProgress(completed: 0, partlyCompleted: 0, total: 0))).map(\.kind),
                       [.programmeDay])
        XCTAssertEqual(programme(nil).map(\.kind), [.programmeDay])

        // One activity is one activity.
        XCTAssertEqual(programme(F.report(today: ProgrammeTodayProgress(completed: 1, partlyCompleted: 0, total: 1)))
            .last?.value, "1 of 1 activity completed today")
    }

    /// The percentage counts part credit, so the counts beside it say how many activities were
    /// partly completed. Without them the two numbers on one row would not add up.
    func testThePercentageStandsBesideTheCountsItCameFromPartCreditIncluded() throws {
        func figureRow(_ figure: ProgrammeConsistencyFigure, completed: Bool = false) -> FertilityPictureRow? {
            row(completed ? .programmeOverall : .programmeWeek, input {
                $0.programmeState = ProgrammeState(startedOn: self.today.minusDays(completed ? 90 : 22))
                $0.consistency = F.report(week: figure, programme: figure)
            })
        }
        // Five done and five at nine tenths of the water goal.
        let mixed = F.figure(completed: 5, partly: Array(repeating: 0.9, count: 5), of: 10)
        XCTAssertEqual([mixed.completed, mixed.partlyCompleted, mixed.counted], [5, 5, 10])
        for completed in [false, true] {
            XCTAssertEqual(figureRow(mixed, completed: completed)?.value, "95%")
            XCTAssertEqual(figureRow(mixed, completed: completed)?.detail, "5 of 10 activities completed, 5 partly completed")
        }
        // Nothing done in full: only the partly completed count is stated.
        let partOnly = figureRow(F.figure(completed: 0, partly: [0.5, 0.5, 0.5], of: 6))
        XCTAssertEqual(partOnly?.value, "25%")
        XCTAssertEqual(partOnly?.detail, "3 of 6 activities partly completed")
        // Below the minimum the same counts stand alone.
        let below = figureRow(F.figure(completed: 2, partly: [0.5], of: 4))
        XCTAssertEqual(below?.value, "2 of 4 activities completed, 1 partly completed")
        XCTAssertNil(below?.detail)

        // The words are the Programme Reviews' own, so one figure reads the same in both places.
        for figure in [mixed, F.figure(completed: 0, partly: [0.5, 0.5, 0.5], of: 6), F.figure(completed: 29, of: 37)] {
            XCTAssertEqual(figureRow(figure)?.value, ProgrammeReviewCopy.percentage(try XCTUnwrap(figure.percentage)))
            XCTAssertEqual(figureRow(figure)?.detail, ProgrammeReviewCopy.activitiesCompleted(
                figure.completed, of: figure.counted, partlyCompleted: figure.partlyCompleted))
        }
    }

    func testACompletedProgrammeShowsThatAndTheOverallFigure() {
        func programme(_ report: ProgrammeConsistencyReport?) -> [FertilityPictureRow] {
            section(.programme, input {
                $0.programmeState = ProgrammeState(startedOn: self.today.minusDays(90))
                $0.consistency = report
            })?.rows ?? []
        }
        let rows = programme(F.report(today: ProgrammeTodayProgress(completed: 2, partlyCompleted: 0, total: 5),
                                      week: F.figure(completed: 29, of: 37), programme: F.figure(completed: 60, of: 80)))
        XCTAssertEqual(rows.map(\.kind), [.programmeDay, .programmeOverall])
        XCTAssertEqual(rows.map(\.label), ["Programme day", "Programme consistency"])
        XCTAssertEqual(rows.map(\.value), ["90-Day Programme completed", "75%"])
        XCTAssertEqual(rows.map(\.detail), [nil, "60 of 80 activities completed"])
        XCTAssertTrue(rows.allSatisfy { $0.destination == .programme(.programmeProgress) })

        XCTAssertEqual(programme(F.report(programme: F.figure(completed: 3, of: 4))).last?.value, "3 of 4 activities completed")
        // Two done in a whole programme rounds to nought: the counts, and no percentage.
        let twoDone = programme(F.report(programme: F.figure(completed: 2, of: 450)))
        XCTAssertEqual(twoDone.last?.value, "2 of 450 activities completed")
        XCTAssertNil(twoDone.last?.detail)
        // A whole programme with nothing done: the completed row alone, and no count of nought.
        XCTAssertTrue(F.figure(completed: 0, of: 450).nothingRecorded)
        XCTAssertEqual(programme(F.report(programme: F.figure(completed: 0, of: 450))).map(\.kind), [.programmeDay])
        XCTAssertEqual(programme(F.report()).map(\.kind), [.programmeDay])
        XCTAssertEqual(programme(nil).map(\.kind), [.programmeDay])
    }

    func testNoProgrammeSectionWhenNotStartedBeforeTheStartOrStopped() {
        let report = F.report(today: ProgrammeTodayProgress(completed: 2, partlyCompleted: 0, total: 5),
                              week: F.figure(completed: 29, of: 37), programme: F.figure(completed: 60, of: 80))
        let states = [
            ProgrammeState.notStarted,
            ProgrammeState(startedOn: today.plusDays(3)),
            ProgrammeState(startedOn: today.minusDays(10), stoppedOn: today.minusDays(1)),
            ProgrammeState(startedOn: today.minusDays(120), stoppedOn: today),
        ]
        for state in states {
            XCTAssertNil(section(.programme, input { $0.programmeState = state; $0.consistency = report }), "\(state)")
        }
    }

    /// The report as the real calculator builds it from real plans, shown without re-working it.
    func testTheProgrammeRowsShowTheCalculatorsOwnFigures() throws {
        let plans = (15...23).map { ProgrammeFixtures.plan(day: $0, todayDay: 23, ProgrammeFixtures.snapshotA(day: $0)) }
        let report = ProgrammeConsistency.report(state: ProgrammeFixtures.state, today: ProgrammeFixtures.date(ofDay: 23), plans: plans)
        var input = F.input(today: ProgrammeFixtures.date(ofDay: 23))
        input.programmeState = ProgrammeFixtures.state
        input.consistency = report

        let today = try XCTUnwrap(report.today)
        let week = report.week
        XCTAssertGreaterThan(today.total, 0)
        XCTAssertGreaterThan(week.credit, 0)
        // Water short of its goal on the day counted, so the week holds part credit.
        XCTAssertGreaterThan(week.partlyCompleted, 0)
        XCTAssertEqual(row(.programmeDay, input)?.value, "Day 23 of 90")
        XCTAssertEqual(row(.programmeToday, input)?.value,
                       FertilityPictureCopy.activitiesCompletedToday(today.completed, of: today.total))
        let counts = ProgrammeReviewCopy.activitiesCompleted(
            week.completed, of: week.counted, partlyCompleted: week.partlyCompleted)
        XCTAssertTrue(counts.hasSuffix("\(week.partlyCompleted) partly completed"), counts)
        if let percentage = week.percentage {
            XCTAssertEqual(row(.programmeWeek, input)?.value, "\(percentage)%")
            XCTAssertEqual(row(.programmeWeek, input)?.detail, counts)
        } else {
            XCTAssertEqual(row(.programmeWeek, input)?.value, counts)
        }
    }

    // ── Never merged: the estimate, a test result, and ovulation itself ──

    func testTheEstimatedWindowAndATestResultStayInTheirOwnSections() {
        var inWindow = F.rich
        inWindow.cycleSettings = settings(onCycleDay: 14)
        inWindow.lhResults = [F.lh(.positive, daysAgo: 0)]

        for input in [F.rich, F.sparse, F.input(), inWindow] {
            let picture = picture(input)
            for section in picture.sections {
                for row in section.rows {
                    if row.kind == .estimatedFertileWindow {
                        XCTAssertEqual(section.kind, .currentCycle)
                        XCTAssertTrue(row.label.hasPrefix("Estimated"))
                    }
                    if row.kind == .latestLhResult { XCTAssertEqual(section.kind, .testing) }
                    XCTAssertEqual(row.dateRange != nil, row.kind == .estimatedFertileWindow)
                    XCTAssertEqual(row.evidenceLevel != nil, row.kind == .pattern)
                }
            }
            for surface in picture.surfaces {
                let lower = surface.lowercased()
                for claim in ["confirmed", "ovulated", "ovulation happened"] {
                    XCTAssertFalse(lower.contains(claim), surface)
                }
            }
        }
        XCTAssertNotNil(row(.estimatedFertileWindow, inWindow))
        XCTAssertNotNil(row(.latestLhResult, inWindow))

        // The current cycle section says nothing of a test, and the testing rows nothing of a window.
        let cycle = section(.currentCycle, inWindow)?.rows ?? []
        let testing = section(.testing, inWindow)?.rows ?? []
        let resultTitles = LhClassification.allCases.map(LhScanCopy.title(for:))
        XCTAssertEqual(cycle.count, 4)
        XCTAssertEqual(testing.count, 4)
        XCTAssertFalse(cycle.contains { resultTitles.contains($0.value ?? "") })
        XCTAssertFalse(testing.contains { ($0.label + ($0.value ?? "") + ($0.detail ?? "")).lowercased().contains("window") })
    }

    /// A test result on the estimated day changes nothing in the estimate, and the estimate
    /// changes nothing in the testing section.
    func testATestResultAndTheEstimateDoNotAlterEachOther() {
        let settings = settings(onCycleDay: 14)
        let estimateOnly = input { $0.cycleSettings = settings }
        let resultOnly = input { $0.scanFeaturesAvailable = true; $0.lhResults = [F.lh(.positive, daysAgo: 0)] }
        let both = input {
            $0.cycleSettings = settings
            $0.scanFeaturesAvailable = true
            $0.lhResults = [F.lh(.positive, daysAgo: 0)]
        }
        XCTAssertEqual(section(.currentCycle, both), section(.currentCycle, estimateOnly))
        XCTAssertEqual(section(.testing, both), section(.testing, resultOnly))
        XCTAssertEqual(section(.patterns, both), section(.patterns, estimateOnly))
    }

    func testThereIsNoRowForOvulationHavingHappened() {
        for kind in FertilityPictureRowKind.allCases {
            let name = kind.rawValue.lowercased()
            XCTAssertFalse(name.contains("confirm"), kind.rawValue)
            XCTAssertFalse(name.contains("ovulat"), kind.rawValue)
        }
        XCTAssertEqual(FertilityPictureRowKind.allCases.count, 20)
    }

    // ── Intimacy ──

    func testTheIntimacyFieldChangesNothing() {
        var without = F.rich
        var with = F.rich
        with.logsByDate = with.logsByDate.mapValues { log in
            var log = log
            log.sexualActivity = true
            return log
        }
        // And on a day that holds nothing else.
        without.logsByDate[today.minusDays(20)] = DailyLog()
        with.logsByDate[today.minusDays(20)] = DailyLog(sexualActivity: true)

        XCTAssertEqual(picture(with), picture(without))
        XCTAssertEqual(picture(input { $0.logsByDate = [self.today: DailyLog(sexualActivity: true)] }), picture(F.input()))
    }

    // ── Destinations ──

    func testEveryRowLeadsSomewhereOnTheClosedList() {
        let expected: [FertilityPictureRowKind: FertilityPictureDestination] = [
            .estimatedCycleDay: .programme(.cycle), .estimatedPhase: .programme(.cycle),
            .estimatedFertileWindow: .programme(.cycle), .recordedCycleDay: .programme(.cycle),
            .latestLhResult: .programme(.lhTest), .latestPhReading: .programme(.phTest),
            .phReadingsLast30Days: .programme(.phTest), .pregnancyTestRecords: .pregnancyTestScreen,
            .lastSleep: .programme(.dailyLog), .waterToday: .programme(.hydration),
            .foodGroupsToday: .programme(.nutrition), .latestMood: .programme(.dailyLog),
            .latestEnergy: .programme(.dailyLog), .symptomsToday: .programme(.dailyLog),
            .programmeDay: .programme(.programmeProgress), .programmeToday: .programme(.programmeProgress),
            .programmeWeek: .programme(.programmeProgress), .programmeOverall: .programme(.programmeProgress),
            .pattern: .programme(.insights), .stillLearning: .programme(.dailyLog),
        ]
        XCTAssertEqual(Set(expected.keys), Set(FertilityPictureRowKind.allCases))

        var completed = F.rich
        completed.programmeState = ProgrammeState(startedOn: today.minusDays(90))
        var seen: Set<FertilityPictureRowKind> = []
        for input in [F.rich, F.sparse, F.input(), completed] {
            for row in rows(input) {
                seen.insert(row.kind)
                XCTAssertEqual(row.destination, expected[row.kind], row.id)
                if case .programme(let destination) = row.destination {
                    XCTAssertTrue(ProgrammeDestination.allCases.contains(destination))
                } else {
                    XCTAssertEqual(row.kind, .pregnancyTestRecords)
                }
            }
        }
        XCTAssertEqual(seen, Set(FertilityPictureRowKind.allCases), "every row kind was produced by a fixture")
    }
}
