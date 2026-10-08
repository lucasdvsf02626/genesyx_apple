import XCTest
import GenesyxCore
@testable import Genesyx

/// The Fertility Kit is DEBUG only until the owner has decided the production access route, the
/// consent wording, and the legal and clinical review of the draft content. Until then nothing
/// of it may be reachable in a Release build, and the development grant, its reset, the seed and
/// every kit launch argument must never be compiled into one.
///
/// A test run is always a DEBUG build, so Release is asked of the source tree, the way
/// `ScanReleaseGateTests` does. If one of these fails, the code is wrong, not the test. Every
/// failure names the file, and the line where there is one.
@MainActor
final class FertilityKitReleaseGateTests: XCTestCase {

    private static let ownerMessage = "Enabling the Fertility Kit for Release is the owner's decision."

    // MARK: - The flag

    func testTheFlagIsDebugOnly() throws {
        let source = Self.collapsed(try Self.source("App/Genesyx/UI/Learn/LearnModels.swift"))
        XCTAssertTrue(
            source.contains("#if DEBUG static let fertilityKit = true #else static let fertilityKit = false #endif"),
            "LearnModels.swift: `fertilityKit` must be true only inside `#if DEBUG`. " + Self.ownerMessage)
        XCTAssertEqual(Self.count("static let fertilityKit", in: source), 2,
                       "LearnModels.swift: `fertilityKit` is defined once, in its `#if DEBUG` / `#else` pair")
        XCTAssertEqual(Self.count("static let fertilityKit = true", in: source), 1, "LearnModels.swift. " + Self.ownerMessage)
    }

    func testTheFlagIsReadOnceByTheContainer() throws {
        var reads: [String: Int] = [:]
        for file in try Self.appSources() {
            let hits = Self.codeLines(try String(contentsOf: file, encoding: .utf8))
                .reduce(0) { $0 + Self.count("FeatureFlags.fertilityKit", in: $1) }
            if hits > 0 { reads[file.lastPathComponent] = hits }
        }
        XCTAssertEqual(reads, ["AppContainer.swift": 1], """
            `FeatureFlags.fertilityKit` is read once, as the default of `AppContainer.init`. Everything else
            asks the container. A second read is a second way into the feature.
            """)
    }

    func testTheContainerWiringIsPinned() throws {
        let container = Self.collapsed(Self.codeLines(try Self.source("App/Genesyx/Data/App/AppContainer.swift")).joined(separator: "\n"))
        for required in [
            "fertilityKit: Bool = FeatureFlags.fertilityKit, cycleHistory: Bool = FeatureFlags.cycleHistory) {",
            "programme.isCollectionPermitted = { fertilityKit && permitted() }",
            "programme.isAccessActive = { [kitAccess] in fertilityKit && kitAccess.hasAccess }",
            "if fertilityKit { _ = await kitAccess.refresh() }",
            "programme.clearLocalState()",
            "kitAccess.clearLocalState()",
        ] {
            XCTAssertTrue(container.contains(required), "AppContainer.swift must still contain `\(required)`")
        }
    }

    // MARK: - The ways in

    func testEveryWayInHangsOffTheFlag() throws {
        let more = Self.collapsed(Self.codeLines(try Self.source("App/Genesyx/UI/More/MoreView.swift")).joined(separator: "\n"))
        XCTAssertTrue(more.contains("if container.fertilityKit && kitAccess.hasAccess { row(.fertilityKit,"),
                      "MoreView.swift: the More row hangs off the flag AND off access. " + Self.ownerMessage)
        XCTAssertEqual(Self.count("if container.fertilityKit { FertilityKitHost(", in: more), 1,
                       "MoreView.swift: the host is built in one place, behind the flag. " + Self.ownerMessage)
        XCTAssertEqual(Self.count("FertilityKitHost(", in: more), 1, "MoreView.swift: the host is built in one place")
        XCTAssertTrue(more.contains("case .kitCycleHistory: if container.cycleHistory { kit { CycleHistoryView() } }"),
                      "MoreView.swift: cycle history stays behind its own flag as well")

        let profile = Self.collapsed(Self.codeLines(try Self.source("App/Genesyx/UI/Profile/ProfileView.swift")).joined(separator: "\n"))
        XCTAssertTrue(profile.contains("if kit.isHosted { FertilityKitAccountSection() }"),
                      "ProfileView.swift: the Fertility Kit area is drawn only when hosted, which only More does")

        let host = Self.collapsed(Self.codeLines(try Self.source("App/Genesyx/UI/FertilityKit/FertilityKitHost.swift")).joined(separator: "\n"))
        XCTAssertTrue(host.contains("isHosted: container.fertilityKit"),
                      "FertilityKitHost.swift: a context is hosted only while the flag is on")
        XCTAssertTrue(host.contains("hasAccess: container.fertilityKit && kitAccess.hasAccess"),
                      "FertilityKitHost.swift: access is decided here, and never without the flag")
    }

    /// Who may construct each kit screen. Checked over the lines a Release build compiles.
    private static let entryPoints: [String: Set<String>] = [
        "FertilityKitHost(": ["MoreView.swift"],
        "FertilityKitHomeView(": ["MoreView.swift"],
        "ProgrammeDayReaderView(": ["MoreView.swift"],
        "ProgrammeGuideView(": ["MoreView.swift"],
        "ProgrammeGuideSectionView(": ["MoreView.swift"],
        "DietPlanView(": ["MoreView.swift"],
        "ProgrammeReviewsView(": ["MoreView.swift"],
        "ProgrammeWeeklyReviewView(": ["MoreView.swift"],
        "ProgrammeNinetyDayReviewView(": ["MoreView.swift"],
        "FertilityPictureView(": ["MoreView.swift"],
        "CycleHistoryView(": ["MoreView.swift"],
        "FertilityKitAccountSection(": ["ProfileView.swift"],
        "FertilityKitAccessCard(": ["FertilityKitAccountSection.swift", "FertilityKitHomeView.swift", "FertilityKitHost.swift"],
        "FertilityKitActivationSheet(": ["FertilityKitAccessCard.swift"],
        "ProgrammeStartSheet(": ["FertilityKitAccessCard.swift"],
        "DietPlanMealSheet(": ["DietPlanView.swift"],
        "PeriodEditSheet(": ["CycleHistoryView.swift"],
        "ProgrammeTaskListView(": ["FertilityKitHomeView.swift", "ProgrammeDayReaderView.swift"],
        "ProgrammeRelatedContentList(": ["ProgrammeDayReaderView.swift", "ProgrammeGuideSectionView.swift"],
    ]

    /// Two halves, because half of these constructors are written by the screens' builders.
    /// ALWAYS: every file that constructs a name is in that name's list, so there is no second
    /// way in. ONLY once no placeholder file is left in the tree: equality, so a screen nothing
    /// builds is noticed too.
    func testKitScreensHaveOneWayIn() throws {
        var found: [String: Set<String>] = [:]
        var where_: [String: [String]] = [:]
        for file in try Self.appSources() {
            let name = file.lastPathComponent
            for (number, line, inDebug) in Self.annotated(try String(contentsOf: file, encoding: .utf8)) where !inDebug {
                for constructor in Self.entryPoints.keys where Self.constructs(constructor, in: line) {
                    found[constructor, default: []].insert(name)
                    where_[constructor, default: []].append("\(name):\(number)")
                }
            }
        }
        for (constructor, allowed) in Self.entryPoints {
            let extra = (found[constructor] ?? []).subtracting(allowed)
            XCTAssertTrue(extra.isEmpty, """
                `\(constructor)` is built outside the files that may build it (\(allowed.sorted().joined(separator: ", "))):
                \((where_[constructor] ?? []).filter { place in extra.contains { place.hasPrefix($0 + ":") } }.joined(separator: "\n"))
                """)
        }
        let placeholders = try Self.placeholderFiles()
        if placeholders.isEmpty {
            print("FertilityKitReleaseGateTests: STRICT half ran (no placeholder file is left)")
            XCTAssertEqual(found, Self.entryPoints, "every kit screen is built, and only where it may be")
        } else {
            print("FertilityKitReleaseGateTests: SKELETON half ran (\(placeholders.count) placeholder files are left)")
        }
    }

    // MARK: - Nothing for development outside DEBUG

    func testDevelopmentOnlyNamesStayInsideDebugRegions() throws {
        let names = ["uiTestKit", "KitUITestSeed", "seedGrantForUITests", "seedGrant(", "resetForQA",
                     "FertilityKitDebugControls", "FertilityKitDebugOptions", "withKitPreview"]
        let files = try Self.appSources()
        XCTAssertGreaterThan(files.count, 60, "Source scan found almost nothing: the path is wrong, not the code")

        var offenders: [String] = []
        var seenInDebug: Set<String> = []
        for file in files {
            for (number, line, inDebug) in Self.annotated(try String(contentsOf: file, encoding: .utf8)) {
                for name in names where line.contains(name) {
                    if inDebug { seenInDebug.insert(name) } else { offenders.append("\(file.lastPathComponent):\(number)  \(line)") }
                }
            }
        }
        XCTAssertEqual(seenInDebug, Set(names), "a search that finds nothing proves nothing")
        XCTAssertTrue(offenders.isEmpty, """
            A development-only part of the Fertility Kit is named outside `#if DEBUG`, so it would compile into Release:
            \(offenders.joined(separator: "\n"))
            """)
    }

    // MARK: - The flag, run

    func testWithTheFlagOffNothingOfTheKitWorks() async {
        let today = CalendarDate(2026, 6, 10)
        let container = KitFixture.container(fertilityKit: false, cycleHistory: false)
        container.kitAccess.seedGrantForUITests()
        XCTAssertEqual(container.programme.start(today: today), .refusedNoAccess)
        XCTAssertNil(container.store.load(ProgrammeProgressDTO.self, forKey: "programme_progress"))
        XCTAssertFalse(container.programme.markLessonRead("programme-day-001"))

        // A refresh would notice that the stand-in server no longer holds the grant and take the
        // cached access away. With the flag off the provider is never asked, so nothing changes.
        container.store.remove(forKey: "fertility_kit_qa_grants")
        await container.hydrate()
        XCTAssertFalse(container.kitAccess.isWorking)
        XCTAssertTrue(container.kitAccess.hasAccess, "hydrate() asked the provider although the flag is off")
        XCTAssertEqual(container.programme.start(today: today), .refusedNoAccess, "and cached access still starts nothing")
        XCTAssertEqual(container.programme.state, .notStarted)

        let kit = KitFixture.context(from: container, today: today)
        XCTAssertFalse(kit.isHosted)
        XCTAssertFalse(kit.hasAccess)
        XCTAssertEqual(kit.accessState, .noAccess)
    }

    func testWithTheFlagOnTheContainerWiresAccessToTheProgramme() async {
        let today = CalendarDate(2026, 6, 10)
        let container = KitFixture.container(fertilityKit: true, cycleHistory: false)
        XCTAssertEqual(container.programme.start(today: today), .refusedNoAccess)
        container.kitAccess.seedGrantForUITests()
        XCTAssertEqual(container.programme.start(today: today), .started(today))
        XCTAssertTrue(KitFixture.context(from: container, today: today).isHosted)
        XCTAssertEqual(KitFixture.context(from: container, today: today).accessState,
                       .active(day: 1, week: 1, phase: .buildTheFoundation))

        let withdrawn = KitFixture.container(fertilityKit: true, cycleHistory: false)
        withdrawn.kitAccess.seedGrantForUITests()
        withdrawn.consent.withdraw()
        XCTAssertEqual(withdrawn.programme.start(today: today), .refusedNoConsent)

        // The probe of the flag-off test can fail: with the flag on, hydrate() does ask.
        container.store.remove(forKey: "fertility_kit_qa_grants")
        await container.hydrate()
        XCTAssertFalse(container.kitAccess.hasAccess)

        container.kitAccess.seedGrantForUITests()
        container.clearLocalState()
        XCTAssertFalse(container.kitAccess.hasAccess)
        XCTAssertEqual(container.programme.state, .notStarted)
        XCTAssertNil(container.store.load(ProgrammeAccess.self, forKey: "fertility_kit_access"))
        XCTAssertNil(container.store.load(ProgrammeProgressDTO.self, forKey: "programme_progress"))
    }

    // MARK: - The checks can fail

    func testTheConstructorMatcher() {
        XCTAssertTrue(Self.constructs("DietPlanView(", in: "case .kitDietPlan: kit { DietPlanView() }"))
        XCTAssertTrue(Self.constructs("FertilityKitHost(", in: "if container.fertilityKit { FertilityKitHost(gated: gated,"))
        XCTAssertFalse(Self.constructs("DietPlanView(", in: "struct DietPlanView: View {"))
        XCTAssertFalse(Self.constructs("DietPlanView(", in: "YourDietPlanView()"), "a longer name that ends the same way is another type")
        XCTAssertFalse(Self.constructs("ProgrammeGuideView(", in: "ProgrammeGuideSectionView(section: section)"))
        let debugOnly = "#if DEBUG\n#Preview { DietPlanView() }\n#endif\nlet x = 1"
        XCTAssertEqual(Self.annotated(debugOnly).filter { !$0.inDebug }.map(\.line), ["let x = 1"])
    }

    // MARK: - Helpers (copied from `ScanReleaseGateTests`, which keeps its own private)

    /// `Name(` not preceded by a letter or a digit, so a longer type name is not a match.
    private static func constructs(_ constructor: String, in line: String) -> Bool {
        guard line.contains(constructor) else { return false }   // the cheap answer first: this runs per line, per name
        return line.range(of: "(?<![A-Za-z0-9_])" + NSRegularExpression.escapedPattern(for: constructor),
                   options: .regularExpression) != nil
    }

    /// Files that still hold the placeholder marker at the start of a line. The marker is put
    /// together from two pieces, so this file is not itself a match.
    private static func placeholderFiles() throws -> [String] {
        let marker = "// SKEL" + "ETON:"
        var files: [String] = []
        for folder in ["App", "Sources", "Tests"] {
            guard let walker = FileManager.default.enumerator(at: repoRoot.appendingPathComponent(folder),
                                                              includingPropertiesForKeys: nil) else { continue }
            for case let file as URL in walker where file.pathExtension == "swift" {
                let text = try String(contentsOf: file, encoding: .utf8)
                if text.components(separatedBy: "\n").contains(where: { $0.hasPrefix(marker) }) {
                    files.append(file.lastPathComponent)
                }
            }
        }
        return files
    }

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

    private static func collapsed(_ source: String) -> String {
        source.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func count(_ needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }
}
