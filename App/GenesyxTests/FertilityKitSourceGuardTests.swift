import XCTest
@testable import Genesyx

/// What a Fertility Kit screen may not hold, asked of the source: wording of its own, the device's
/// clock, a feature flag, a review status, a second kind of navigation, anything that reports on
/// her, anything that cuts text short. Scans every Swift file under `UI/FertilityKit` and
/// `UI/CycleHistory`.
///
/// Coarse on purpose: it turns a private discovery on one simulator into one red test. Every
/// failure names the file and the line. These tests read the live tree, so while screens are
/// being built one can be red for a half-finished file: act on a failure that names YOUR file.
final class FertilityKitSourceGuardTests: XCTestCase {

    // MARK: - The lists

    /// Forbidden anywhere in a kit file, comments and literals included.
    static let forbiddenAnywhere = [
        // No console output and no reporting.
        "print(", "NSLog", "os_log", "Logger(", "dump(", "debugPrint", "ShareLink",
        // A screen asks the context, never a flag, a service or a store.
        "FeatureFlags.", "ScanServices", "@AppStorage", "SceneStorage", "UserDefaults", "ProgrammeTaskEngine.plan(",
        // Parts of the app the kit must not borrow.
        "allArticles", "learnArticles", "PlaceholderScreen", "StreakEngine", "usesLine", "usesFocusFood", "phaseFoods",
        "supplementPlan", "RecipeSheet", "RecipeCopy.footnote", "WeeklySummaryView",
        // Never said, never shown.
        "unlock", "GX90", "kitAccess.source",
        // A kit screen shows what core hands it and never reads a result or a value itself.
        "LhClassification", "phValue",
        // Review status and safety notes are never rendered.
        "ProgrammeReviewStatus", "ProgrammeContentReview", "itemsNeedingClinicalReview", "reviewItems(",
        ".status.rawValue", "containsHealthInterpretation", "safety.notes", "safetyNotes",
        // The clock: today is `kit.today`.
        ".today()", "CalendarDate.today(",
        // One kind of navigation, and content that is always in the tree.
        "NavigationLink(", ".navigationDestination(", "LazyVStack", "LazyHStack", "LazyVGrid", "LazyHGrid",
        "List(", "List {",
    ]

    /// The one file that may read the device's date and the launch options, and what it may name.
    static let allowed: [String: Set<String>] = ["FertilityKitContext.swift": ["CalendarDate.today(", "UserDefaults"]]

    static let forbiddenInActivationSheet = [".characters", ".words", ".sentences", "textContentType"]
    static let forbiddenInDietPlan = ["ProgressView", "Gauge", "percent", "%"]
    static let dietPlanFiles: Set<String> = ["DietPlanView.swift", "DietPlanMealSheet.swift"]
    static let allowedImports: Set<String> = ["SwiftUI", "GenesyxCore", "Foundation", "UIKit"]
    static let forbiddenLayout = [".lineLimit(", ".truncationMode(", ".minimumScaleFactor("]
    /// The one file that may give something a fixed size: the 44 pt icon tile.
    static let fixedSizeFile = "FertilityKitComponents.swift"

    // MARK: - The matchers (one per rule, used on the tree and on the samples below)

    /// Rule 2a. The names of `forbiddenAnywhere` found in a raw line, plus a bare `Date()`.
    static func forbiddenNames(in line: String, file: String) -> [String] {
        let permitted = allowed[file] ?? []
        var found = forbiddenAnywhere.filter { !permitted.contains($0) && contains($0, in: line) }
        if line.range(of: "(?<![A-Za-z])Date\\(\\)", options: .regularExpression) != nil { found.append("Date()") }
        return found
    }

    /// "unlock" is matched whatever its case, and `List` only as a whole name (a kit type may
    /// end in "List"); every other name as written.
    private static func contains(_ name: String, in line: String) -> Bool {
        if name == "unlock" { return line.lowercased().contains(name) }
        if name.hasPrefix("List") {
            return line.range(of: "(?<![A-Za-z])" + NSRegularExpression.escapedPattern(for: name), options: .regularExpression) != nil
        }
        return line.contains(name)
    }

    /// Rule 2b. A member access named exactly `review` or `iso`, in code with literals removed.
    static func forbiddenMembers(inCode code: String) -> [String] {
        let bare = withoutLiterals(code)
        return [".review", ".iso"].filter {
            bare.range(of: NSRegularExpression.escapedPattern(for: $0) + "\\b", options: .regularExpression) != nil
        }
    }

    /// Rule 2c. A call that would silently use the device's date. The repository's `setEnd` is
    /// told from the edit sheet's mode of the same name by its `forStart:` label.
    static func missingDate(inCode code: String) -> [String] {
        var found: [String] = []
        let setsAnEnd = code.contains("setEnd(") && code.contains("forStart:")
        if (code.contains("recordStart(") || setsAnEnd) && !code.contains("today:") { found.append("today:") }
        if code.contains("LogView(") && !code.contains("date:") { found.append("date:") }
        return found
    }

    /// Rule 1. String literals holding wording: a space, or an upper-case first letter.
    static func wording(inCode code: String) -> [String] {
        literals(in: code).filter { literal in
            literal.contains(" ") || (literal.first.map { $0.isLetter && $0.isUppercase } ?? false)
        }
    }

    /// Rule 8. A number given as a width or a height. `minHeight` and `maxWidth` pass.
    static func fixesASize(_ code: String) -> Bool {
        code.range(of: "\\.frame\\([^)]*(?<![A-Za-z])(width|height):\\s*[0-9]", options: .regularExpression) != nil
    }

    /// Rule 7. Bare identifiers that are the start of another identifier of the same file
    /// followed by a dot: they name a container, and a bare identifier there renames the
    /// children. Returned with the line each stands on.
    static func bareContainerIdentifiers(inLines lines: [(number: Int, code: String)]) -> [(number: Int, identifier: String)] {
        let all = lines.flatMap { identifierLiterals(in: $0.code) }
        var found: [(number: Int, identifier: String)] = []
        for (index, line) in lines.enumerated() {
            for literal in bareIdentifierLiterals(in: line.code) {
                let stem = literal.components(separatedBy: "\\(")[0]
                guard all.contains(where: { $0 != literal && $0.hasPrefix(stem + ".") }) else { continue }
                // Directly after `.accessibilityElement(children: .contain)`, on this line or the one before.
                let before = line.code.components(separatedBy: ".accessibilityIdentifier(\"" + literal)[0]
                let previous = index > 0 ? lines[index - 1].code.trimmingCharacters(in: .whitespaces) : ""
                let declared = before.trimmingCharacters(in: .whitespaces).hasSuffix(".accessibilityElement(children: .contain)")
                    || (before.trimmingCharacters(in: .whitespaces).isEmpty && previous.hasSuffix(".accessibilityElement(children: .contain)"))
                if !declared { found.append((line.number, literal)) }
            }
        }
        return found
    }

    // MARK: - The tree

    func testNoKitFileNamesWhatItMustNot() throws {
        var offenders: [String] = []
        for file in try Self.kitFiles() {
            for (number, raw) in file.text.components(separatedBy: "\n").enumerated() {
                for name in Self.forbiddenNames(in: raw, file: file.name) {
                    offenders.append("\(file.name):\(number + 1)  names `\(name)`")
                }
            }
            for line in file.lines {
                for member in Self.forbiddenMembers(inCode: line.code) {
                    offenders.append("\(file.name):\(line.number)  reads `\(member)`")
                }
                for parameter in Self.missingDate(inCode: line.code) {
                    offenders.append("\(file.name):\(line.number)  leaves out `\(parameter)`, so the device's date is used and not kit.today")
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty, "\n" + offenders.joined(separator: "\n"))
    }

    /// Wording lives in the core copy registries, where the guards read it. A label typed into a
    /// view, or put together there by interpolation, is wording no guard ever sees.
    func testNoKitViewHoldsWordingOfItsOwn() throws {
        var offenders: [String] = []
        for file in try Self.kitFiles() {
            for line in file.lines where !line.inDebug {
                for literal in Self.wording(inCode: line.code) {
                    offenders.append("\(file.name):\(line.number)  \"\(literal)\"")
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty, "\n" + offenders.joined(separator: "\n"))
    }

    func testTheActivationSheetShapesNothingSheTypes() throws {
        let file = try XCTUnwrap(try Self.kitFiles().first { $0.name == "FertilityKitActivationSheet.swift" })
        for line in file.lines {
            for name in Self.forbiddenInActivationSheet where line.code.contains(name) {
                XCTFail("\(file.name):\(line.number)  names `\(name)`")
            }
        }
    }

    /// Nutrition is a record. Nothing on Your Diet Plan can draw or state a share.
    func testYourDietPlanCannotShowAMark() throws {
        let files = try Self.kitFiles().filter { Self.dietPlanFiles.contains($0.name) }
        XCTAssertEqual(Set(files.map(\.name)), Self.dietPlanFiles)
        for file in files {
            for (number, raw) in file.text.components(separatedBy: "\n").enumerated() {
                for name in Self.forbiddenInDietPlan where raw.contains(name) {
                    XCTFail("\(file.name):\(number + 1)  names `\(name)`")
                }
            }
        }
    }

    /// Coarse: a file that presents a sheet or a cover hands it the app's environment somewhere.
    func testEverySheetIsHandedTheAppEnvironment() throws {
        for file in try Self.kitFiles() {
            guard let line = file.lines.first(where: { $0.code.contains(".sheet(") || $0.code.contains(".fullScreenCover(") }) else { continue }
            XCTAssertTrue(file.text.contains(".withAppEnvironment(container)"),
                          "\(file.name):\(line.number)  presents a sheet, and the file never calls `.withAppEnvironment(container)`")
        }
    }

    func testKitFilesImportOnlyWhatTheyMay() throws {
        for file in try Self.kitFiles() {
            for line in file.lines where line.code.hasPrefix("import ") || line.code.hasPrefix("@testable import ") {
                let module = line.code.components(separatedBy: " ").last ?? ""
                XCTAssertTrue(Self.allowedImports.contains(module), "\(file.name):\(line.number)  imports \(module)")
            }
        }
    }

    func testAContainerIdentifierIsNeverBare() throws {
        for file in try Self.kitFiles() {
            for found in Self.bareContainerIdentifiers(inLines: file.lines.map { ($0.number, $0.code) }) {
                XCTFail("""
                    \(file.name):\(found.number)  "\(found.identifier)" is the start of another identifier in this file, so it \
                    names a container: use `.kitContainer(`, `KitCard(identifier:)`, or put it directly after \
                    `.accessibilityElement(children: .contain)`
                    """)
            }
        }
    }

    /// The deterministic stand-in for "no label is cut short", which a UI test cannot see.
    func testNothingIsGivenAFixedSizeOrAllowedToCutTextShort() throws {
        for file in try Self.kitFiles() where file.name != Self.fixedSizeFile {
            for line in file.lines {
                for name in Self.forbiddenLayout where line.code.contains(name) {
                    XCTFail("\(file.name):\(line.number)  calls `\(name)`")
                }
                if Self.fixesASize(line.code) { XCTFail("\(file.name):\(line.number)  gives a fixed width or height") }
            }
        }
    }

    func testTheScanReadsTheKitFolders() throws {
        let names = Set(try Self.kitFiles().map(\.name))
        XCTAssertGreaterThanOrEqual(names.count, 23, "the scan found too few files: the path is wrong, not the code")
        for expected in ["FertilityKitContext.swift", "FertilityKitHost.swift", "FertilityKitRoutes.swift",
                         "FertilityKitComponents.swift", "FertilityKitHomeView.swift", "CycleHistoryView.swift",
                         "PeriodEditSheet.swift"] {
            XCTAssertTrue(names.contains(expected), "\(expected) was not read")
        }
    }

    // MARK: - The guard can fail

    func testEveryForbiddenNameIsCaughtAndTheNearestInnocentTextIsNot() {
        for name in Self.forbiddenAnywhere {
            XCTAssertEqual(Self.forbiddenNames(in: "    let x = \(name)", file: "DietPlanView.swift"), [name], name)
        }
        XCTAssertEqual(Self.forbiddenNames(in: "// we never say Unlocked here", file: "X.swift"), ["unlock"])
        XCTAssertEqual(Self.forbiddenNames(in: "let now = Date()", file: "X.swift"), ["Date()"])
        XCTAssertEqual(Self.forbiddenNames(in: "DatePicker(selection: $date, in: ...Date())", file: "X.swift"), ["Date()"])
        // The one file that reads the clock may name exactly two things, and nothing else.
        XCTAssertEqual(Self.forbiddenNames(in: "CalendarDate.today(.autoupdatingCurrent)", file: "FertilityKitContext.swift"), [])
        XCTAssertEqual(Self.forbiddenNames(in: "UserDefaults.standard.bool(forKey: key)", file: "FertilityKitContext.swift"), [])
        XCTAssertEqual(Self.forbiddenNames(in: "let d = Date()", file: "FertilityKitContext.swift"), ["Date()"])
        XCTAssertEqual(Self.forbiddenNames(in: "CalendarDate.today(.current)", file: "FertilityKitHost.swift"), ["CalendarDate.today("])

        for innocent in ["picker.toDate(calendar: calendar)", "ProgrammeConsistency.today(plan)", "kit.today",
                         "FertilityKitClock.current()", "ProgrammePlanService.plan(on: today, input: planInput)",
                         "VStack(alignment: .leading) {", "ProgrammeTaskListView(plan: plan, interactive: true)",
                         "kit.open(.kitGuide)", "CalendarDate(date: date, calendar: calendar)",
                         "ProgrammeRelatedContentList(references: references)", "struct ProgrammeRelatedContentList: View {"] {
            XCTAssertEqual(Self.forbiddenNames(in: innocent, file: "DietPlanView.swift"), [], innocent)
        }
    }

    func testTheMemberCheckCanFailAndLeavesNamesAndIdentifiersAlone() {
        XCTAssertEqual(Self.forbiddenMembers(inCode: "Text(page.definition.review.status.rawValue)"), [".review"])
        XCTAssertEqual(Self.forbiddenMembers(inCode: "section.review"), [".review"])
        XCTAssertEqual(Self.forbiddenMembers(inCode: ".accessibilityIdentifier(day.iso)"), [".iso"])
        for innocent in ["let review = ProgrammeReviewLogic.weekly(week: week, input: input)", "review.headline",
                         ".kitContainer(\"kit.review.week.headline\")", "kit.reviewInput(patterns: patterns)",
                         "kit.open(.kitReviews)", "\"kit.review.iso\"", "isolated.value"] {
            XCTAssertEqual(Self.forbiddenMembers(inCode: innocent), [], innocent)
        }
    }

    func testTheDateCheckCanFail() {
        XCTAssertEqual(Self.missingDate(inCode: "periods.recordStart(date)"), ["today:"])
        XCTAssertEqual(Self.missingDate(inCode: "periods.setEnd(end, forStart: start)"), ["today:"])
        XCTAssertEqual(Self.missingDate(inCode: "LogView().withAppEnvironment(container)"), ["date:"])
        XCTAssertEqual(Self.missingDate(inCode: "periods.recordStart(date, today: kit.today)"), [])
        XCTAssertEqual(Self.missingDate(inCode: "periods.setEnd(end, forStart: start, today: today)"), [])
        XCTAssertEqual(Self.missingDate(inCode: "LogView(date: day.date).withAppEnvironment(container)"), [])
        // The edit sheet's mode shares the name and takes no date.
        XCTAssertEqual(Self.missingDate(inCode: "case setEnd(start: CalendarDate, current: CalendarDate?)"), [])
        XCTAssertEqual(Self.missingDate(inCode: "sheet = .setEnd(start: cycle.start, current: nil)"), [])
    }

    func testTheWordingCheckCanFail() {
        XCTAssertEqual(Self.wording(inCode: "Text(\"Two words\")"), ["Two words"])
        XCTAssertEqual(Self.wording(inCode: "Text(\"Done\")"), ["Done"])
        XCTAssertEqual(Self.wording(inCode: "Text(\"day \\(day) of ninety\")"), ["day \\(day) of ninety"])
        for innocent in [".kitContainer(\"kit.home.today\")", "Image(systemName: \"chevron.right\")",
                         "case \"your-fertility-kit\", \"pregnancy-tests\":", "Text(FertilityKitCopy.done)",
                         ".accessibilityIdentifier(\"kit.task.\\(task.id)\")"] {
            XCTAssertEqual(Self.wording(inCode: innocent), [], innocent)
        }
        // A comment is not code.
        XCTAssertEqual(Self.lines(of: "let a = 1 // \"Two words\"\n// \"More words\"").flatMap { Self.wording(inCode: $0.code) }, [])
    }

    func testTheLayoutCheckCanFail() {
        XCTAssertTrue(Self.fixesASize(".frame(height: 120)"))
        XCTAssertTrue(Self.fixesASize(".frame(width: 44, height: 44)"))
        XCTAssertTrue(Self.fixesASize(".frame(maxWidth: .infinity).frame(height: 56)"))
        XCTAssertFalse(Self.fixesASize(".frame(maxWidth: .infinity, minHeight: 46)"))
        XCTAssertFalse(Self.fixesASize(".frame(maxWidth: .infinity, alignment: .leading)"))
        XCTAssertFalse(Self.fixesASize(".frame(minHeight: 44)"))
    }

    func testTheIdentifierShapeCheckCanFail() {
        func bare(_ source: String) -> [String] {
            Self.bareContainerIdentifiers(inLines: Self.lines(of: source).map { ($0.number, $0.code) }).map(\.identifier)
        }
        let child = "Text(title).accessibilityIdentifier(\"kit.access.title\")\n"
        XCTAssertEqual(bare(child + "VStack { }.accessibilityIdentifier(\"kit.access\")"), ["kit.access"])
        XCTAssertEqual(bare(child + "VStack { }.kitContainer(\"kit.access\")"), [])
        XCTAssertEqual(bare(child + "KitCard(identifier: \"kit.access\") { }"), [])
        XCTAssertEqual(bare(child + "VStack { }.accessibilityElement(children: .contain).accessibilityIdentifier(\"kit.access\")"), [])
        XCTAssertEqual(bare(child + "VStack { }\n    .accessibilityElement(children: .contain)\n    .accessibilityIdentifier(\"kit.access\")"), [])
        // A leaf beside another leaf is not a container, and neither is a name that merely starts the same.
        XCTAssertEqual(bare(child + "Text(body).accessibilityIdentifier(\"kit.access.body\")"), [])
        XCTAssertEqual(bare("Text(a).accessibilityIdentifier(\"kit.reviews\")\nText(b).accessibilityIdentifier(\"kit.reviewsNote\")"), [])
        // A row's children are named through `kitRow`, which is seen as an identifier too.
        XCTAssertEqual(bare("Text(a).kitRow(\"kit.home.today.progress\", label: label)\nVStack { }.accessibilityIdentifier(\"kit.home.today\")"),
                       ["kit.home.today"])
    }

    func testTheOtherListsCanFail() {
        for name in Self.forbiddenInActivationSheet { XCTAssertTrue("field\(name)".contains(name)) }
        XCTAssertFalse(Self.allowedImports.contains("OSLog"))
        XCTAssertFalse(Self.allowedImports.contains("StoreKit"))
        XCTAssertEqual(Self.lines(of: "#if DEBUG\nlet a = \"Two words\"\n#endif\nlet b = 1").map(\.inDebug), [true, false])
    }

    // MARK: - Reading the tree

    struct Line {
        let number: Int
        /// The line with its comment removed and trimmed.
        let code: String
        let inDebug: Bool
    }

    struct KitFile {
        let name: String
        let text: String
        let lines: [Line]
    }

    private static func kitFiles() throws -> [KitFile] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // GenesyxTests
            .deletingLastPathComponent()   // App
            .appendingPathComponent("Genesyx/UI")
        var files: [KitFile] = []
        for folder in ["FertilityKit", "CycleHistory"] {
            let urls = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent(folder), includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "swift" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            for url in urls {
                let text = try String(contentsOf: url, encoding: .utf8)
                files.append(KitFile(name: url.lastPathComponent, text: text, lines: lines(of: text)))
            }
        }
        return files
    }

    /// The code lines of a source: comments removed, blank lines and compiler directives left
    /// out, each with whether it sits inside `#if DEBUG` (as `ScanReleaseGateTests` reads it).
    static func lines(of source: String) -> [Line] {
        var frames: [Bool] = []
        var result: [Line] = []
        for (offset, raw) in source.components(separatedBy: "\n").enumerated() {
            let code = withoutComment(raw).trimmingCharacters(in: .whitespaces)
            if code.hasPrefix("#if") {
                frames.append(code == "#if DEBUG")
            } else if code.hasPrefix("#else") {
                if !frames.isEmpty { frames[frames.count - 1] = false }
            } else if code.hasPrefix("#endif") {
                if !frames.isEmpty { frames.removeLast() }
            } else if !code.isEmpty {
                result.append(Line(number: offset + 1, code: code, inDebug: frames.contains(true)))
            }
        }
        return result
    }

    /// The line up to a `//` that is not inside a string literal.
    private static func withoutComment(_ line: String) -> String {
        var inString = false
        var previous: Character?
        var index = line.startIndex
        while index < line.endIndex {
            let character = line[index]
            if character == "\"" && previous != "\\" { inString.toggle() }
            if !inString && character == "/" && previous == "/" {
                return String(line[..<line.index(before: index)])
            }
            previous = character
            index = line.index(after: index)
        }
        return line
    }

    private static let literalPattern = "\"((?:[^\"\\\\\\n]|\\\\.)*)\""

    static func literals(in code: String) -> [String] {
        captures(of: literalPattern, in: code)
    }

    private static func withoutLiterals(_ code: String) -> String {
        code.replacingOccurrences(of: literalPattern, with: "\"\"", options: .regularExpression)
    }

    /// Every identifier a line gives, by any of the ways a kit file gives one.
    private static func identifierLiterals(in code: String) -> [String] {
        captures(of: "(?:\\.accessibilityIdentifier\\(|kitContainer\\(|kitRow\\(|identifier: )" + literalPattern, in: code)
    }

    private static func bareIdentifierLiterals(in code: String) -> [String] {
        captures(of: "\\.accessibilityIdentifier\\(" + literalPattern, in: code)
    }

    private static func captures(of pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range(at: 1), in: text).map { String(text[$0]) }
        }
    }
}
