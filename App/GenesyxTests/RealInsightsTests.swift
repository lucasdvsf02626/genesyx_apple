import XCTest
@testable import Genesyx
import GenesyxCore

/// Unit tests for the real-data Insights logic (cycle regularity, symptom patterns, ovulation).
final class RealInsightsTests: XCTestCase {

    // MARK: Cycle regularity

    func testCycleRegularityNilWhenNoSettings() {
        XCTAssertNil(CycleRegularityLogic.compute(settings: nil))
    }

    func testCycleRegularityInRange() {
        let r = CycleRegularityLogic.compute(settings: CycleSettings(lastPeriodDate: .today(), cycleLength: 28, periodLength: 5))!
        XCTAssertTrue(r.inTypicalRange)
        XCTAssertTrue(r.insight.contains("within the typical"))
    }

    func testCycleRegularityOutOfRange() {
        let r = CycleRegularityLogic.compute(settings: CycleSettings(lastPeriodDate: .today(), cycleLength: 18, periodLength: 5))!
        XCTAssertFalse(r.inTypicalRange)
        XCTAssertTrue(r.insight.contains("outside the typical"))
    }

    // MARK: Symptom patterns

    func testSymptomEmptyState() {
        let r = SymptomPatternLogic.compute(logs: [:], today: .today())
        XCTAssertEqual(r.dailyCounts.count, 28)
        XCTAssertEqual(r.daysWithSymptoms, 0)
        XCTAssertTrue(r.insight.contains("No symptoms logged"))
    }

    func testSymptomThinDataGuard() {
        let today = CalendarDate.today()
        var logs: [CalendarDate: DailyLog] = [:]
        for back in 0..<3 { logs[today.minusDays(back)] = DailyLog(symptoms: ["Fatigue"]) }
        let r = SymptomPatternLogic.compute(logs: logs, today: today)
        XCTAssertEqual(r.daysWithSymptoms, 3)
        XCTAssertTrue(r.insight.contains("Early days"), "Thin data must not claim a pattern")
    }

    func testSymptomTopSymptom() {
        let today = CalendarDate.today()
        var logs: [CalendarDate: DailyLog] = [:]
        for back in 0..<8 {
            logs[today.minusDays(back)] = DailyLog(symptoms: back < 3 ? ["Fatigue", "Cramps"] : ["Fatigue"])
        }
        let r = SymptomPatternLogic.compute(logs: logs, today: today)
        XCTAssertEqual(r.daysWithSymptoms, 8)
        XCTAssertEqual(r.topSymptom, "Fatigue")
        XCTAssertEqual(r.topSymptomCount, 8)
        XCTAssertTrue(r.insight.contains("You logged Fatigue 8 times"))
    }

    // MARK: Ovulation

    func testOvulationNilWhenNoSettings() {
        XCTAssertNil(OvulationLogic.compute(settings: nil))
    }

    func testOvulationPredictedDay() {
        let r = OvulationLogic.compute(settings: CycleSettings(lastPeriodDate: .today(), cycleLength: 28, periodLength: 5))!
        XCTAssertEqual(r.ovulationDay, 14)   // cycleLength - 14
        XCTAssertEqual(r.cycleDay, 1)
        XCTAssertTrue(r.insight.contains("predicted"), "Ovulation copy must always say 'predicted'")
    }

    func testTrackCycleRowMatchesCycleEngineNearOvulation() {
        let today = CalendarDate(2026, 7, 15)
        let settings = CycleSettings(lastPeriodDate: today.minusDays(11), cycleLength: 28, periodLength: 5)
        let engine = CycleEngine.cyclePhase(settings: settings, target: today)

        XCTAssertEqual(engine.dayOfCycle, 12)
        XCTAssertEqual(engine.ovulationDay, 14)
        XCTAssertEqual(CyclePredictionCopy.summary(settings: settings, today: today),
                       "Day 12 · Ovulation predicted in 2 days")
    }

    func testTrackCycleRowPredictedOvulationDay() {
        let today = CalendarDate(2026, 7, 15)
        let settings = CycleSettings(lastPeriodDate: today.minusDays(13), cycleLength: 28, periodLength: 5)

        XCTAssertEqual(CyclePredictionCopy.summary(settings: settings, today: today),
                       "Day 14 · Predicted ovulation day")
    }

    func testTrackCycleRowFallsBackToPhaseAwayFromOvulation() {
        let today = CalendarDate(2026, 7, 15)
        let settings = CycleSettings(lastPeriodDate: today.minusDays(19), cycleLength: 28, periodLength: 5)

        XCTAssertEqual(CyclePredictionCopy.summary(settings: settings, today: today),
                       "Day 20 · Luteal phase")
    }

    func testOvulationFertileWindow() {
        let today = CalendarDate.today()
        let r = OvulationLogic.compute(
            settings: CycleSettings(lastPeriodDate: today.minusDays(13), cycleLength: 28, periodLength: 5),
            today: today)!
        XCTAssertEqual(r.cycleDay, 14)
        XCTAssertTrue(r.insight.contains("fertile window"))
        XCTAssertTrue(r.insight.contains("predicted"))
    }

    func testFutureOvulationDayCopyStaysPredicted() {
        let today = CalendarDate(2026, 7, 15)
        let settings = CycleSettings(lastPeriodDate: today.minusDays(8), cycleLength: 28, periodLength: 5)
        let future = today.plusDays(5)
        let info = CycleEngine.cyclePhase(settings: settings, target: future)

        XCTAssertEqual(info.dayOfCycle, info.ovulationDay)
        XCTAssertEqual(CyclePredictionCopy.summary(settings: settings, today: future),
                       "Day 14 · Predicted ovulation day")
    }

    func testShortAndLongCycleOvulationBoundariesUseCycleEngine() {
        let start = CalendarDate(2026, 7, 1)
        for (cycleLength, expectedOvulationDay) in [(21, 7), (35, 21)] {
            let settings = CycleSettings(lastPeriodDate: start, cycleLength: cycleLength, periodLength: 5)
            let target = start.plusDays(expectedOvulationDay - 1)
            let info = CycleEngine.cyclePhase(settings: settings, target: target)
            let ovulation = OvulationLogic.compute(settings: settings, today: target)

            XCTAssertEqual(info.dayOfCycle, expectedOvulationDay)
            XCTAssertEqual(info.ovulationDay, expectedOvulationDay)
            XCTAssertEqual(info.fertileWindow.startDay, expectedOvulationDay - 5)
            XCTAssertEqual(info.fertileWindow.endDay, expectedOvulationDay + 1)
            XCTAssertEqual(CycleEngine.dayType(for: info), .ovulation)
            XCTAssertEqual(ovulation?.ovulationDay, info.ovulationDay)
        }
    }

    func testFertileWindowBoundariesAreInclusive() {
        let start = CalendarDate(2026, 7, 1)
        let settings = CycleSettings(lastPeriodDate: start, cycleLength: 28, periodLength: 5)
        let info = CycleEngine.cyclePhase(settings: settings, target: start)

        XCTAssertFalse(info.fertileWindow.contains(info.fertileWindow.startDay - 1))
        XCTAssertTrue(info.fertileWindow.contains(info.fertileWindow.startDay))
        XCTAssertTrue(info.fertileWindow.contains(info.fertileWindow.endDay))
        XCTAssertFalse(info.fertileWindow.contains(info.fertileWindow.endDay + 1))
    }

    func testFirstDayOfPeriodFallsBackToPhaseWithoutOvulationCertainty() {
        let today = CalendarDate(2026, 7, 15)
        let settings = CycleSettings(lastPeriodDate: today, cycleLength: 28, periodLength: 5)

        XCTAssertEqual(CyclePredictionCopy.summary(settings: settings, today: today),
                       "Day 1 · \(CyclePredictionCopy.phaseLabel(.period))")
        XCTAssertTrue(OvulationLogic.compute(settings: settings, today: today)?.insight.contains("predicted") == true)
    }

    func testCycleSettingsEditChangesDerivedPredictionWithoutNewState() {
        let today = CalendarDate(2026, 7, 15)
        let original = CycleSettings(lastPeriodDate: today.minusDays(11), cycleLength: 28, periodLength: 5)
        let edited = CycleSettings(lastPeriodDate: today.minusDays(11), cycleLength: 30, periodLength: 5)

        XCTAssertEqual(OvulationLogic.compute(settings: original, today: today)?.daysUntilOvulation, 2)
        XCTAssertEqual(OvulationLogic.compute(settings: edited, today: today)?.daysUntilOvulation, 4)
        XCTAssertNotEqual(CyclePredictionCopy.summary(settings: original, today: today),
                          CyclePredictionCopy.summary(settings: edited, today: today))
    }

    func testCalendarDateTodayIsStableAcrossDstRolloverDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))

        let beforeJump = try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 3,
            day: 8,
            hour: 1,
            minute: 30)))
        let afterJump = try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 3,
            day: 8,
            hour: 3,
            minute: 30)))

        XCTAssertEqual(CalendarDate.today(calendar, now: beforeJump), CalendarDate(2026, 3, 8))
        XCTAssertEqual(CalendarDate.today(calendar, now: afterJump), CalendarDate(2026, 3, 8))
    }

    // MARK: Content safety

    func testNoBannedPhrasesAcrossInsightCopy() {
        let banned = ["alkaline diet", "balance your ph", "boy or girl", "sex selection",
                      "gender sway", "sway the sex", "choose the sex", "detox", "flush toxins"]
        var strings: [String] = []
        for length in [18, 28, 40] {
            if let r = CycleRegularityLogic.compute(settings: CycleSettings(lastPeriodDate: .today(), cycleLength: length)) {
                strings.append(r.insight)
            }
        }
        strings.append(SymptomPatternLogic.compute(logs: [:]).insight)
        let today = CalendarDate.today()
        for back in 0..<28 {
            if let r = OvulationLogic.compute(
                settings: CycleSettings(lastPeriodDate: today.minusDays(back), cycleLength: 28, periodLength: 5),
                today: today) {
                strings.append(r.insight)
            }
        }
        for s in strings {
            let lower = s.lowercased()
            for phrase in banned { XCTAssertFalse(lower.contains(phrase), "Banned phrase \"\(phrase)\" in: \(s)") }
            XCTAssertFalse(lower.contains("confirmed ovulation"), "No ovulation copy may claim confirmation: \(s)")
        }
        let predictionSettings = CycleSettings(lastPeriodDate: today.minusDays(13), cycleLength: 28, periodLength: 5)
        XCTAssertFalse(CyclePredictionCopy.summary(settings: predictionSettings, today: today).lowercased().contains("confirmed ovulation"))
    }
}
