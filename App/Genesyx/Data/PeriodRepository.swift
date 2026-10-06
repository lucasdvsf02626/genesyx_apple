import Foundation
import GenesyxCore

/// Cycle history: the periods she has recorded, and the cycles derived from them. Local-first and
/// shaped like `LhRepository`, with two differences in kind. A record is keyed by its start date,
/// not a random id, so the same period recorded on two devices is one record. And a record can be
/// edited: every change is decided by `CycleHistoryRules` in the core, never here.
///
/// The device is the source of truth. Every write is saved locally first and then queued for the
/// backend: a push that fails (offline, signed out, server down, table not there yet) leaves the
/// record marked `pendingSync` and is retried on the next `refresh` or app foreground. `refresh`
/// MERGES the remote snapshot into the local set (`PeriodSync.merge`) and never replaces it.
/// Deletes are tombstones so they reach her other devices. The one push that is not retried is a
/// record the server refuses for what is in it (`refusedStarts`).
///
/// Predictions do not read this. `CycleEngine` still works from `CycleSettings` alone; the only
/// link is that a start she records or deletes here moves `lastPeriodDate` to her latest start.
@MainActor
final class PeriodRepository: ObservableObject {

    /// What the UI sees: tombstones hidden, earliest start first.
    @Published private(set) var periods: [PeriodRecord] = []
    /// The cycles those periods describe, earliest first; the last one is open. Two starts a few
    /// days apart (the same period recorded on two devices with different dates) show here as a
    /// very short cycle. Nothing merges them: she deletes the one that is wrong.
    @Published private(set) var cycles: [DerivedCycle] = []

    /// Periods on this device that the server refused: a date outside the range it accepts,
    /// which this phone let through because its own date was wrong at the time
    /// (`CycleHistoryRules.accepts`). They stay in her history here, and are not offered to the
    /// server again until she changes or deletes them. Listed so the app can tell her.
    var refusedStarts: [CalendarDate] {
        records.filter { !$0.deleted && refused[$0.id] == $0.updatedAt }.map(\.id)
    }

    /// The record versions the server refused, as start date and the stamp of the refused edit,
    /// so a later edit of the same record is offered again. Kept beside the records because
    /// `pendingSync` stays true for them: the server does not hold them.
    @Published private var refused: [CalendarDate: Date] = [:] {
        didSet {
            if refused.isEmpty { store.remove(forKey: refusedKey) } else { store.save(refused, forKey: refusedKey) }
        }
    }

    private var records: [StoredPeriodRecord] = [] {
        didSet {
            periods = PeriodSync.visible(records)
            cycles = CycleHistory.cycles(from: records)
        }
    }

    /// Guards new records only. `delete` is deliberately outside it: erasing what she already
    /// recorded is Article 17 and must stay available after a withdrawal.
    var isCollectionPermitted: HealthDataCollectionGate = { true }

    /// Her current cycle settings, and the existing way of saving them. Wired by `AppContainer`
    /// to `CycleRepository`, so a moved `lastPeriodDate` is stored and synced as it is today.
    var cycleSettings: () -> CycleSettings? = { nil }
    var saveCycleSettings: (CycleSettings) -> Void = { _ in }

    private let store: LocalStore
    private let backend: PeriodBackend?
    private let key = "period_records"
    private let cursorKey = "period_records_cursor"
    private let refusedKey = "period_records_refused"
    /// Overlap subtracted from the cursor on each pull, to absorb clock skew against the server that
    /// stamps `updated_at`.
    private static let cursorOverlap: TimeInterval = 60

    /// The server's stamp from the last successful pull. Nil until the first one, which is what
    /// makes that first sync a full-history fetch.
    private var lastSyncedAt: Date? {
        didSet {
            if let date = lastSyncedAt { store.save(date, forKey: cursorKey) } else { store.remove(forKey: cursorKey) }
        }
    }

    init(store: LocalStore, backend: PeriodBackend? = nil) {
        self.store = store
        self.backend = backend
        self.lastSyncedAt = store.load(Date.self, forKey: cursorKey)
        self.refused = store.load([CalendarDate: Date].self, forKey: refusedKey) ?? [:]
        if let stored = store.load([PeriodRecordDTO].self, forKey: key) {
            // An entry whose start date cannot be read is dropped: the start is its identity.
            records = stored.compactMap(\.record)
            periods = PeriodSync.visible(records)
            cycles = CycleHistory.cycles(from: records)
        }
    }

    // MARK: - Writes

    /// Records a period start and says what that meant (`CycleHistoryRules.apply`): a new period,
    /// a past one, a correction of a nearby start, nothing, or a refused future date.
    /// **Returns nil when the consent gate refused the write.**
    @discardableResult
    func recordStart(_ date: CalendarDate, today: CalendarDate = .today()) -> PeriodStartOutcome? {
        guard isCollectionPermitted() else { return nil }
        seedIfEmpty(today: today)
        let change = CycleHistoryRules.apply(newStart: date, to: records, today: today, now: Date())
        guard change.records != records else { return change.outcome }
        commit(change.records)
        keepSettingsInStep()
        return change.outcome
    }

    /// Records, changes or (with nil) clears the last day of the period starting on `start`.
    /// **Returns nil when the consent gate refused the write.** Clearing an end is not gated.
    @discardableResult
    func setEnd(_ end: CalendarDate?, forStart start: CalendarDate, today: CalendarDate = .today()) -> PeriodEndOutcome? {
        guard end == nil || isCollectionPermitted() else { return nil }
        let change = CycleHistoryRules.setEnd(end, forStart: start, in: records, today: today, now: Date())
        if change.outcome == .updated { commit(change.records) }
        return change.outcome
    }

    /// Tombstone, not a removal: the deletion has to survive the next pull and reach her other
    /// devices. Returns false when no visible period starts on that date. Deleting her latest
    /// start moves `lastPeriodDate` back to the one before; deleting her only one leaves her
    /// settings where they were.
    @discardableResult
    func delete(start: CalendarDate) -> Bool {
        let remaining = CycleHistoryRules.delete(start: start, from: records, now: Date())
        guard remaining != records else { return false }
        commit(remaining)
        keepSettingsInStep()
        return true
    }

    /// The existing settings flow's way in, called by `CycleRepository.upsert` with what she is
    /// about to save and returning what should be stored. If the date she saved differs from the
    /// one in her settings it is a period start like any other, so history is appended to or
    /// corrected instead of overwritten, and the stored `lastPeriodDate` is her latest start.
    /// Her cycle length and period length are stored exactly as she set them.
    func settingsToStore(_ proposed: CycleSettings, today: CalendarDate = .today()) -> CycleSettings {
        guard isCollectionPermitted() else { return proposed }
        seedIfEmpty(today: today)   // from the settings she is replacing, so that period is not lost
        guard proposed.lastPeriodDate != cycleSettings()?.lastPeriodDate else { return proposed }
        let change = CycleHistoryRules.apply(newStart: proposed.lastPeriodDate, to: records, today: today, now: Date())
        guard change.records != records else { return proposed }
        commit(change.records)
        return CycleHistoryRules.settingsInStep(proposed, with: records) ?? proposed
    }

    /// Starts history with the one record copied from her cycle settings (`CycleHistoryRules.seed`).
    /// Does nothing once any record exists, tombstones included, so it happens once and a history
    /// she has emptied is never refilled. A last period date no period can be on seeds nothing;
    /// it is looked at again on every call, so the same settings seed once that date has arrived.
    func seedIfEmpty(today: CalendarDate = .today()) {
        guard isCollectionPermitted(),
              let seeded = CycleHistoryRules.seed(settings: cycleSettings(), records: records, today: today, now: Date()) else { return }
        commit([seeded])
    }

    // MARK: - Sync

    /// Merge the remote snapshot into the local set, then push anything the server is still owed.
    /// A failed fetch still drains the queue (that's the retry path). No-op when local-only.
    ///
    /// The pull is gated on consent like the writes are; the drain is not, because it is what
    /// carries her deletions to her other devices.
    ///
    /// Seeding waits for a pull that succeeded, so a history she emptied on another device (its
    /// tombstones arrive in that pull) is not refilled from this one. Then her settings are
    /// compared with history, which is how a `last_period_date` written by Android or an older
    /// build becomes a record (`PeriodReconcile`). A pull never writes her settings.
    ///
    /// A row that starts on a date no period can be on (`CycleHistoryRules.accepts`) is left out
    /// of the merge, so it is never her latest start and is never sent back. It is not tombstoned
    /// either: this device's date is no ground for deleting what another client wrote.
    func refresh(today: CalendarDate = .today()) async {
        guard let backend else { return }
        if isCollectionPermitted() {
            let since = lastSyncedAt.map { $0.addingTimeInterval(-Self.cursorOverlap) }
            if let page = try? await backend.list(updatedSince: since) {
                // A date this device already holds merges as usual: left out, the full merge would
                // read our copy as one the server has never seen and push it over theirs.
                let held = Set(records.map(\.id))
                let remote = page.payload.filter { held.contains($0.id) || CycleHistoryRules.accepts($0.id, today: today) }
                let waiting = page.payload.contains { !held.contains($0.id) && $0.id > today }
                records = since == nil
                    ? PeriodSync.merge(local: records, remote: remote)
                    : PeriodSync.mergeIncremental(local: records, remote: remote)
                persist()
                // Only ever forward, and only onto ground the server named (see `LhRepository`).
                // A row left out for starting after today may only be ahead of this device's date
                // (another time zone, or a clock that is behind), so the cursor waits and the row
                // is asked for again until its day arrives.
                if !waiting, let cursor = page.latestUpdatedAt, cursor > (lastSyncedAt ?? .distantPast) {
                    lastSyncedAt = cursor
                }
                #if DEBUG
                print("[Sync] period_records: \(remote.count) rows (\(since == nil ? "full" : "incremental"))")
                #endif
                seedIfEmpty(today: today)
                if let settings = cycleSettings() {
                    let change = PeriodReconcile.apply(lastPeriodDate: settings.lastPeriodDate, to: records,
                                                       today: today, now: Date())
                    if change.records != records { records = change.records; persist() }
                }
            }
        }
        await drainPending()
    }

    /// Push every record the server is still owed: tombstones first, then the rest, each oldest
    /// edit first. A correction is a tombstone on the old date and a record on the new one, so
    /// this order means another device can briefly see that period missing but never sees it
    /// twice. If the second write fails it stays queued and goes on the next drain.
    ///
    /// A failure of the connection (offline, or no session yet) is the same answer for every
    /// record behind it, so we stop and leave the queue for next time. A server-side rejection is
    /// specific to that one record and is stepped over.
    ///
    /// A record the server refused for what is in it (`SyncError.isRowRefused`) is stepped
    /// over too, and that version of it is not offered again. It stays on this device, still
    /// marked as owed, and shows in `refusedStarts`. A date that was only ahead of the server's
    /// would pass once that day came, but it was recorded under a wrong date and is hers to
    /// correct, not ours to send later. Any other rejection is offered again on the next drain,
    /// as before.
    func drainPending() async {
        guard let backend else { return }
        let pending = PeriodSync.pending(records).filter { refused[$0.id] != $0.updatedAt }
        for record in pending.filter(\.deleted) + pending.filter({ !$0.deleted }) {
            do {
                try await backend.upsert(record)
                clearPending(record)
            } catch {
                if SyncError.shouldHaltDrain(error) { break }
                if SyncError.isRowRefused(error) { refused[record.id] = record.updatedAt }
                continue
            }
        }
        persist()
    }

    /// Saves a record set the core rules returned and starts one ordered drain. A change can
    /// touch two or three records, so they are not pushed one by one.
    private func commit(_ changed: [StoredPeriodRecord]) {
        records = changed
        persist()
        guard backend != nil else { return }
        Task { await drainPending() }
    }

    /// Moves `lastPeriodDate` to her latest visible start after she recorded or deleted one.
    /// Only ever called for a change she made on this device, never after a pull.
    private func keepSettingsInStep() {
        let current = cycleSettings()
        guard let inStep = CycleHistoryRules.settingsInStep(current, with: records), inStep != current else { return }
        saveCycleSettings(inStep)
    }

    /// Clear the queue flag, but only if the record hasn't changed again while the push was in
    /// flight.
    private func clearPending(_ pushed: StoredPeriodRecord) {
        records = records.map { current in
            current.id == pushed.id && current.updatedAt == pushed.updatedAt
                ? current.marking(pendingSync: false)
                : current
        }
    }

    private func persist() {
        store.save(records.map(\.dto), forKey: key)
    }

    /// Clear on-device state (memory + store). Invoked on sign-out / account deletion.
    func clearLocalState() {
        records = []
        lastSyncedAt = nil          // next account starts from a full history fetch, not this one's cursor
        refused = [:]
        store.remove(forKey: key)
    }
}

/// What a `last_period_date` that did not come through this app's own history means for history.
/// Android and older iOS builds write `cycle_settings` only, so this is how their edits arrive.
/// Only her latest start is ever touched, and her settings are never written from here.
///
/// | `lastPeriodDate` against her latest visible start | Result |
/// |---|---|
/// | There is no visible start | no history change |
/// | The same date as any visible start | no history change |
/// | More than 10 days later | append a new record |
/// | Within 10 days, either side | correction: the latest start moves |
/// | More than 10 days earlier | no history change, settings left as she set them |
/// | After today | no history change |
enum PeriodReconcile {
    static func apply(
        lastPeriodDate date: CalendarDate,
        to records: [StoredPeriodRecord],
        today: CalendarDate,
        now: Date
    ) -> PeriodStartChange {
        let unchanged = PeriodStartChange(outcome: .noChange, records: records)
        guard let latest = PeriodSync.visible(records).last?.startDate,
              date >= latest.minusDays(CycleHistoryRules.correctionWindowDays) else { return unchanged }
        let change = CycleHistoryRules.apply(newStart: date, to: records, today: today, now: now)
        switch change.outcome {
        case .append: return change
        // The core corrects the nearest start. If that is not her latest, leave history alone.
        case .correction(let from, _) where from == latest: return change
        default: return unchanged
        }
    }
}
