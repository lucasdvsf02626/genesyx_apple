import Foundation
import GenesyxCore

enum DailyLogSyncState: Equatable {
    case saved
    case synced
    case willSyncWhenOnline

    var label: String {
        switch self {
        case .saved: return "Saved"
        case .synced: return "Synced"
        case .willSyncWhenOnline: return "Will sync when online"
        }
    }
}

/// Daily logs (mood/energy/symptoms/sleep/supplements/notes/water), date-keyed and persisted
/// on-device. Mirrors the Android `DailyLogRepository`.
///
/// Local saves always succeed — the device is the source of truth. A push that fails (offline,
/// signed out) leaves that day owed to the server; it is retried on the next refresh or app
/// foreground, and a pull will not overwrite a day that is still owed. Days the server has never
/// seen are carried up, which is how an existing on-device history reaches the cloud on first
/// sign-in.
@MainActor
final class DailyLogRepository: ObservableObject {

    @Published private(set) var logByDate: [CalendarDate: DailyLog] = [:]

    private let store: LocalStore
    private let backend: DailyLogBackend?
    private let key = "daily_logs"
    private let pendingKey = "daily_logs_pending"

    /// The days the server hasn't got yet. A v1.0 install has logs but no record of any push, so
    /// every logged day counts as owed.
    private var pendingDates: Set<CalendarDate> {
        didSet { store.save(Array(pendingDates), forKey: pendingKey) }
    }

    init(store: LocalStore, backend: DailyLogBackend? = nil) {
        self.store = store
        self.backend = backend

        var map: [CalendarDate: DailyLog] = [:]
        if let stored = store.load([String: DailyLogDTO].self, forKey: key) {
            for (k, v) in stored {
                if let date = CalendarDate(iso: k) { map[date] = v.domain }
            }
        }
        self.logByDate = map
        self.pendingDates = store.load([CalendarDate].self, forKey: pendingKey).map(Set.init) ?? Set(map.keys)
    }

    func log(on date: CalendarDate) -> DailyLog { logByDate[date] ?? DailyLog() }

    func waterMl(on date: CalendarDate) -> Int { log(on: date).waterMl }

    func syncState(on date: CalendarDate) -> DailyLogSyncState {
        guard backend != nil else { return .saved }
        return pendingDates.contains(date) ? .willSyncWhenOnline : .synced
    }

    func upsert(_ log: DailyLog, on date: CalendarDate) {
        logByDate[date] = log
        persist()
        pendingDates.insert(date)
        push(log, on: date)
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

    /// Set a day's sleep duration. `nil` or a non-positive value clears the value; otherwise clamp to 12h.
    func setSleep(_ minutes: Int?, on date: CalendarDate = .today()) {
        var entry = log(on: date)
        entry.sleepMinutes = minutes.flatMap { $0 > 0 ? min($0, 12 * 60) : nil }
        upsert(entry, on: date)
    }

    /// Consecutive days with water logged, ending today — or ending yesterday when today has no
    /// water yet (morning grace). Drives the hydration flame. Uses the canonical `TrackingEngine`
    /// rule so this number matches the one the Insights Consistency card shows.
    func streak(today: CalendarDate = .today()) -> Int {
        TrackingEngine.streak(days: TrackingEngine.hydrationDays(logByDate), today: today)
    }

    /// Push the days the server is owed, then pull the rest of her history. A day still owed is
    /// left alone — the local copy is the newer one. No-op when local-only.
    func refresh() async {
        guard let backend else { return }
        await drainPending()
        guard let remote = try? await backend.list() else { return }
        for (date, log) in remote where !pendingDates.contains(date) {
            logByDate[date] = log
        }
        persist()
    }

    /// Retry the writes the server never received, oldest day first. Stops at the first failure —
    /// if one push fails we're almost certainly offline, so the rest stay queued.
    func drainPending() async {
        guard let backend else { return }
        for date in pendingDates.sorted() {
            guard let log = logByDate[date] else { pendingDates.remove(date); continue }
            do {
                try await backend.upsert(log, on: date)
                if logByDate[date] == log { pendingDates.remove(date) }   // unless re-edited meanwhile
            } catch {
                break
            }
        }
    }

    private func push(_ log: DailyLog, on date: CalendarDate) {
        guard let backend else { return }
        Task {
            guard (try? await backend.upsert(log, on: date)) != nil else { return }   // stays owed
            if logByDate[date] == log { pendingDates.remove(date) }
        }
    }

    private func persist() {
        let snapshot = Dictionary(uniqueKeysWithValues: logByDate.map { ($0.key.iso, $0.value.dto) })
        store.save(snapshot, forKey: key)
    }

    /// Clear on-device state (memory + store). Invoked on sign-out / account deletion.
    func clearLocalState() {
        logByDate = [:]
        pendingDates = []
        store.remove(forKey: key)
        store.remove(forKey: pendingKey)
    }
}
