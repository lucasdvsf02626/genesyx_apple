import XCTest

/// Cycle history states dates and counts of days. It carries no copy, no judgement of her cycles
/// and no prediction, and this scan keeps it that way. It reads the whole of each source file,
/// comments included, which is stricter than scanning string literals alone.
final class CycleHistorySourceGuardTests: XCTestCase {

    private func sources() throws -> [(name: String, text: String)] {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CycleHistory
            .deletingLastPathComponent()   // GenesyxCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // package root
            .appendingPathComponent("Sources/GenesyxCore/CycleHistory")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        return try files.map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
    }

    func testSourceIsScanned() throws {
        XCTAssertEqual(try sources().map(\.name).sorted(),
                       ["CycleHistory.swift", "CycleHistoryRules.swift", "PeriodRecord.swift", "PeriodSync.swift"])
    }

    /// "regular" also catches "irregular" and "regularity".
    func testNoJudgementOfHerCyclesAndNoOvulationLogic() throws {
        for (name, text) in try sources() {
            let lowered = text.lowercased()
            for banned in ["regular", "ovulat", "fertil", "luteal"] {
                XCTAssertFalse(lowered.contains(banned), "\(name) contains \"\(banned)\"")
            }
        }
    }

    /// No assumed cycle length, and no other bare day count: every limit is a named constant
    /// taken from `CycleEngine`.
    func testNoAssumedCycleLength() throws {
        for (name, text) in try sources() {
            for banned in ["28", "14", "21", "35"] {
                XCTAssertFalse(text.contains(banned), "\(name) contains the number \(banned)")
            }
            XCTAssertFalse(text.contains("defaultCycleLength"), "\(name) reads the default cycle length")
        }
    }

    func testNoUserFacingStrings() throws {
        for (name, text) in try sources() {
            XCTAssertFalse(text.contains("\""), "\(name) contains a string literal")
        }
    }
}
