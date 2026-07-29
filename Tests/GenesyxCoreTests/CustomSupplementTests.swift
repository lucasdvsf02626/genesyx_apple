import XCTest
@testable import GenesyxCore

final class CustomSupplementTests: XCTestCase {

    func testValidity() {
        XCTAssertTrue(CustomSupplement(name: "Magnesium", dose: "200 mg", time: "Evening").isValid)
        XCTAssertFalse(CustomSupplement(name: "   ", dose: "", time: "").isValid)
    }

    func testListRoundTrip() {
        let list = [
            CustomSupplement(id: "a", name: "Magnesium", dose: "200 mg", time: "Evening"),
            CustomSupplement(id: "b", name: "Vitamin C", dose: "500 mg", time: "Morning"),
        ]
        let json = CustomSupplement.encodeList(list)
        XCTAssertEqual(CustomSupplement.decodeList(json), list)
    }

    func testDecodeGarbageIsEmptyNotCrash() {
        XCTAssertEqual(CustomSupplement.decodeList("not json"), [])
        XCTAssertEqual(CustomSupplement.decodeList(""), [])
    }
}
