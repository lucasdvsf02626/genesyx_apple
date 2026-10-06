import XCTest
@testable import Genesyx

/// Scan Test reads a medical-device strip, and the regulatory sign-off for that is PENDING (owner).
/// Until it is recorded, nothing of the feature may be reachable in a Release build, and the
/// scripted analyser must never be compiled into one.
///
/// A test run is always a DEBUG build, so most of this cannot be asked of the running app: it is
/// asked of the source tree instead, the way `LearnSurfaceGuardTests` does. If one of these fails,
/// do not edit the test to match the code. The checklist is in `.claude/tmp/scan-adr.md` section 9.
final class ScanReleaseGateTests: XCTestCase {

    private static let signOffMessage = """
        Enabling Scan Test for Release needs the owner's regulatory sign-off and the checklist in
        the ADR (.claude/tmp/scan-adr.md section 9).
        """

    // MARK: - The tab list

    func testMoreTakesProfilesPlaceAndNoTabMoves() {
        let six = ["Home", "Track", "pH", "Nutrition", "Insights", "Learn"]
        XCTAssertEqual(MainTabView.items(moreEnabled: false).map(\.title), six + ["Profile"],
                       "With Scan off the bar is the seven existing tabs, ending in Profile")
        XCTAssertEqual(MainTabView.items(moreEnabled: true).map(\.title), six + ["More"],
                       "With Scan on, More takes index 6: nothing is appended and no tab index moves")
        XCTAssertEqual(MainTabView.items(moreEnabled: false).map(\.icon),
                       ["house", "calendar", "drop", "leaf", "chart.bar", "book", "person"],
                       "With Scan off the bar's icons are the baseline's")
    }

    // MARK: - The flag

    func testTheFlagIsStillDebugOnly() throws {
        let source = Self.collapsed(try Self.source("App/Genesyx/UI/Learn/LearnModels.swift"))
        XCTAssertTrue(
            source.contains("#if DEBUG static let scanTest = true #else static let scanTest = false #endif"),
            Self.signOffMessage)
        XCTAssertEqual(Self.count("static let scanTest = true", in: source), 1, Self.signOffMessage)
        XCTAssertEqual(Self.count("static let scanTest", in: source), 2,
                       "`scanTest` is defined once, in its `#if DEBUG` / `#else` pair. " + Self.signOffMessage)
    }

    /// The flag is read in two places and no others: the tab bar (the Profile-or-More decision),
    /// and `AppContainer.hydrate()`, which pulls `lh_results` only while it is on.
    func testTheFlagIsReadOnlyByTheTabBarAndHydrate() throws {
        var reads: [String: Int] = [:]
        for file in try Self.appSources() {
            let hits = Self.codeLines(try String(contentsOf: file, encoding: .utf8))
                .reduce(0) { $0 + Self.count("FeatureFlags.scanTest", in: $1) }
            if hits > 0 { reads[file.lastPathComponent] = hits }
        }
        XCTAssertEqual(reads, ["MainTabView.swift": 1, "AppContainer.swift": 1], """
            `FeatureFlags.scanTest` may be read once in MainTabView and once in AppContainer.hydrate().
            A third read is a second way into the feature. \(Self.signOffMessage)
            """)
    }

    /// The More tab item and the More tab content both hang off one optional, which needs the
    /// flag AND a set of services; without it the seventh tab is Profile, as it always was.
    /// Ungating either would leave this build looking identical, so it is pinned in source.
    func testMoreHangsOffTheFlagAndTheServices() throws {
        let tabs = Self.collapsed(Self.codeLines(try Self.source("App/Genesyx/UI/MainTabView.swift")).joined(separator: "\n"))
        for required in [
            "private let scanServices: ScanServices? = FeatureFlags.scanTest ? ScanServices.current : nil",
            """
            if let scanServices { tabContent(Self.profileTab, MoreView(scanServices: scanServices, path: $morePath)) } \
            else { tabContent(Self.profileTab, ProfileView()) }
            """,
            "Self.items(moreEnabled: scanServices != nil)",
        ] {
            XCTAssertTrue(tabs.contains(required), "MainTabView must still contain `\(required)`. " + Self.signOffMessage)
        }
        XCTAssertEqual(Self.count("items(moreEnabled:", in: tabs), 2,
                       "The tab list is built in one place, from `scanServices`")
        XCTAssertEqual(Self.count("tabContent(Self.profileTab", in: tabs), 2,
                       "Index 6 holds More or Profile, chosen in one place")
        XCTAssertFalse(tabs.contains("tabContent(7"), "There is no eighth tab")

        // More cannot be built without services, and is the only thing that builds Scan home.
        let more = Self.collapsed(Self.codeLines(try Self.source("App/Genesyx/UI/More/MoreView.swift")).joined(separator: "\n"))
        XCTAssertTrue(more.contains("struct MoreView: View { let scanServices: ScanServices"),
                      "MoreView must need a non-optional set of scan services. " + Self.signOffMessage)
        XCTAssertTrue(more.contains("case .scan: ScanTabView(services: scanServices,"),
                      "Scan home is built from the services More was given. " + Self.signOffMessage)

        // Nothing else may open the feature: More is built only by the tab bar, Scan home only by
        // More, the camera cover only by Scan home, and the services are asked for only by the
        // tab bar. The LH half hangs off Scan home: its screen is built only there, its cover only
        // by that screen, and its services are asked for only by that screen. The pregnancy test
        // half hangs off Scan home in the same way.
        var entryPoints: [String: Set<String>] = [:]
        for file in try Self.appSources() {
            for line in Self.releaseLines(try String(contentsOf: file, encoding: .utf8)) {
                // So a pH name is not found inside the LH or pregnancy test name that ends with it.
                let phLine = line.replacingOccurrences(of: "LhScan", with: "Lh")
                    .replacingOccurrences(of: "HcgScan", with: "Hcg")
                for name in ["MoreView(", "ScanTabView(", "ScanCaptureView(", "ScanServices.current",
                             "LhScanHomeView(", "LhScanCaptureView(", "LhScanServices.current",
                             "HcgScanHomeView(", "HcgScanCaptureView(", "HcgScanServices.current"]
                where (name.hasPrefix("Lh") || name.hasPrefix("Hcg") ? line : phLine).contains(name) {
                    entryPoints[name, default: []].insert(file.lastPathComponent)
                }
            }
        }
        XCTAssertEqual(entryPoints, [
            "MoreView(": ["MainTabView.swift"],
            "ScanTabView(": ["MoreView.swift"],
            "ScanCaptureView(": ["ScanTabView.swift"],
            "ScanServices.current": ["MainTabView.swift"],
            "LhScanHomeView(": ["ScanTabView.swift"],
            "LhScanCaptureView(": ["LhScanHomeView.swift"],
            "LhScanServices.current": ["LhScanHomeView.swift"],
            "HcgScanHomeView(": ["ScanTabView.swift"],
            "HcgScanCaptureView(": ["HcgScanHomeView.swift"],
            "HcgScanServices.current": ["HcgScanHomeView.swift"],
        ], "Scan Test has exactly one way in, the gated More tab. " + Self.signOffMessage)
    }

    // MARK: - Nothing simulated outside DEBUG

    func testSimulatedAndDebugOnlyNamesStayInsideDebugRegions() throws {
        let forbidden = ["MockPh", "MockScan", "FakeScanFrameSource", "ScanDebug", "PhotosPicker", "PhotosUI",
                         "uiTestScanScenario", "uiTestConsentWithdrawn", "uiTestMore",
                         "MockLh", "uiTestLhScenario",
                         "MockHcg", "uiTestHcgScenario", "uiTestHcgSeed"]
        let files = try Self.appSources()
        XCTAssertGreaterThan(files.count, 60, "Source scan found almost nothing: the path is wrong, not the code")

        var offenders: [String] = []
        var sawMockInDebug = false
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (number, line, inDebug) in Self.annotated(source) {
                if inDebug {
                    if line.contains("MockScan") { sawMockInDebug = true }
                } else if forbidden.contains(where: { line.contains($0) }) {
                    offenders.append("\(file.lastPathComponent):\(number)  \(line)")
                }
            }
        }
        XCTAssertTrue(sawMockInDebug, "The scan never met `MockScan` inside `#if DEBUG`: a search that finds nothing proves nothing")
        XCTAssertTrue(offenders.isEmpty, """
            Simulated or DEBUG-only scan code is named outside `#if DEBUG`, so it would compile into Release:
            \(offenders.joined(separator: "\n"))
            """)
    }

    /// `#if !DEBUG` cannot be run by a test, so the Release branch is read instead.
    func testReleaseHasNoScanServices() throws {
        let source = Self.collapsed(try Self.source("App/Genesyx/Services/Scan/ScanServices.swift"))
        XCTAssertTrue(source.contains("static var current: ScanServices? { #if DEBUG"),
                      "`ScanServices.current` must still branch on DEBUG")
        XCTAssertTrue(source.contains("#else return nil #endif"),
                      "Outside DEBUG `ScanServices.current` must be nil: there is no real analyser. " + Self.signOffMessage)
    }

    func testReleaseHasNoLhScanServices() throws {
        let source = Self.collapsed(try Self.source("App/Genesyx/Services/Scan/LhScanServices.swift"))
        XCTAssertTrue(source.contains("static var current: LhScanServices? { #if DEBUG"),
                      "`LhScanServices.current` must still branch on DEBUG")
        XCTAssertTrue(source.contains("#else return nil #endif"),
                      "Outside DEBUG `LhScanServices.current` must be nil: there is no real analyser. " + Self.signOffMessage)
    }

    func testReleaseHasNoHcgScanServices() throws {
        let source = Self.collapsed(try Self.source("App/Genesyx/Services/Scan/HcgScanServices.swift"))
        XCTAssertTrue(source.contains("static var current: HcgScanServices? { #if DEBUG"),
                      "`HcgScanServices.current` must still branch on DEBUG")
        XCTAssertTrue(source.contains("#else return nil #endif"),
                      "Outside DEBUG `HcgScanServices.current` must be nil: there is no real analyser. " + Self.signOffMessage)
    }

    // MARK: - The pregnancy test stays inside the Scan area

    /// A pregnancy test result is read by nothing outside its own flow: no other screen, no
    /// notification, no prediction. So the files that may name it are listed, and its screens may
    /// not name the parts of the app a result must never reach.
    func testPregnancyTestCodeStaysInsideTheScanArea() throws {
        let views: Set<String> = ["HcgScanHomeView.swift", "HcgScanCaptureView.swift", "HcgResultView.swift",
                                  "HcgManualEntrySheet.swift"]
        let unreachable = ["pregnancyMode", "FocusMode", "focusMode", "CycleRepository", "CycleEngine",
                           "PreferencesRepository", "NotificationService", "TabRouter", "PregnancyView",
                           "pregnancyAccent", "print("]
        var naming: Set<String> = []
        var offenders: [String] = []
        for file in try Self.appSources() {
            let name = file.lastPathComponent
            for (number, line, _) in Self.annotated(try String(contentsOf: file, encoding: .utf8)) {
                if line.contains("Hcg") || line.contains("hcg") { naming.insert(name) }
                if views.contains(name), unreachable.contains(where: { line.contains($0) }) {
                    offenders.append("\(name):\(number)  \(line)")
                }
            }
        }
        // Equal, not a subset: a search that finds nothing must fail too.
        XCTAssertEqual(naming, views.union([
            "HcgRepository.swift", "PersistenceDTOs.swift", "AppContainer.swift", "GenesyxApp.swift",
            "HcgTestAnalyzing.swift", "MockHcgTestAnalyzer.swift", "HcgScanServices.swift", "ScanTabView.swift",
        ]), "Pregnancy test code is named outside the files that own it. A result must not leave the Scan area.")
        XCTAssertTrue(offenders.isEmpty, """
            A pregnancy test screen names a part of the app its result must never reach:
            \(offenders.joined(separator: "\n"))
            """)
    }

    // MARK: - Helpers

    /// `#filePath` is this file's location at compile time, App/GenesyxTests, so three components
    /// up is the repo root.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // GenesyxTests
            .deletingLastPathComponent()   // App
            .deletingLastPathComponent()   // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private static func appSources() throws -> [URL] {
        let root = repoRoot.appendingPathComponent("App/Genesyx")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw XCTSkip("Source tree not readable at \(root.path)")
        }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// Every line that is not a comment, numbered from 1, with whether it sits inside `#if DEBUG`.
    /// `#if DEBUG` opens a DEBUG region; any other `#if` opens a frame that is not one; `#else` and
    /// `#elseif` end the DEBUG part of their own frame; `#endif` closes it. A line is in a DEBUG
    /// region when any enclosing frame is.
    private static func annotated(_ source: String) -> [(number: Int, line: String, inDebug: Bool)] {
        var frames: [Bool] = []
        var result: [(number: Int, line: String, inDebug: Bool)] = []
        for (offset, raw) in source.components(separatedBy: .newlines).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#if") {
                frames.append(line == "#if DEBUG")
            } else if line.hasPrefix("#else") {   // also `#elseif`
                if !frames.isEmpty { frames[frames.count - 1] = false }
            } else if line.hasPrefix("#endif") {
                if !frames.isEmpty { frames.removeLast() }
            } else if !line.hasPrefix("//") {
                result.append((number: offset + 1, line: line, inDebug: frames.contains(true)))
            }
        }
        return result
    }

    private static func codeLines(_ source: String) -> [String] {
        annotated(source).map(\.line)
    }

    /// The lines a Release build compiles (conservatively: everything outside `#if DEBUG`).
    private static func releaseLines(_ source: String) -> [String] {
        annotated(source).filter { !$0.inDebug }.map(\.line)
    }

    private static func collapsed(_ source: String) -> String {
        source.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func count(_ needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }
}
