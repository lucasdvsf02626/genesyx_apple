import XCTest
@testable import Genesyx
import GenesyxCore

/// The pregnancy test data layer: the persisted DTO and `HcgRepository`, which is on-device only.
@MainActor
final class HcgRepositoryTests: XCTestCase {

    private func makeStore() -> LocalStore {
        LocalStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
    }

    private static let key = "hcg_results"

    private let provenance = HcgScanProvenance(
        scannerVersion: "scanner-1", configurationID: "strip-test", configurationVersion: "9.9.9")

    // MARK: - Local DTO

    func testDTORoundTrip() throws {
        let manual = HcgResult(id: "m", recordedAt: Date(timeIntervalSince1970: 1_000), classification: .invalid)
        let scanned = HcgResult(id: "s", recordedAt: Date(timeIntervalSince1970: 3_000),
                                classification: .testLineDetected, scan: provenance)

        for result in [manual, scanned] {
            let data = try JSONEncoder().encode(result.dto)
            let back = try JSONDecoder().decode(HcgResultDTO.self, from: data).result
            XCTAssertEqual(back, result)
        }
        XCTAssertEqual(manual.dto.result?.source, .manual)
        XCTAssertEqual(scanned.dto.result?.scan, provenance, "all three version strings must survive")
    }

    func testMinimalDTODecodesAsManual() throws {
        let data = Data(#"{"id":"a","recordedAt":0,"classification":"noTestLineDetected"}"#.utf8)
        let result = try XCTUnwrap(JSONDecoder().decode(HcgResultDTO.self, from: data).result)
        XCTAssertEqual(result.source, .manual)
        XCTAssertEqual(result.classification, .noTestLineDetected)
    }

    /// A scan is rebuilt only when all three version fields are there; otherwise it is manual.
    func testDTOWithAnIncompleteScanDecodesAsManual() {
        var dto = HcgResult(recordedAt: Date(), classification: .testLineDetected, scan: provenance).dto
        dto.scannerVersion = nil
        XCTAssertEqual(dto.result?.source, .manual)
        XCTAssertEqual(dto.result?.classification, .testLineDetected)
    }

    func testUnknownClassificationIsDroppedAndTheOthersStillLoad() {
        XCTAssertNil(HcgResultDTO(id: "x", recordedAt: Date(), classification: "unreadable").result)
        XCTAssertNil(HcgResultDTO(id: "x", recordedAt: Date(), classification: "positive").result)

        let store = makeStore()
        store.save([HcgResultDTO(id: "a", recordedAt: Date(timeIntervalSince1970: 1), classification: "noTestLineDetected"),
                    HcgResultDTO(id: "x", recordedAt: Date(timeIntervalSince1970: 2), classification: "unreadable"),
                    HcgResultDTO(id: "y", recordedAt: Date(timeIntervalSince1970: 3), classification: "positive"),
                    HcgResultDTO(id: "b", recordedAt: Date(timeIntervalSince1970: 4), classification: "testLineDetected")],
                   forKey: Self.key)
        let repo = HcgRepository(store: store)
        XCTAssertEqual(repo.results.map(\.id), ["a", "b"])
        XCTAssertEqual(repo.results.map(\.classification), [.noTestLineDetected, .testLineDetected],
                       "an unknown value is never shown as something else")
    }

    /// Only the outcome and three version strings are stored: no signal, no confidence, no cycle
    /// day, no sync bookkeeping.
    func testEncodedKeysAreOnlyTheAllowedSet() throws {
        let allowed: Set = ["id", "recordedAt", "classification",
                            "scannerVersion", "scanConfigurationID", "scanConfigurationVersion"]
        let scanned = HcgResult(recordedAt: Date(), classification: .testLineDetected, scan: provenance)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(scanned.dto)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), allowed)

        let manual = HcgResult(recordedAt: Date(), classification: .noTestLineDetected)
        let manualObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(manual.dto)) as? [String: Any])
        XCTAssertTrue(Set(manualObject.keys).isSubset(of: allowed))
    }

    // MARK: - Repository

    func testResultsSurviveARelaunchOrderedByRecordedAt() {
        let store = makeStore()
        let repo = HcgRepository(store: store)
        XCTAssertTrue(repo.create(HcgResult(id: "late", recordedAt: Date(), classification: .testLineDetected, scan: provenance)))
        XCTAssertTrue(repo.create(HcgResult(id: "early", recordedAt: Date().addingTimeInterval(-86_400),
                                            classification: .noTestLineDetected)))
        XCTAssertEqual(repo.results.map(\.id), ["early", "late"])

        let relaunched = HcgRepository(store: store)
        XCTAssertEqual(relaunched.results.map(\.id), ["early", "late"])
        XCTAssertEqual(relaunched.results.last?.scan, provenance)
    }

    func testAScannedInvalidIsRefusedAndAManualOneIsSaved() {
        let store = makeStore()
        let repo = HcgRepository(store: store)
        XCTAssertFalse(repo.create(HcgResult(recordedAt: Date(), classification: .invalid, scan: provenance)))
        XCTAssertTrue(repo.results.isEmpty)
        XCTAssertNil(store.load([HcgResultDTO].self, forKey: Self.key))

        XCTAssertTrue(repo.create(HcgResult(recordedAt: Date(), classification: .invalid)))
        XCTAssertEqual(repo.results.map(\.classification), [.invalid])
    }

    func testTheSameIdTwiceLeavesOneRow() {
        let store = makeStore()
        let repo = HcgRepository(store: store)
        let result = HcgResult(id: "a", recordedAt: Date(), classification: .noTestLineDetected)
        XCTAssertTrue(repo.create(result))
        XCTAssertTrue(repo.create(result))
        XCTAssertEqual(repo.results.count, 1)
        XCTAssertEqual(store.load([HcgResultDTO].self, forKey: Self.key)?.count, 1)
    }

    func testDeleteIsAHardRemovalAndAnUnknownIdIsANoOp() {
        let store = makeStore()
        let repo = HcgRepository(store: store)
        repo.create(HcgResult(id: "a", recordedAt: Date(timeIntervalSince1970: 1), classification: .noTestLineDetected))
        repo.create(HcgResult(id: "b", recordedAt: Date(timeIntervalSince1970: 2), classification: .testLineDetected))

        repo.delete(id: "nobody")
        XCTAssertEqual(repo.results.map(\.id), ["a", "b"])

        repo.delete(id: "a")
        XCTAssertEqual(repo.results.map(\.id), ["b"])
        XCTAssertEqual(store.load([HcgResultDTO].self, forKey: Self.key)?.map(\.id), ["b"], "nothing of it is left on disk")
        XCTAssertEqual(HcgRepository(store: store).results.map(\.id), ["b"])
    }

    func testDeleteAllAndClearLocalStateRemoveTheStoreKey() {
        for viaClearLocalState in [false, true] {
            let store = makeStore()
            let repo = HcgRepository(store: store)
            repo.create(HcgResult(recordedAt: Date(), classification: .testLineDetected))
            XCTAssertNotNil(store.load([HcgResultDTO].self, forKey: Self.key))

            if viaClearLocalState { repo.clearLocalState() } else { repo.deleteAll() }

            XCTAssertTrue(repo.results.isEmpty)
            XCTAssertNil(store.load([HcgResultDTO].self, forKey: Self.key), "not even an empty list is left")
            XCTAssertTrue(HcgRepository(store: store).results.isEmpty)
        }
    }

    // MARK: - Consent

    func testAClosedGateRefusesCreateButNotDeletion() {
        let store = makeStore()
        let repo = HcgRepository(store: store)
        repo.create(HcgResult(id: "a", recordedAt: Date(timeIntervalSince1970: 1), classification: .noTestLineDetected))
        repo.create(HcgResult(id: "b", recordedAt: Date(timeIntervalSince1970: 2), classification: .testLineDetected))
        repo.isCollectionPermitted = { false }

        XCTAssertFalse(repo.create(HcgResult(id: "c", recordedAt: Date(), classification: .testLineDetected)))
        XCTAssertEqual(repo.results.map(\.id), ["a", "b"])
        XCTAssertEqual(store.load([HcgResultDTO].self, forKey: Self.key)?.map(\.id), ["a", "b"])

        repo.delete(id: "a")
        XCTAssertEqual(repo.results.map(\.id), ["b"], "erasing what she recorded must stay available")
        repo.deleteAll()
        XCTAssertTrue(repo.results.isEmpty)
        XCTAssertNil(store.load([HcgResultDTO].self, forKey: Self.key))
    }

    // MARK: - Container

    func testWithdrawingConsentStopsNewResultsButNotDeletion() {
        let c = AppContainer(store: makeStore(), backend: nil, monitorNetwork: false)
        c.consent.grant()
        let kept = HcgResult(recordedAt: Date(), classification: .noTestLineDetected)
        XCTAssertTrue(c.hcg.create(kept))

        c.consent.withdraw()

        XCTAssertFalse(c.hcg.create(HcgResult(recordedAt: Date(), classification: .testLineDetected)),
                       "no new result may be recorded after a withdrawal")
        XCTAssertEqual(c.hcg.results.count, 1)

        c.hcg.delete(id: kept.id)
        XCTAssertTrue(c.hcg.results.isEmpty, "erasing what she recorded must stay available")
    }

    func testSignOutAndTheContainerWipeClearPregnancyResults() {
        let store = makeStore()
        let c = AppContainer(store: store, backend: nil, monitorNetwork: false)
        c.consent.grant()
        c.hcg.create(HcgResult(recordedAt: Date(), classification: .testLineDetected))
        XCTAssertNotNil(store.load([HcgResultDTO].self, forKey: Self.key))

        c.clearLocalState()

        XCTAssertTrue(c.hcg.results.isEmpty)
        XCTAssertNil(store.load([HcgResultDTO].self, forKey: Self.key))

        c.consent.grant()   // the wipe clears her consent with everything else
        c.hcg.create(HcgResult(recordedAt: Date(), classification: .testLineDetected))
        XCTAssertFalse(c.hcg.results.isEmpty)
        c.session.signOut()
        XCTAssertTrue(c.hcg.results.isEmpty, "the next person on this phone must not see her results")
        XCTAssertNil(store.load([HcgResultDTO].self, forKey: Self.key))
    }

    // MARK: - Source guards

    /// On-device only is a decision the owner and legal have not reopened: nothing in the
    /// repository may reach a server, and no remote file may know the record exists.
    func testTheRepositoryNamesNoBackendAndNoRemoteFileNamesIt() throws {
        let repository = Self.codeLines(try Self.source("App/Genesyx/Data/HcgRepository.swift"))
        XCTAssertGreaterThan(repository.count, 20, "Source scan found almost nothing: the path is wrong, not the code")
        for forbidden in ["Backend", "backend", "pendingSync", "async", "Task", "print("] {
            let hits = repository.filter { $0.contains(forbidden) }
            XCTAssertTrue(hits.isEmpty, "HcgRepository.swift must not contain `\(forbidden)`: \(hits)")
        }

        let remote = Self.repoRoot.appendingPathComponent("App/Genesyx/Data/Remote")
        let files = (FileManager.default.enumerator(at: remote, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL } ?? []).filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThanOrEqual(files.count, 3, "Source scan found almost nothing: the path is wrong, not the code")
        for file in files {
            XCTAssertFalse(try String(contentsOf: file, encoding: .utf8).lowercased().contains("hcg"),
                           "\(file.lastPathComponent) names the pregnancy test record")
        }
    }

    func testTheContainerGatesAndWipesButNeverSyncs() throws {
        let container = Self.codeLines(try Self.source("App/Genesyx/Data/App/AppContainer.swift")).joined(separator: "\n")
        XCTAssertTrue(container.contains("hcg.clearLocalState()"))
        XCTAssertTrue(container.contains("hcg.isCollectionPermitted = permitted"))
        XCTAssertFalse(container.contains("hcg.refresh"))
        XCTAssertFalse(container.contains("hcg.drainPending"))
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

    /// Every line that is not a comment.
    private static func codeLines(_ source: String) -> [String] {
        source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
    }
}
