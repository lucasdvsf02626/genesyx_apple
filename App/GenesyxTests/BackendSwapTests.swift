import XCTest
@testable import Genesyx
import GenesyxCore

/// Verifies repositories work both local-only (nil backend) and online-first (with a backend):
/// `refresh()` pulls from the backend; a nil backend keeps pure on-device behaviour.
@MainActor
final class BackendSwapTests: XCTestCase {

    private final class FakeCycleBackend: CycleBackend {
        var stored: CycleSettings?
        private(set) var upsertCount = 0
        func fetch() async throws -> CycleSettings? { stored }
        func upsert(_ settings: CycleSettings) async throws { upsertCount += 1; stored = settings }
    }

    private func makeStore() -> LocalStore {
        LocalStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
    }

    func testRefreshPullsFromBackend() async {
        let backend = FakeCycleBackend()
        backend.stored = CycleSettings(lastPeriodDate: CalendarDate(2026, 6, 1), cycleLength: 31, periodLength: 4)
        let repo = CycleRepository(store: makeStore(), backend: backend)
        XCTAssertNil(repo.settings)            // nothing local yet
        await repo.refresh()
        XCTAssertEqual(repo.settings?.cycleLength, 31)   // pulled from remote
    }

    func testNilBackendIsPureLocal() {
        let store = makeStore()
        let repo = CycleRepository(store: store, backend: nil)
        repo.upsert(CycleSettings(lastPeriodDate: CalendarDate(2026, 6, 1), cycleLength: 27, periodLength: 5))
        // A fresh instance over the same store reads the persisted value — no backend involved.
        XCTAssertEqual(CycleRepository(store: store).settings?.cycleLength, 27)
    }

    func testUpsertWritesThroughToBackend() async {
        let backend = FakeCycleBackend()
        let repo = CycleRepository(store: makeStore(), backend: backend)
        repo.upsert(CycleSettings(lastPeriodDate: CalendarDate(2026, 6, 1), cycleLength: 28, periodLength: 5))
        // Write-through is fire-and-forget; yield until it lands (bounded).
        for _ in 0..<50 where backend.upsertCount == 0 { await Task.yield() }
        XCTAssertEqual(backend.upsertCount, 1)
        XCTAssertEqual(backend.stored?.cycleLength, 28)
    }
}
