import Foundation
import GenesyxCore

/// Daily logs (mood/energy/symptoms/sleep/supplements/notes/water), date-keyed and persisted
/// on-device. When a `DailyLogBackend` is provided, writes mirror to the remote and `refresh`
/// pulls a day. Backend is `nil` in the local-only v1. Mirrors the Android `DailyLogRepository`.
@MainActor
final class DailyLogRepository: ObservableObject {

    @Published private(set) var logByDate: [CalendarDate: DailyLog] = [:]

    private let store: LocalStore
    private let backend: DailyLogBackend?
    private let key = "daily_logs"

    init(store: LocalStore, backend: DailyLogBackend? = nil) {
        self.store = store
        self.backend = backend
        if let stored = store.load([String: DailyLogDTO].self, forKey: key) {
            var map: [CalendarDate: DailyLog] = [:]
            for (k, v) in stored {
                if let date = CalendarDate(iso: k) { map[date] = v.domain }
            }
            self.logByDate = map
        }
    }

    func log(on date: CalendarDate) -> DailyLog { logByDate[date] ?? DailyLog() }

    func waterMl(on date: CalendarDate) -> Int { log(on: date).waterMl }

    func upsert(_ log: DailyLog, on date: CalendarDate) {
        logByDate[date] = log
        persist()
        if let backend { Task { try? await backend.upsert(log, on: date) } }
    }

    /// Adjust a day's hydration by `deltaMl`, clamped to 0...10000.
    func adjustWater(_ deltaMl: Int, on date: CalendarDate = .today()) {
        var entry = log(on: date)
        entry.waterMl = min(max(entry.waterMl + deltaMl, 0), 10_000)
        upsert(entry, on: date)
    }

    /// Set a day's hydration to `ml`, clamped to 0...10000.
    func setWater(_ ml: Int, on date: CalendarDate = .today()) {
        var entry = log(on: date)
        entry.waterMl = min(max(ml, 0), 10_000)
        upsert(entry, on: date)
    }

    /// Consecutive days back from `today` (inclusive) that have water logged.
    func streak(today: CalendarDate = .today()) -> Int {
        var streak = 0
        var day = today
        while (logByDate[day]?.waterMl ?? 0) > 0 {
            streak += 1
            day = day.minusDays(1)
        }
        return streak
    }

    /// Pull a day's log from the remote (no-op when local-only).
    func refresh(date: CalendarDate = .today()) async {
        guard let backend, let remote = try? await backend.fetch(date: date) else { return }
        logByDate[date] = remote
        persist()
    }

    private func persist() {
        let snapshot = Dictionary(uniqueKeysWithValues: logByDate.map { ($0.key.iso, $0.value.dto) })
        store.save(snapshot, forKey: key)
    }

    /// Clear on-device state (memory + store). Invoked on sign-out / account deletion.
    func clearLocalState() {
        logByDate = [:]
        store.remove(forKey: key)
    }
}
