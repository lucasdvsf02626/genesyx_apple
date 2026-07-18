import XCTest
@testable import GenesyxCore

/// Validates the pH status thresholds and the pure insight computation (`PhInsightLogic`).
/// Ported verbatim from the Android `PhInsightLogicTest.kt`.
final class PhInsightLogicTests: XCTestCase {

    // Absolute value is irrelevant; only offsets matter. Fixed for determinism.
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let day: TimeInterval = 86_400

    private func reading(_ value: Double, _ daysAgo: Double) -> PhReading {
        PhReading(phValue: value, recordedAt: now.addingTimeInterval(-daysAgo * day))
    }

    // ── PhStatus.classify thresholds (acidic < 6.0, alkaline > 7.5, else optimal) ──

    func testPhStatusClassifiesAroundBoundaries() {
        XCTAssertEqual(PhStatus.classify(5.99), .acidic)
        XCTAssertEqual(PhStatus.classify(6.0), .optimal)
        XCTAssertEqual(PhStatus.classify(6.8), .optimal)
        XCTAssertEqual(PhStatus.classify(7.5), .optimal)
        XCTAssertEqual(PhStatus.classify(7.51), .alkaline)
    }

    func testPhSliderRangeConstantsMatchTheWeb() {
        XCTAssertEqual(PhStatus.min, 4.5, accuracy: 0)
        XCTAssertEqual(PhStatus.max, 9.0, accuracy: 0)
        XCTAssertEqual(PhStatus.step, 0.1, accuracy: 0)
    }

    // ── PhInsightLogic.compute ──

    func testNoReadingsYieldsTheEmptyDefault() {
        let r = PhInsightLogic.compute([], now: now)
        XCTAssertFalse(r.hasReadings)
        XCTAssertNil(r.currentValue)
        XCTAssertEqual(PhInsights().insight, r.insight)
    }

    func testSingleReadingIsFlatWithNoWeeklyInsightYet() {
        let r = PhInsightLogic.compute([reading(6.5, 0)], now: now)
        XCTAssertTrue(r.hasReadings)
        XCTAssertEqual(r.currentValue!, 6.5, accuracy: 1e-9)
        XCTAssertEqual(r.currentStatus, .optimal)
        XCTAssertEqual(r.trend, .flat)
        XCTAssertEqual(r.avg7!, 6.5, accuracy: 1e-9)
        // Fewer than 2 recent readings -> generic insight, no recommendation.
        XCTAssertEqual(r.insight, "Log a few more readings and we'll share gentle observations.")
        XCTAssertEqual(r.recommendation, "")
    }

    func testTwoOptimalReadingsGiveOptimalInsightAndRisingTrend() {
        let r = PhInsightLogic.compute([reading(6.4, 2), reading(6.8, 0)], now: now)
        XCTAssertEqual(r.trend, .up) // 6.8 - 6.4 = 0.4 > 0.1
        XCTAssertEqual(r.avg7!, 6.6, accuracy: 1e-9)
        XCTAssertTrue(r.insight.contains("optimal range"))
        XCTAssertEqual(r.recommendation, "", "dietary recommendations removed for App Store 1.4.1")
    }

    func testAcidicWeeklyAverageProducesTheAcidicInsight() {
        let r = PhInsightLogic.compute([reading(5.5, 1), reading(5.7, 0)], now: now)
        XCTAssertTrue(r.insight.contains("acidic"))
        XCTAssertEqual(r.recommendation, "", "dietary recommendations removed for App Store 1.4.1")
    }

    func testAlkalineWeeklyAverageProducesTheAlkalineInsight() {
        let r = PhInsightLogic.compute([reading(7.8, 1), reading(8.0, 0)], now: now)
        XCTAssertEqual(r.currentStatus, .alkaline)
        XCTAssertTrue(r.insight.contains("alkaline"))
    }

    func testFallingAndFlatTrendsRespectThe0_1Threshold() {
        let down = PhInsightLogic.compute([reading(7.0, 1), reading(6.5, 0)], now: now)
        XCTAssertEqual(down.trend, .down) // -0.5

        let flat = PhInsightLogic.compute([reading(6.50, 1), reading(6.55, 0)], now: now)
        XCTAssertEqual(flat.trend, .flat) // 0.05 within threshold
    }

    func test7DayAverageExcludesOlderReadingsThat30DayAverageIncludes() {
        let r = PhInsightLogic.compute(
            [reading(8.0, 20), reading(6.0, 1), reading(6.2, 0)],
            now: now
        )
        XCTAssertEqual(r.avg7!, 6.1, accuracy: 1e-9, "7-day avg excludes the 20-day-old reading")
        XCTAssertEqual(r.avg30!, (8.0 + 6.0 + 6.2) / 3, accuracy: 1e-9, "30-day avg includes all three")
    }

    func testReadingsOlderThan7DaysLeaveTheWeeklyAverageNil() {
        let r = PhInsightLogic.compute([reading(6.5, 10)], now: now)
        XCTAssertTrue(r.hasReadings)
        XCTAssertNil(r.avg7, "no readings within 7 days")
        XCTAssertEqual(r.avg30!, 6.5, accuracy: 1e-9)
    }
}
