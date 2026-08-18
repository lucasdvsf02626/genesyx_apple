import XCTest
@testable import Genesyx

/// The guard `LearnModels.swift` asks for in prose: "No reader-facing surface should use it; they
/// all use `articles`."
///
/// Prose does not fail a build. Nutrition's article list read the raw `learnArticles` for two
/// releases, so it listed the weekly pieces that are written months ahead and dated forward —
/// every row opened straight onto the "unavailable" screen, because the deep link behind it
/// resolves through `articleBySlug`, which only returns a published piece. Nothing caught it: every
/// content test asserts things about the *arrays*, and the array was fine. The defect was in which
/// array one screen reached for.
///
/// So this scans the source. It is the only kind of test that can see the mistake, because the
/// mistake is a name.
final class LearnSurfaceGuardTests: XCTestCase {

    /// Files allowed to name the raw array. `LearnContent.swift` declares it; `LearnModels.swift`
    /// is the single legitimate consumer, wrapping it as `allArticles`.
    private let allowed: Set<String> = ["LearnContent.swift", "LearnModels.swift"]

    func testNoReaderFacingSurfaceUsesTheRawArticleArray() throws {
        let uiRoot = Self.repoRoot.appendingPathComponent("App/Genesyx/UI")
        let files = try Self.swiftFiles(under: uiRoot)
        XCTAssertGreaterThan(files.count, 20, "Source scan found almost nothing — the path is wrong, not the code")

        var offenders: [String] = []
        for file in files where !allowed.contains(file.lastPathComponent) {
            let source = try String(contentsOf: file, encoding: .utf8)
            // `LearnLibrary.allArticles` is caught by the same pattern, deliberately: a reader-facing
            // surface has no more business with the unfiltered accessor than with the raw array.
            for (offset, line) in source.components(separatedBy: .newlines).enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                guard !code.hasPrefix("//"), !code.hasPrefix("///") else { continue }
                if code.contains("learnArticles") || code.contains("allArticles") {
                    offenders.append("\(file.lastPathComponent):\(offset + 1)  \(code)")
                }
            }
        }

        XCTAssertTrue(offenders.isEmpty, """
            Reader-facing code reached for the unfiltered article set. Use `LearnLibrary.articles`,
            which hides anything dated in the future — otherwise the row renders and the tap lands
            on "unavailable".
            \(offenders.joined(separator: "\n"))
            """)
    }

    /// The scan above is only worth anything while there is something to withhold. If the weekly
    /// series ever fully publishes, `articles` and `allArticles` become the same list, the guard
    /// silently stops testing anything, and the next future-dated piece reintroduces the defect
    /// against a green suite.
    func testThereIsStillSomethingWithheldForTheGuardToCatch() {
        let withheld = LearnLibrary.allArticles.count - LearnLibrary.articles.count
        XCTAssertGreaterThan(withheld, 0, """
            Every article is published, so `articles` and `allArticles` are identical and the raw-array
            guard now proves nothing. Keep it — but know it is dormant until the next dated piece lands.
            """)
    }

    // MARK: - Helpers

    /// `#filePath` is this file's location at compile time — App/GenesyxTests/…​ — so three
    /// components up is the repo root.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // GenesyxTests
            .deletingLastPathComponent()   // App
            .deletingLastPathComponent()   // repo root
    }

    private static func swiftFiles(under root: URL) throws -> [URL] {
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw XCTSkip("Source tree not readable at \(root.path)")
        }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }
}
