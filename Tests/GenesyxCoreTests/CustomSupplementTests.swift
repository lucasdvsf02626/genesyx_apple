import XCTest
@testable import GenesyxCore

final class CustomSupplementTests: XCTestCase {

    func testValidity() {
        XCTAssertTrue(CustomSupplement(name: "Magnesium", dose: "200 mg", timeOfDay: .evening).isValid)
        XCTAssertFalse(CustomSupplement(name: "   ", dose: "").isValid)
    }

    /// 60 characters is the server's bound, not a nicety: `user_supplements` carries
    /// `check (char_length(btrim(name)) between 1 and 60)`, and a row past it is rejected. Refusing
    /// it here is what keeps a doomed write out of the retry queue, where it would be attempted
    /// forever.
    func testNameLongerThanTheServerAllowsIsRefused() {
        XCTAssertTrue(CustomSupplement(name: String(repeating: "a", count: 60), dose: "").isValid)
        XCTAssertFalse(CustomSupplement(name: String(repeating: "a", count: 61), dose: "").isValid)
    }

    /// The bound is on the TRIMMED name, matching `btrim` on the server — otherwise a name that is
    /// legal once stored would be refused here for its whitespace.
    func testTheLengthBoundIgnoresSurroundingSpaceJustAsTheServerDoes() {
        let padded = "  " + String(repeating: "a", count: 60) + "  "
        XCTAssertTrue(CustomSupplement(name: padded, dose: "").isValid)
    }

    func testListRoundTrip() {
        let list = [
            CustomSupplement(id: "a", name: "Magnesium", dose: "200 mg", timeOfDay: .evening),
            CustomSupplement(id: "b", name: "Vitamin C", dose: "500 mg", timeOfDay: .morning),
        ]
        let json = CustomSupplement.encodeList(list)
        XCTAssertEqual(CustomSupplement.decodeList(json), list)
    }

    func testDecodeGarbageIsEmptyNotCrash() {
        XCTAssertEqual(CustomSupplement.decodeList("not json"), [])
        XCTAssertEqual(CustomSupplement.decodeList(""), [])
    }

    // MARK: - Reading what the free-text box left behind

    /// The whole reason `CustomSupplement` decodes by hand. `time` used to be a free-text field, so
    /// devices in the wild hold strings no enum will ever match. A strict decode of the array is
    /// all-or-nothing — one unrecognisable string and `decodeList` returns `[]`, losing not the time
    /// but EVERY supplement she ever added.
    func testAnUnrecognisableStoredTimeCostsTheTimeAndNothingElse() {
        let stored = """
        [{"id":"a","name":"Magnesium","dose":"200 mg","time":"with breakfast"},\
        {"id":"b","name":"Vitamin C","dose":"500 mg","time":"morning"}]
        """

        let decoded = CustomSupplement.decodeList(stored)

        XCTAssertEqual(decoded.map(\.name), ["Magnesium", "Vitamin C"])
        XCTAssertNil(decoded.first?.timeOfDay)
        XCTAssertEqual(decoded.last?.timeOfDay, .morning)
    }

    /// The box she used to type into was free text, so the values that ARE one of the four often
    /// arrived capitalised or padded. Recovering them costs nothing and saves her retyping.
    func testTypedTimesAreRecoveredDespiteCaseAndSpace() {
        XCTAssertEqual(SupplementTime.parse("Evening"), .evening)
        XCTAssertEqual(SupplementTime.parse("  MORNING "), .morning)
        XCTAssertNil(SupplementTime.parse("after dinner"))
        XCTAssertNil(SupplementTime.parse(nil))
    }

    /// The wire values are a cross-platform contract: Android writes these exact strings and the
    /// server's `time_of_day` CHECK accepts only these. Renaming one after a client ships breaks
    /// both. The label is presentation and may be translated; the raw value may not change.
    func testWireValuesMatchTheServerCheckConstraint() {
        XCTAssertEqual(SupplementTime.allCases.map(\.rawValue),
                       ["morning", "afternoon", "evening", "anytime"])
        XCTAssertEqual(SupplementTime.allCases.map(\.label),
                       ["Morning", "Afternoon", "Evening", "Anytime"])
    }

    /// An unset time is a real state — the column is nullable — so it must survive a round trip as
    /// absent rather than as an empty string the server would reject.
    func testAnUnsetTimeIsOmittedRatherThanWrittenEmpty() {
        let json = CustomSupplement.encodeList([CustomSupplement(id: "a", name: "Zinc", dose: "")])

        XCTAssertFalse(json.contains("\"time\""))
        XCTAssertNil(CustomSupplement.decodeList(json).first?.timeOfDay)
    }

    /// A supplement stored before ids existed still has to load. It gets a fresh id rather than
    /// being dropped.
    func testAnEntryMissingItsIdIsKeptNotDiscarded() {
        let decoded = CustomSupplement.decodeList("""
        [{"name":"Magnesium","dose":"200 mg"}]
        """)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertFalse(decoded.first!.id.isEmpty)
    }
}
