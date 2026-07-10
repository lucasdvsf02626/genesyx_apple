import XCTest
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

    func testOvulationFertileWindow() {
        let today = CalendarDate.today()
        let r = OvulationLogic.compute(
            settings: CycleSettings(lastPeriodDate: today.minusDays(13), cycleLength: 28, periodLength: 5),
            today: today)!
        XCTAssertEqual(r.cycleDay, 14)
        XCTAssertTrue(r.insight.contains("fertile window"))
        XCTAssertTrue(r.insight.contains("predicted"))
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
        }
    }
}
