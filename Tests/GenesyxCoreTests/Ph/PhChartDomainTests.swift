import XCTest
@testable import GenesyxCore

/// The trend chart's readability, expressed as arithmetic.
///
/// The chart is the whole point of logging pH weekly — the Learn guide tells her to read the shape,
/// not the point. Scaled to the full loggable 3.8–7.0 it could not show a shape: the threshold sat
/// 78% of the way up, so the box was mostly amber and every real reading was pressed flat against
/// the floor. These tests fix the properties that make the shape legible.
final class PhChartDomainTests: XCTestCase {

    /// Fraction of the chart's height given to the healthy band.
    private func healthyShare(_ values: [Double]) -> Double {
        let d = PhStatus.chartDomain(for: values)
        return (4.5 - d.lowerBound) / (d.upperBound - d.lowerBound)
    }

    // MARK: - The defect

    /// Two months of ordinary weekly logging, all of it healthy. This is the common case and the
    /// one the old domain served worst.
    func testAnOrdinaryHistoryFillsTheChartRatherThanHuggingTheFloor() {
        let weekly = [4.1, 4.0, 4.2, 4.3, 4.1, 4.0, 4.2, 4.4]
        let d = PhStatus.chartDomain(for: weekly)

        XCTAssertEqual(d.upperBound, PhStatus.chartCeiling,
                       "nothing here forces the ceiling up, so it stays where it is legible")

        // Where her readings actually sit within the visible height. On the old 3.8–7.0 domain the
        // whole spread lived below 19%; the point of the fix is that it no longer does.
        let lowest = (weekly.min()! - d.lowerBound) / (d.upperBound - d.lowerBound)
        let highest = (weekly.max()! - d.lowerBound) / (d.upperBound - d.lowerBound)
        XCTAssertGreaterThan(highest, 0.35, "her readings must reach into the body of the chart")
        XCTAssertGreaterThan(highest - lowest, 0.20,
                             "and vary enough vertically to read as a shape rather than a flat line")
    }

    /// The colour balance. Amber is a warning; giving it three-quarters of a chart where every
    /// reading is healthy tells her something is wrong when nothing is.
    func testHealthyIsNotOutweighedByTheWarningColour() {
        XCTAssertEqual(healthyShare([4.1, 4.2, 4.0]), 0.5, accuracy: 0.001,
                       "with no elevated reading the threshold sits on the halfway line")
        XCTAssertGreaterThanOrEqual(healthyShare([]), 0.5, "and on an empty chart too")
    }

    // MARK: - Not at the cost of honesty

    /// A genuinely high reading is the one result she most needs to see. Holding the ceiling at 5.2
    /// would clamp it flat against the top edge and hide how high it went.
    func testAHighReadingOpensTheCeilingInsteadOfBeingClampedFlat() {
        let d = PhStatus.chartDomain(for: [4.1, 4.2, 6.1])
        XCTAssertGreaterThan(d.upperBound, 6.1, "the reading must sit inside the chart, not on its edge")
        XCTAssertLessThanOrEqual(d.upperBound, PhStatus.max, "and never beyond what is loggable")
    }

    /// A reading only just above the ceiling still gets headroom rather than being drawn on the border.
    func testAReadingJustOverTheCeilingStillGetsHeadroom() {
        let d = PhStatus.chartDomain(for: [5.1])
        XCTAssertGreaterThan(d.upperBound, 5.1)
    }

    /// The floor never moves. If it tracked the data, a calm month and an alarming month would draw
    /// the same picture, and comparing them across time would be meaningless.
    func testTheFloorIsFixedSoMonthsAreComparable() {
        for values in [[4.4, 4.5], [3.9], [6.9], []] {
            XCTAssertEqual(PhStatus.chartDomain(for: values).lowerBound, PhStatus.min,
                           "\(values): the floor is the bottom of the healthy band, always")
        }
    }

    /// Out-of-range input must not drag the axis somewhere absurd.
    func testAnImpossibleValueCannotStretchTheAxis() {
        let d = PhStatus.chartDomain(for: [14.0, 4.2])
        XCTAssertEqual(d.upperBound, PhStatus.max, "clamped to the loggable maximum")

        XCTAssertEqual(PhStatus.chartDomain(for: [-2.0]).upperBound, PhStatus.chartCeiling,
                       "a value below the floor cannot collapse the chart")
    }

    /// The domain must always be able to contain what it is asked to draw.
    func testEveryLoggableValueFitsInsideTheDomainItProduces() {
        for tenths in Int(PhStatus.min * 10)...Int(PhStatus.max * 10) {
            let v = Double(tenths) / 10
            let d = PhStatus.chartDomain(for: [v])
            XCTAssertTrue(d.contains(PhStatus.clamped(v)), "pH \(v) falls outside its own chart")
        }
    }
}
