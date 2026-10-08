import XCTest
import GenesyxCore
@testable import Genesyx

/// What My Fertility Picture draws, from contexts built with `KitFixture`. The assembly is core's;
/// these tests pin what the screen does with it.
@MainActor
final class FertilityPictureScreenTests: XCTestCase {

    private let today = CalendarDate(2026, 10, 6)
    private let calendar = Calendar.autoupdatingCurrent

    private func noon(_ daysBefore: Int) -> Date { today.minusDays(daysBefore).toDate(calendar: calendar) }

    private func settings(lastPeriodDaysBefore: Int = 8) -> CycleSettings {
        CycleSettings(lastPeriodDate: today.minusDays(lastPeriodDaysBefore), cycleLength: 28, periodLength: 5)
    }

    private func picture(_ context: FertilityKitContext) -> FertilityPicture {
        FertilityPictureLogic.picture(context.pictureInput())
    }

    private func section(_ kind: FertilityPictureSectionKind, in picture: FertilityPicture) -> FertilityPictureSection? {
        picture.sections.first { $0.kind == kind }
    }

    /// With scanning, one pH reading and one ovulation result: the Testing section holds the
    /// ovulation row, the pH rows and the pregnancy test row.
    private func testingContext(scan: Bool = true) -> FertilityKitContext {
        KitFixture.context(today: today, scan: scan, phReadings: [PhReading(phValue: 6.7, recordedAt: noon(2))],
                           lhResults: [LhResult(recordedAt: noon(1), classification: .low)], cycleSettings: settings())
    }

    // MARK: Where the note goes

    func testTheOvulationNoteFollowsItsRowAndComesBeforeThePhRows() throws {
        let testing = try XCTUnwrap(section(.testing, in: picture(testingContext())))
        let note = try XCTUnwrap(testing.note, "core hands the ovulation sentence over as the section's note")
        let items = FertilityPicturePresentation.items(for: testing)

        XCTAssertEqual(items.first, .title(testing.title))
        let lh = try XCTUnwrap(items.firstIndex { if case .row(let row) = $0 { return row.kind == .latestLhResult } else { return false } })
        XCTAssertEqual(items[lh + 1], .note(note), "the note is directly under the ovulation row")
        let ph = try XCTUnwrap(items.firstIndex { if case .row(let row) = $0 { return row.kind == .latestPhReading } else { return false } })
        XCTAssertLessThan(lh + 1, ph, "and before the pH rows")
        XCTAssertEqual(items.filter { $0 == .note(note) }.count, 1)
        XCTAssertNotEqual(items[1], .note(note), "never under the title")
    }

    func testWithNoOvulationRowTheTestingSectionHasNoNote() throws {
        let noResult = KitFixture.context(today: today, scan: true, phReadings: [PhReading(phValue: 6.7, recordedAt: noon(2))])
        let noScan = testingContext(scan: false)
        for context in [noResult, noScan] {
            let testing = try XCTUnwrap(section(.testing, in: picture(context)))
            XCTAssertNil(testing.note)
            XCTAssertFalse(FertilityPicturePresentation.items(for: testing).contains {
                if case .note = $0 { return true } else { return false }
            })
            XCTAssertFalse(testing.rows.contains { $0.kind == .latestLhResult })
        }
    }

    func testEveryOtherSectionsNoteIsUnderItsTitle() throws {
        let context = KitFixture.context(today: today, day: 23, logs: [today: DailyLog(mood: .good)],
                                         cycleSettings: settings())
        let sections = picture(context).sections.filter { $0.kind != .testing }
        let withNote = try XCTUnwrap(sections.first { $0.note != nil }, "the current cycle section carries the estimate note")
        for section in sections {
            let items = FertilityPicturePresentation.items(for: section)
            XCTAssertEqual(items.first, .title(section.title))
            if let note = section.note { XCTAssertEqual(items[1], .note(note), section.title) }
            XCTAssertEqual(items.count, 1 + (section.note == nil ? 0 : 1) + section.rows.count)
        }
        XCTAssertEqual(withNote.kind, .currentCycle)
    }

    // MARK: The three screens

    func testWithNoSectionsAndConsentOnTheScreenIsTheEmptyState() {
        XCTAssertEqual(FertilityPicturePresentation.screen(isWithheld: false, sectionCount: 0), .empty)
        XCTAssertEqual(FertilityPicturePresentation.screen(isWithheld: false, sectionCount: 1), .sections)
        XCTAssertEqual(FertilityPicturePresentation.screen(isWithheld: true, sectionCount: 0), .withheld)
    }

    /// Core always says "still learning" in the Patterns section until three cycles are recorded,
    /// so with consent on, a picture is never without a section today: the empty state is the
    /// screen's answer should core ever return none. This pins what core does now.
    func testWithNothingRecordedCoreStillGivesThePatternsSection() throws {
        let nothing = picture(KitFixture.context(today: today, scan: false))
        XCTAssertEqual(nothing.sections.map(\.kind), [.patterns])
        XCTAssertEqual(nothing.sections.first?.rows.map(\.kind), [.stillLearning])
        XCTAssertEqual(FertilityPicturePresentation.screen(for: nothing), .sections)
    }

    func testWithConsentWithdrawnThePictureIsWithheld() {
        let withheld = picture(KitFixture.context(today: today, consent: false, cycleSettings: settings()))
        XCTAssertEqual(FertilityPicturePresentation.screen(for: withheld), .withheld)
        XCTAssertTrue(withheld.sections.isEmpty)
    }

    func testWithDataTheScreenListsSections() {
        XCTAssertEqual(FertilityPicturePresentation.screen(for: picture(testingContext())), .sections)
    }

    // MARK: Programme

    func testWithNoStartDateThereIsNoProgrammeSection() {
        XCTAssertNil(section(.programme, in: picture(KitFixture.context(today: today, cycleSettings: settings()))))
    }

    private func richLogs(throughDay last: Int, startedOn start: CalendarDate) -> [CalendarDate: DailyLog] {
        var logs: [CalendarDate: DailyLog] = [:]
        for day in 0..<last {
            logs[start.plusDays(day)] = DailyLog(mood: .good, energy: .high, sleepMinutes: 450, waterMl: 2_000)
        }
        return logs
    }

    func testOnDay23TheProgrammeSectionHoldsTheDayItsPhaseTodaysCountsAndTheWeek() throws {
        let start = today.minusDays(22)
        let context = KitFixture.context(today: today, day: 23, logs: richLogs(throughDay: 23, startedOn: start))
        let programme = try XCTUnwrap(section(.programme, in: picture(context)))
        let kinds = programme.rows.map(\.kind)
        XCTAssertEqual(kinds.first, .programmeDay)
        XCTAssertTrue(kinds.contains(.programmeToday))
        XCTAssertTrue(kinds.contains(.programmeWeek))
        XCTAssertFalse(kinds.contains(.programmeOverall))
        let day = try XCTUnwrap(programme.rows.first)
        XCTAssertEqual(day.value, FertilityPictureCopy.dayOfProgramme(23))
        let position = ProgrammeCalendar.position(context.planInput.state, on: today)
        guard case .active(_, _, let phase) = position else { return XCTFail("day 23 is an active day") }
        XCTAssertEqual(day.detail, ProgrammeContent.draft.phaseTitles[phase], "the day carries its phase")
    }

    func testFromDay91TheCompletedRowAndTheOverallFigureReplaceThem() throws {
        let start = today.minusDays(90)
        let context = KitFixture.context(today: today, day: 91, logs: richLogs(throughDay: 90, startedOn: start))
        let programme = try XCTUnwrap(section(.programme, in: picture(context)))
        let kinds = programme.rows.map(\.kind)
        XCTAssertEqual(kinds, [.programmeDay, .programmeOverall])
        XCTAssertEqual(programme.rows.first?.value, FertilityPictureCopy.programmeCompleted)
    }

    // MARK: Patterns

    /// Four recorded starts 28 days apart: three completed cycles, all recorded, in range.
    private func contextWithRecordedCycles(_ starts: Int) -> FertilityKitContext {
        let container = KitFixture.container()
        for index in 0..<starts {
            container.periods.recordStart(today.minusDays(27 + 28 * (starts - 1 - index)), today: today)
        }
        return KitFixture.context(from: container, today: today)
    }

    func testBelowThreeCountableCyclesThePatternsHoldTheStillLearningRowAndNoCrossCycleRow() throws {
        let context = contextWithRecordedCycles(3)
        XCTAssertFalse(CycleHistory.canMakeCrossCycleStatement(context.cycles))
        let patterns = try XCTUnwrap(section(.patterns, in: picture(context)))
        XCTAssertTrue(patterns.rows.contains { $0.kind == .stillLearning })
        XCTAssertFalse(patterns.rows.contains { $0.evidenceLevel == .crossCyclePattern })
    }

    func testWithThreeCountableCyclesThePatternsHoldACrossCycleRowAndNoStillLearningRow() throws {
        let context = contextWithRecordedCycles(4)
        XCTAssertTrue(CycleHistory.canMakeCrossCycleStatement(context.cycles))
        let patterns = try XCTUnwrap(section(.patterns, in: picture(context)))
        XCTAssertTrue(patterns.rows.contains { $0.evidenceLevel == .crossCyclePattern })
        XCTAssertFalse(patterns.rows.contains { $0.kind == .stillLearning })
    }

    func testAPatternRowsLabelIsItsLevelTitleAndTheScreenAddsNone() throws {
        let patterns = try XCTUnwrap(section(.patterns, in: picture(contextWithRecordedCycles(4))))
        let cross = try XCTUnwrap(patterns.rows.first { $0.evidenceLevel == .crossCyclePattern })
        XCTAssertEqual(cross.label, ProgrammeEvidenceCopy.title(for: .crossCyclePattern))
        let lines = FertilityPictureScreenCopy.rowLines(for: cross)
        XCTAssertEqual(lines, [cross.label, try XCTUnwrap(cross.value)], "the label and the statement, nothing looked up a second time")
        let learning = try XCTUnwrap(section(.patterns, in: picture(contextWithRecordedCycles(3)))?.rows.first { $0.kind == .stillLearning })
        XCTAssertEqual(FertilityPictureScreenCopy.rowLines(for: learning), [learning.label, ProgrammeEvidenceCopy.stillLearning])
    }

    // MARK: The pregnancy test row

    func testWithoutScanningThereIsNoOvulationRowAndNoPregnancyRow() throws {
        let testing = try XCTUnwrap(section(.testing, in: picture(testingContext(scan: false))))
        XCTAssertFalse(testing.rows.contains { $0.kind == .latestLhResult })
        XCTAssertFalse(testing.rows.contains { $0.kind == .pregnancyTestRecords })
    }

    func testThePregnancyRowIsTheSameWithOrWithoutASavedResultAndNeverCarriesOne() throws {
        let without = KitFixture.container()
        let with = KitFixture.container()
        XCTAssertTrue(with.hcg.create(HcgResult(recordedAt: noon(1), classification: .testLineDetected)))
        XCTAssertEqual(with.hcg.results.count, 1)

        func row(_ container: AppContainer) throws -> (FertilityPictureRow, FertilityKitContext) {
            let context = KitFixture.context(from: container, today: today)
            let testing = try XCTUnwrap(section(.testing, in: picture(context)))
            return (try XCTUnwrap(testing.rows.first { $0.kind == .pregnancyTestRecords }), context)
        }
        let (a, context) = try row(without)
        let (b, _) = try row(with)
        XCTAssertEqual(a, b, "the row says nothing about her")
        XCTAssertNil(a.value)
        XCTAssertNil(a.date)
        XCTAssertNil(a.dateRange)
        XCTAssertEqual(FertilityPictureScreenCopy.rowLines(for: a), [a.label, try XCTUnwrap(a.detail)])
        XCTAssertEqual(FertilityKitRoutes.route(for: a.destination, in: context), .scan(.pregnancyTest))
    }

    // MARK: Everyday health

    func testASeededLogGivesTheEverydayHealthRowsCoreLists() throws {
        let logs = [today: DailyLog(mood: .good, energy: .high, symptoms: ["Fatigue", "Cramps"], sleepMinutes: 445,
                                    waterMl: 750, foodGroups: ["vegetables", "fruit"])]
        let health = try XCTUnwrap(section(.everydayHealth, in: picture(KitFixture.context(today: today, logs: logs))))
        let kinds = Set(health.rows.map(\.kind))
        XCTAssertTrue(kinds.isSuperset(of: [.lastSleep, .waterToday, .latestMood, .latestEnergy, .symptomsToday]), "\(kinds)")
        XCTAssertEqual(health.rows.first { $0.kind == .symptomsToday }?.value, "2")
    }

    // MARK: Routes

    func testARowIsTappableThroughItsDestinationAndPlainWhenUnavailable() {
        let context = KitFixture.context(today: today)
        XCTAssertEqual(FertilityKitRoutes.route(for: .programme(.phTest), in: context), .tab(2))
        XCTAssertEqual(FertilityKitRoutes.route(for: .programme(.lhTest), in: KitFixture.context(today: today, scan: false)),
                       .unavailable)
    }
}
