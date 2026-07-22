import XCTest
@testable import GenesyxCore

/// Pins the vaginal pH model: two-band classification, the 3.5–7.0 scale + clamp, legacy
/// exclusion from insights, and the verbatim copy. (Android's suite lacked the legacy-exclusion
/// and verbatim-copy checks — added here.)
final class PhInsightLogicTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let day: TimeInterval = 86_400

    private func reading(_ value: Double, _ daysAgo: Double, _ type: PhMeasurementType = .vaginal) -> PhReading {
        PhReading(phValue: value, recordedAt: now.addingTimeInterval(-daysAgo * day), measurementType: type)
    }

    // ── Two-band classification ──

    func testClassifyBoundaries() {
        XCTAssertEqual(PhStatus.classify(3.4), .healthy, "below the 3.8 healthy floor still classifies healthy (two-band)")
        XCTAssertEqual(PhStatus.classify(3.8), .healthy)
        XCTAssertEqual(PhStatus.classify(4.5), .healthy, "4.5 is inclusive-healthy")
        XCTAssertEqual(PhStatus.classify(4.51), .elevated)
        XCTAssertEqual(PhStatus.classify(7.0), .elevated)
        XCTAssertEqual(PhStatus.allCases.count, 2, "exactly two bands — no acidic/optimal/alkaline")
    }

    // ── Scale constants + clamp ──

    func testScaleConstants() {
        XCTAssertEqual(PhStatus.min, 3.5, accuracy: 0)
        XCTAssertEqual(PhStatus.max, 7.0, accuracy: 0)
        XCTAssertEqual(PhStatus.step, 0.1, accuracy: 0)
    }

    func testClampToRange() {
        XCTAssertEqual(PhStatus.clamped(3.4), 3.5, accuracy: 1e-9, "below-range clamps up to 3.5")
        XCTAssertEqual(PhStatus.clamped(7.1), 7.0, accuracy: 1e-9, "above-range clamps down to 7.0")
        XCTAssertEqual(PhStatus.clamped(4.2), 4.2, accuracy: 1e-9, "in-range unchanged")
    }

    // ── compute: empty / single / trend / averages ──

    func testNoReadingsYieldsEmptyDefault() {
        let r = PhInsightLogic.compute([], now: now)
        XCTAssertFalse(r.hasReadings)
        XCTAssertNil(r.currentValue)
        XCTAssertEqual(PhInsights().insight, r.insight)
    }

    func testSingleReadingHasNoWeeklyInsightYet() {
        let r = PhInsightLogic.compute([reading(4.2, 0)], now: now)
        XCTAssertTrue(r.hasReadings)
        XCTAssertEqual(r.currentValue!, 4.2, accuracy: 1e-9)
        XCTAssertEqual(r.currentStatus, .healthy)
        XCTAssertEqual(r.trend, .flat)
        XCTAssertEqual(r.insight, "Log a few more readings and we'll share gentle observations.")
        XCTAssertEqual(r.recommendation, "")
    }

    func testTwoHealthyReadingsGiveHealthyInsightNoSignpost() {
        let r = PhInsightLogic.compute([reading(4.0, 2), reading(4.2, 0)], now: now)
        XCTAssertEqual(r.trend, .up)                      // +0.2 > 0.1
        XCTAssertEqual(r.avg7!, 4.1, accuracy: 1e-9)
        XCTAssertEqual(r.currentStatus, .healthy)
        XCTAssertEqual(r.insight, "Your recent readings sit within the typical healthy range.")
        XCTAssertEqual(r.recommendation, "", "healthy carries no signpost")
    }

    func testTwoElevatedReadingsGiveElevatedInsightAndSignpost() {
        let r = PhInsightLogic.compute([reading(4.8, 1), reading(5.2, 0)], now: now)   // avg7 = 5.0 > 4.5
        XCTAssertEqual(r.currentStatus, .elevated)
        XCTAssertEqual(r.insight, "Your recent readings are above the typical healthy range.")
        XCTAssertEqual(r.recommendation, "If readings stay above the usual range over several days, a GP or pharmacist can talk it through with you.")
    }

    func testTrendThreshold() {
        let down = PhInsightLogic.compute([reading(4.5, 1), reading(4.0, 0)], now: now)
        XCTAssertEqual(down.trend, .down)
        let flat = PhInsightLogic.compute([reading(4.20, 1), reading(4.25, 0)], now: now)
        XCTAssertEqual(flat.trend, .flat, "0.05 is within the 0.1 threshold")
    }

    func test7DayAverageExcludesOlderReadingsThat30DayAverageIncludes() {
        let r = PhInsightLogic.compute([reading(6.0, 20), reading(4.0, 1), reading(4.2, 0)], now: now)
        XCTAssertEqual(r.avg7!, 4.1, accuracy: 1e-9)
        XCTAssertEqual(r.avg30!, (6.0 + 4.0 + 4.2) / 3, accuracy: 1e-9)
    }

    // ── Legacy exclusion ──

    func testLegacyReadingsExcludedFromInsights() {
        let r = PhInsightLogic.compute([
            reading(6.9, 3, .urine), reading(6.5, 2, .urine),   // legacy — must be ignored
            reading(4.0, 1, .vaginal), reading(4.2, 0, .vaginal),
        ], now: now)
        XCTAssertTrue(r.hasReadings)
        XCTAssertEqual(r.currentValue!, 4.2, accuracy: 1e-9, "latest VAGINAL reading, not the legacy 6.9")
        XCTAssertEqual(r.avg7!, 4.1, accuracy: 1e-9, "average excludes legacy urine")
        XCTAssertEqual(r.currentStatus, .healthy)
    }

    func testAllLegacyReturnsDefaultState() {
        let r = PhInsightLogic.compute([reading(6.5, 1, .urine), reading(6.9, 0, .urine)], now: now)
        XCTAssertFalse(r.hasReadings, "all-legacy input never classifies — returns the empty state")
        XCTAssertNil(r.currentValue)
        XCTAssertNil(r.currentStatus)
        XCTAssertEqual(PhInsights().insight, r.insight)
    }

    // ── Verbatim copy (hardcoded so a typo edited into a constant fails) ──

    func testCopyStringsAreVerbatim() {
        XCTAssertEqual(PhCopy.healthy, "Your recent readings sit within the typical healthy range.")
        XCTAssertEqual(PhCopy.elevated, "Your recent readings are above the typical healthy range.")
        XCTAssertEqual(PhCopy.elevatedSignpost, "If readings stay above the usual range over several days, a GP or pharmacist can talk it through with you.")
        XCTAssertEqual(PhCopy.disclaimer, "This tracker is for your own record and isn't medical advice. If a reading worries you, or a pattern persists, please speak to a GP, nurse, or pharmacist.")
        XCTAssertEqual(PhCopy.oneTimeNotice, "This tracker now records vaginal pH. Your earlier readings are kept and marked 'urine (legacy)'. New readings are saved as vaginal pH, on a different scale.")
        XCTAssertEqual(PhCopy.legacyMarker, "urine (legacy)")
    }

    // ── Banned-phrase guard over pH-surface copy (Learn pH content guarded in the app test target) ──

    func testPhCopyHasNoBannedClinicalOrDietTerms() {
        let banned = ["bv", "thrush", "infection", "candida", "vaginosis", "leafy greens", "whole grains", "mineral water"]
        let surfaces = [PhCopy.healthy, PhCopy.elevated, PhCopy.elevatedSignpost, PhCopy.disclaimer, PhCopy.oneTimeNotice, PhCopy.legacyMarker]
        for s in surfaces {
            let lower = s.lowercased()
            for term in banned {
                XCTAssertFalse(lower.contains(term), "Banned term \"\(term)\" in pH copy: \(s)")
            }
        }
    }
}
