import Foundation

/// What `CycleHistoryRules.apply` decided to do with a proposed period start.
public enum PeriodStartOutcome: Hashable, Sendable {
    /// The date is already a recorded start. Nothing is written.
    case noChange
    /// The date is close enough to an existing start to be the same period: that start moves.
    case correction(from: CalendarDate, to: CalendarDate)
    /// A new period after every recorded one.
    case append(CalendarDate)
    /// A past period, earlier than the latest recorded one.
    case backFill(CalendarDate)
    /// A date after today. Nothing is written.
    case refused
}

/// The decision on a proposed start together with the record set it leaves behind. For
/// `noChange` and `refused` the records are the ones passed in, untouched.
public struct PeriodStartChange: Hashable, Sendable {
    public let outcome: PeriodStartOutcome
    public let records: [StoredPeriodRecord]

    public init(outcome: PeriodStartOutcome, records: [StoredPeriodRecord]) {
        self.outcome = outcome
        self.records = records
    }
}

/// What `CycleHistoryRules.setEnd` decided to do with a proposed period end.
public enum PeriodEndOutcome: Hashable, Sendable {
    /// The record already has exactly this end (or already has none). Nothing is written.
    case noChange
    case updated
    /// No visible record starts on the given date.
    case refusedUnknownStart
    /// The end is before the start of its own period.
    case refusedBeforeStart
    /// The period would be longer than the longest period the app accepts.
    case refusedTooLong
    /// The end is on or after the next recorded start.
    case refusedReachesNextStart
    /// The end is after today.
    case refusedFuture
}

/// The decision on a proposed end together with the record set it leaves behind. Unless the
/// outcome is `updated`, the records are the ones passed in, untouched.
public struct PeriodEndChange: Hashable, Sendable {
    public let outcome: PeriodEndOutcome
    public let records: [StoredPeriodRecord]

    public init(outcome: PeriodEndOutcome, records: [StoredPeriodRecord]) {
        self.outcome = outcome
        self.records = records
    }
}

/// Every write to cycle history goes through here, so the period-started action, the settings sheet and
/// a pull from another client all reach the same decision for the same date. Pure: today and
/// the timestamp for changed records are passed in.
public enum CycleHistoryRules {

    /// How many days either side of an existing start a new date is read as a correction of that
    /// start instead of another period. It is the longest period the app accepts, reused so that
    /// no new number is introduced.
    public static let correctionWindowDays = CycleEngine.periodLengthRange.upperBound

    // MARK: - Recording a start

    /// Decides what a proposed period start means and returns the resulting records.
    ///
    /// | Situation | Outcome |
    /// |---|---|
    /// | After `today` | `refused` |
    /// | Already a visible start | `noChange` |
    /// | Within `correctionWindowDays` of a visible start, either side | `correction` of the nearest |
    /// | Later than the latest start (or no start exists) | `append` |
    /// | Earlier than the latest start | `backFill` |
    ///
    /// A correction cannot change a record's key, which is its start date, so it is written as a
    /// tombstone on the old date plus a record on the new one. The new record is `recorded`
    /// whatever the old one was (she has now stated the date herself) and keeps the old end date
    /// if that end is still valid for the new start. If the moved start now reaches back into the
    /// period before it, that earlier period's end is cleared.
    ///
    /// When two starts are equally near, the later one is corrected.
    public static func apply(
        newStart: CalendarDate,
        to records: [StoredPeriodRecord],
        today: CalendarDate,
        now: Date
    ) -> PeriodStartChange {
        guard newStart <= today else { return PeriodStartChange(outcome: .refused, records: records) }

        let periods = PeriodSync.visible(records)
        if periods.contains(where: { $0.startDate == newStart }) {
            return PeriodStartChange(outcome: .noChange, records: records)
        }

        let nearest = periods
            .filter { distance($0.startDate, newStart) <= correctionWindowDays }
            .min { (distance($0.startDate, newStart), $1.startDate) < (distance($1.startDate, newStart), $0.startDate) }

        guard let old = nearest else {
            let written = put(PeriodRecord(startDate: newStart), into: records, now: now)
            let isLatest = periods.last.map { newStart > $0.startDate } ?? true
            return PeriodStartChange(outcome: isLatest ? .append(newStart) : .backFill(newStart), records: written)
        }

        let others = periods.filter { $0.startDate != old.startDate }
        let next = others.first { $0.startDate > newStart }?.startDate
        let keptEnd = old.endDate.flatMap {
            endRefusal($0, start: newStart, nextStart: next, today: today) == nil ? $0 : nil
        }

        var written = put(old, into: records, now: now, deleted: true)
        written = put(PeriodRecord(startDate: newStart, endDate: keptEnd), into: written, now: now)
        if let before = others.last(where: { $0.startDate < newStart }),
           let end = before.endDate, end >= newStart {
            written = put(PeriodRecord(startDate: before.startDate, source: before.source), into: written, now: now)
        }
        return PeriodStartChange(outcome: .correction(from: old.startDate, to: newStart), records: written)
    }

    // MARK: - Recording an end

    /// Records, changes or (with `nil`) clears the last day of the period that starts on `start`.
    ///
    /// An end is accepted only if it is on or after its start, makes a period no longer than the
    /// longest the app accepts, falls before the next recorded start, and is not after `today`.
    /// The record's source is left as it was.
    public static func setEnd(
        _ end: CalendarDate?,
        forStart start: CalendarDate,
        in records: [StoredPeriodRecord],
        today: CalendarDate,
        now: Date
    ) -> PeriodEndChange {
        let periods = PeriodSync.visible(records)
        guard let period = periods.first(where: { $0.startDate == start }) else {
            return PeriodEndChange(outcome: .refusedUnknownStart, records: records)
        }
        if period.endDate == end { return PeriodEndChange(outcome: .noChange, records: records) }

        let next = periods.first { $0.startDate > start }?.startDate
        if let end, let refusal = endRefusal(end, start: start, nextStart: next, today: today) {
            return PeriodEndChange(outcome: refusal, records: records)
        }
        let updated = PeriodRecord(startDate: start, endDate: end, source: period.source)
        return PeriodEndChange(outcome: .updated, records: put(updated, into: records, now: now))
    }

    // MARK: - Deleting

    /// Deletes the period that starts on `start` by turning it into a tombstone, so the deletion
    /// reaches her other devices. With no visible record on that date the records come back
    /// untouched.
    ///
    /// On the next derivation the cycle that began there is gone and the cycle before it runs on
    /// to the following start (or becomes the open cycle, if the latest start was deleted).
    public static func delete(
        start: CalendarDate,
        from records: [StoredPeriodRecord],
        now: Date
    ) -> [StoredPeriodRecord] {
        guard let period = PeriodSync.visible(records).first(where: { $0.startDate == start }) else { return records }
        return put(period, into: records, now: now, deleted: true)
    }

    // MARK: - Seeding

    /// The one record history begins with: her current last period date, marked `seeded`.
    ///
    /// Returns nil when she has no cycle settings, and when any record exists already, tombstones
    /// included, so a history she has emptied on purpose is never refilled. Nothing else is ever
    /// made up: no earlier periods, no end date, no lengths.
    public static func seed(
        settings: CycleSettings?,
        records: [StoredPeriodRecord],
        now: Date
    ) -> StoredPeriodRecord? {
        guard let settings, records.isEmpty else { return nil }
        return StoredPeriodRecord(
            period: PeriodRecord(startDate: settings.lastPeriodDate, source: .seeded),
            updatedAt: now,
            pendingSync: true
        )
    }

    // MARK: - Keeping the current settings in step

    /// Her cycle settings with `lastPeriodDate` moved to the latest visible start. Nothing else
    /// changes: the cycle length and period length she chose are never rewritten from history.
    ///
    /// With no visible record the settings come back exactly as given, so deleting her only
    /// period leaves her predictions where they were. With no settings there is nothing to keep
    /// in step, and none are created.
    public static func settingsInStep(
        _ settings: CycleSettings?,
        with records: [StoredPeriodRecord]
    ) -> CycleSettings? {
        guard let settings, let latest = PeriodSync.visible(records).last else { return settings }
        return CycleSettings(
            lastPeriodDate: latest.startDate,
            cycleLength: settings.cycleLength,
            periodLength: settings.periodLength
        )
    }

    // MARK: - Helpers

    private static func distance(_ a: CalendarDate, _ b: CalendarDate) -> Int {
        abs(CycleEngine.daysBetween(a, b))
    }

    /// Why `end` cannot be the last day of the period starting on `start`, or nil if it can.
    private static func endRefusal(
        _ end: CalendarDate,
        start: CalendarDate,
        nextStart: CalendarDate?,
        today: CalendarDate
    ) -> PeriodEndOutcome? {
        if end < start { return .refusedBeforeStart }
        if end > today { return .refusedFuture }
        if CycleEngine.daysBetween(start, end) >= CycleEngine.periodLengthRange.upperBound { return .refusedTooLong }
        if let nextStart, end >= nextStart { return .refusedReachesNextStart }
        return nil
    }

    /// Writes `period` over whatever holds its start date (a tombstone included), stamped and
    /// owed to the server.
    private static func put(
        _ period: PeriodRecord,
        into records: [StoredPeriodRecord],
        now: Date,
        deleted: Bool = false
    ) -> [StoredPeriodRecord] {
        let record = StoredPeriodRecord(period: period, updatedAt: now, pendingSync: true, deleted: deleted)
        return PeriodSync.sorted(records.filter { $0.id != period.startDate } + [record])
    }
}
