import Foundation
import GenesyxCore

/// What the server knows about one day, as far as this device can tell.
///
/// Deliberately says nothing about connectivity. The old third case was named
/// `willSyncWhenOnline` and read "Will sync when online", which turned a fact about a *row* into a
/// claim about the *network* — so the ordinary second between a save and its push landing was
/// reported to her as being offline, over an app that was working perfectly. The state is now
/// `pendingSync`: this day is on the phone and not yet on the server, which is true whether she is
/// online or not.
enum DailyLogSyncState: Equatable {
    /// Momentary write confirmation, shown for ~1.2s after an edit.
    case saved
    /// The server has this day.
    case synced
    /// Saved on the device, not yet acknowledged by the server.
    case pendingSync

    /// Connectivity changes only the *explanation*, never the fact: the row is unsynced either way.
    /// Offline is the one case where "when you're back online" is a true statement rather than a
    /// guess, so it is the only case that mentions it.
    func label(online: Bool = true) -> String {
        switch self {
        case .saved: return "Saved"
        case .synced: return "Synced"
        case .pendingSync: return online ? "Saved on this phone" : "Saved — syncs when you're back online"
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

    var isCollectionPermitted: HealthDataCollectionGate = { true }

    private let store: LocalStore
    private let backend: DailyLogBackend?
    private let key = "daily_logs"
    private let pendingKey = "daily_logs_pending"

    /// The days the server hasn't got yet. A v1.0 install has logs but no record of any push, so
    /// every logged day counts as owed.
    ///
    /// `@Published` because `syncState` reads it: a push lands after the save that queued it, and
    /// without the notification the row kept showing the unsynced badge over a day the server
    /// already had, until some unrelated edit redrew it.
    @Published private var pendingDates: Set<CalendarDate> {
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
        return pendingDates.contains(date) ? .pendingSync : .synced
    }

    /// Every mutator on this repository — water, sleep, food groups, the log sheet — routes through
    /// here, so this one guard is the whole surface. See `HealthDataCollectionGate`.
    ///
    /// **Returns false when the gate refused the write.** It returned `Void` until build 22, which
    /// meant a caller could not tell a refusal from a save: the log sheet wrote nothing, dismissed
    /// itself, and the day was gone with no error. A gate that is correct at the repository and
    /// invisible at the UI is worse than no gate, because it spends the user's trust to enforce
    /// her own decision. Callers must branch on this rather than discard it.
    @discardableResult
    func upsert(_ log: DailyLog, on date: CalendarDate) -> Bool {
        guard isCollectionPermitted() else { return false }
        logByDate[date] = log
        // Owed before saved, deliberately: these are two separate writes to disk, and a kill
        // between them must leave a day queued that the server already has (harmless re-push)
        // rather than a day on disk that nothing will ever send.
        pendingDates.insert(date)
        persist()
        push(log, on: date)
        return true
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

    /// Add or remove one food group for a day. `id` is a `FoodGroup.rawValue`.
    ///
    /// Read-modify-write on the stored day rather than a whole-log replace, so ticking a group off
    /// in Nutrition cannot overwrite the mood she recorded in the log sheet a minute earlier.
    func toggleFoodGroup(_ id: String, on date: CalendarDate = .today()) {
        var entry = log(on: date)
        if entry.foodGroups.contains(id) { entry.foodGroups.remove(id) } else { entry.foodGroups.insert(id) }
        upsert(entry, on: date)
    }

    /// Mark a set of groups as eaten, in one write.
    ///
    /// Additive rather than a toggle: this is the "I cooked this" button on a recipe card, and a
    /// second tap means the same thing as the first. Toggling would silently *un*-log a group she
    /// had already ticked by hand. One upsert rather than one per group, so a four-group recipe is
    /// one push and not four — and the no-op guard means a repeat tap queues nothing at all.
    func logFoodGroups(_ ids: Set<String>, on date: CalendarDate = .today()) {
        var entry = log(on: date)
        guard !ids.isSubset(of: entry.foodGroups) else { return }
        entry.foodGroups.formUnion(ids)
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
    ///
    /// The pull is gated on consent like the writes are: pulling her logs back down is fresh
    /// processing of special-category data and has no lawful basis after a withdrawal. What is
    /// already on the device stays on screen — withdrawal stops collection, it is not erasure, and
    /// erasure has its own door in Profile. The drain above it is deliberately ungated.
    func refresh() async {
        guard let backend else { return }
        await drainPending()
        guard isCollectionPermitted() else { return }
        guard let remote = try? await backend.list() else { return }
        for (date, log) in remote where !pendingDates.contains(date) {
            logByDate[date] = log
        }
        persist()
    }

    /// Retry the writes the server never received, oldest day first. A failure of the connection —
    /// offline, or no session yet — is the same answer for every day behind it, so we stop and
    /// leave the queue for next time. A server-side rejection, though, is specific to that one day
    /// — stepping over it keeps a single poisoned write from starving every newer day behind it.
    func drainPending() async {
        guard let backend else { return }
        for date in pendingDates.sorted() {
            guard let log = logByDate[date] else { pendingDates.remove(date); continue }
            do {
                try await backend.upsert(log, on: date)
                if logByDate[date] == log { pendingDates.remove(date) }   // unless re-edited meanwhile
            } catch {
                if SyncError.shouldHaltDrain(error) { break }
                continue
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
