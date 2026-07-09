import Foundation
import GenesyxCore

/// Urine-pH readings. Local-first, ordered by `recordedAt` ascending; pH rounded to 1 dp on write
/// (web `round(v*10)/10`). When a `PhBackend` is provided, reads refresh from and writes mirror to
/// the remote. Backend is `nil` in the local-only v1. Mirrors the Android `PhRepository`.
@MainActor
final class PhRepository: ObservableObject {

    @Published private(set) var readings: [PhReading] = []

    private let store: LocalStore
    private let backend: PhBackend?
    private let key = "ph_readings"

    init(store: LocalStore, backend: PhBackend? = nil) {
        self.store = store
        self.backend = backend
        if let stored = store.load([PhReadingDTO].self, forKey: key) {
            self.readings = stored.map(\.domain).sorted { $0.recordedAt < $1.recordedAt }
        }
    }

    private func round1(_ value: Double) -> Double { (value * 10).rounded() / 10 }

    func create(_ reading: PhReading) {
        let normalized = PhReading(id: reading.id, phValue: round1(reading.phValue), recordedAt: reading.recordedAt, notes: reading.notes)
        readings = (readings + [normalized]).sorted { $0.recordedAt < $1.recordedAt }
        persist()
        if let backend { Task { try? await backend.create(normalized) } }
    }

    func update(_ reading: PhReading) {
        let normalized = PhReading(id: reading.id, phValue: round1(reading.phValue), recordedAt: reading.recordedAt, notes: reading.notes)
        readings = readings.map { $0.id == reading.id ? normalized : $0 }.sorted { $0.recordedAt < $1.recordedAt }
        persist()
        if let backend { Task { try? await backend.update(normalized) } }
    }

    func delete(id: String) {
        readings.removeAll { $0.id == id }
        persist()
        if let backend { Task { try? await backend.delete(id: id) } }
    }

    /// Pull the latest readings from the remote (no-op when local-only).
    func refresh() async {
        guard let backend, let remote = try? await backend.list(sinceDays: nil) else { return }
        readings = remote.sorted { $0.recordedAt < $1.recordedAt }
        persist()
    }

    private func persist() {
        store.save(readings.map(\.dto), forKey: key)
    }

    /// Clear on-device state (memory + store). Invoked on sign-out / account deletion.
    func clearLocalState() {
        readings = []
        store.remove(forKey: key)
    }
}
