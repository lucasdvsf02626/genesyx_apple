import XCTest
@testable import GenesyxCore

/// The three internal QA codes must not exist in a Release build. A test run is normally a
/// development build, so where the codes are written is asked of the source tree, and the last
/// test asks the build it was compiled into: run it with `-c release` to see the other half.
final class ProgrammeAccessReleaseGuardTests: XCTestCase {

    private let qaCodes = ["GX90-QA-001", "GX90-QA-002", "GX90-QA-003"]

    /// Four components above this file is the repo root, as in `ProgrammeSourceGuardTests`.
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func swiftSources(under folder: String) throws -> [(path: String, text: String)] {
        let base = Self.root.appendingPathComponent(folder)
        let walker = try XCTUnwrap(FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil))
        return try walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
            .map { ($0.path, try String(contentsOf: $0, encoding: .utf8)) }
    }

    private func count(_ needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    func testTheCodesAreWrittenOnlyInTheDebugBranchOfTheAccessFile() throws {
        let sources = try swiftSources(under: "Sources")
        XCTAssertGreaterThan(sources.count, 40, "Source scan found almost nothing: the path is wrong, not the code")
        let naming = sources.filter { $0.text.contains("GX90") }
        XCTAssertEqual(naming.count, 1, "the codes are written in one file: \(naming.map(\.path))")
        let access = try XCTUnwrap(naming.first)
        XCTAssertTrue(access.path.hasSuffix("/Sources/GenesyxCore/Programme/ProgrammeAccess.swift"), access.path)

        // One entry per open `#if`: true while inside `#if DEBUG` and before its `#else`.
        var frames: [Bool] = []
        var inDebugBranch = 0
        var elsewhere: [String] = []
        for raw in access.text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#if") {
                frames.append(line == "#if DEBUG")
            } else if line.hasPrefix("#else") {   // also `#elseif`
                if !frames.isEmpty { frames[frames.count - 1] = false }
            } else if line.hasPrefix("#endif") {
                if !frames.isEmpty { frames.removeLast() }
            } else if line.contains("GX90") {
                if frames.last == true { inDebugBranch += count("GX90", in: line) } else { elsewhere.append(line) }
            }
        }
        XCTAssertEqual(inDebugBranch, 3, "three codes, each between `#if DEBUG` and its `#else`")
        XCTAssertTrue(elsewhere.isEmpty, "\(elsewhere.count) line(s) would compile a code into a Release build")

        let collapsed = access.text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        XCTAssertTrue(collapsed.contains("#else private static let internalQACodes: Set<String> = [] #endif"),
                      "outside DEBUG the set of codes must be declared empty")
        XCTAssertEqual(count("static let internalQACodes", in: collapsed), 2,
                       "`internalQACodes` is declared once, in its `#if DEBUG` / `#else` pair")
    }

    /// The app validates through the core and never writes a code itself. Test folders are not read.
    func testTheAppTargetNeverWritesACode() throws {
        let sources = try swiftSources(under: "App/Genesyx")
        XCTAssertGreaterThan(sources.count, 60, "Source scan found almost nothing: the path is wrong, not the code")
        XCTAssertEqual(sources.filter { $0.text.contains("GX90") }.map(\.path), [])
    }

    func testThisBuildHonoursTheCodesOnlyWhenItIsADevelopmentBuild() {
        for code in qaCodes {
            for entry in [code, code.lowercased(), "  \(code)\n"] {
                let outcome = ProgrammeActivationCode.validate(entry, internalQAAllowed: true)
                #if DEBUG
                XCTAssertEqual(outcome, .accepted(source: .internalQA))
                #else
                XCTAssertEqual(outcome, .rejectedUnknown)
                #endif
            }
        }
    }
}
