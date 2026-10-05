import XCTest
@testable import GenesyxCore

/// The programme core must stay clear of the streak rules, the intimacy field and pregnancy-test
/// results, and must never write to the console. Checked against the source itself.
final class ProgrammeSourceGuardTests: XCTestCase {

    private func programmeSources() throws -> [(name: String, text: String)] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appendingPathComponent("Sources/GenesyxCore/Programme")
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        return try files.map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
    }

    func testProgrammeSourcesReferenceNothingTheyMustNot() throws {
        let sources = try programmeSources()
        XCTAssertGreaterThanOrEqual(sources.count, 6)
        let forbidden = ["StreakEngine", "isMeaningfulLog", "sexualActivity", "HcgResult", "print(",
                         "NSLog", "os_log", "Logger(", "Date()", "random", "import SwiftUI", "import UIKit"]
        for source in sources {
            for term in forbidden {
                XCTAssertFalse(source.text.contains(term), "\(source.name) references \(term)")
            }
            XCTAssertFalse(source.text.contains("\u{2014}"), "em dash in \(source.name)")
            XCTAssertFalse(source.text.lowercased().contains("unlock"), "banned word in \(source.name)")
        }
    }

    /// The internal codes are written in exactly one place, and nowhere in a string that is shown.
    func testTheInternalCodesAppearOnlyInTheAccessFile() throws {
        for source in try programmeSources() where source.name != "ProgrammeAccess.swift" {
            XCTAssertFalse(source.text.contains("GX90"), source.name)
        }
        let access = try XCTUnwrap(try programmeSources().first { $0.name == "ProgrammeAccess.swift" })
        XCTAssertEqual(access.text.components(separatedBy: "GX90").count - 1, 3)
    }
}
