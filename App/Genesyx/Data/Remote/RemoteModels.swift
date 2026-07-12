import Foundation
import GenesyxCore

// Codable row DTOs for the Supabase tables (see the Android docs/schema.sql). Pure Foundation —
// these always compile; the actual network calls live in SupabaseBackend (guarded). snake_case
// column names map to camelCase via CodingKeys.

private let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private func parseISO(_ s: String) -> Date {
    isoFormatter.date(from: s) ?? ISO8601DateFormatter().date(from: s) ?? Date()
}

struct CycleSettingsRow: Codable {
    var userId: String
    var lastPeriodDate: String   // yyyy-MM-dd
    var cycleLength: Int
    var periodLength: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case lastPeriodDate = "last_period_date"
        case cycleLength = "cycle_length"
        case periodLength = "period_length"
    }

    var domain: CycleSettings? {
        guard let date = CalendarDate(iso: lastPeriodDate) else { return nil }
        return CycleSettings(lastPeriodDate: date, cycleLength: cycleLength, periodLength: periodLength)
    }

    init(userId: String, settings: CycleSettings) {
        self.userId = userId
        self.lastPeriodDate = settings.lastPeriodDate.iso
        self.cycleLength = settings.cycleLength
        self.periodLength = settings.periodLength
    }
}

/// The client sends `updated_at`, but the live table has a `trg_ph_readings_updated_at` trigger
/// that stamps `now()` on update — so the SERVER's clock decides it, and two devices that both
/// pushed resolve last-push-wins rather than last-edit-wins. That is fine: the rule that actually
/// protects her data — an unsynced local edit always beats the server copy — lives in
/// `PhSync.merge` on the device and is unaffected, and an online edit pushes immediately, so
/// edit-time and push-time are the same moment in every case except a same-reading race.
///
/// The tombstone is the table's existing `deleted_at` timestamp — null means alive. The app models
/// it as a plain `deleted` flag (`PhRecord`), and the mapping happens here; there is no separate
/// `deleted` boolean column, and no `pending_sync` column either (that is local bookkeeping the
/// server has no use for).
struct PhReadingRow: Codable {
    var id: String
    var userId: String
    var phValue: Double
    var recordedAt: String
    var notes: String?
    var updatedAt: String
    var deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case phValue = "ph_value"
        case recordedAt = "recorded_at"
        case notes
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    var domain: PhRecord {
        PhRecord(
            reading: PhReading(id: id, phValue: phValue, recordedAt: parseISO(recordedAt), notes: notes),
            updatedAt: parseISO(updatedAt),
            pendingSync: false,
            deleted: deletedAt != nil
        )
    }

    init(userId: String, record: PhRecord) {
        self.id = record.reading.id
        self.userId = userId
        self.phValue = record.reading.phValue
        self.recordedAt = isoFormatter.string(from: record.reading.recordedAt)
        self.notes = record.reading.notes
        self.updatedAt = isoFormatter.string(from: record.updatedAt)
        // The deletion's timestamp is the edit that made it — so a later edit on another device
        // still wins the merge.
        self.deletedAt = record.deleted ? isoFormatter.string(from: record.updatedAt) : nil
    }
}

struct DailyLogRow: Codable {
    var userId: String
    var date: String             // yyyy-MM-dd
    var mood: String?
    var energy: String?
    var symptoms: [String]
    var sleepMinutes: Int?
    var waterMl: Int
    var supplements: [String]
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case date
        case mood, energy, symptoms, notes, supplements
        case sleepMinutes = "sleep_minutes"
        case waterMl = "water_ml"
    }

    var domain: DailyLog {
        DailyLog(
            mood: mood.flatMap(Mood.init(rawValue:)),
            energy: energy.flatMap(EnergyLevel.init(rawValue:)),
            symptoms: Set(symptoms),
            sleepMinutes: sleepMinutes,
            supplements: Set(supplements),
            notes: notes,
            waterMl: waterMl
        )
    }

    init(userId: String, date: CalendarDate, log: DailyLog) {
        self.userId = userId
        self.date = date.iso
        self.mood = log.mood?.rawValue
        self.energy = log.energy?.rawValue
        self.symptoms = Array(log.symptoms)
        self.sleepMinutes = log.sleepMinutes
        self.waterMl = log.waterMl
        self.supplements = Array(log.supplements)
        self.notes = log.notes
    }
}

struct PartnerInviteRow: Codable {
    var id: String
    var inviterId: String
    var inviteeEmail: String
    var code: String
    var status: String

    enum CodingKeys: String, CodingKey {
        case id, code, status
        case inviterId = "inviter_id"
        case inviteeEmail = "invitee_email"
    }

    var domain: PartnerInvite {
        PartnerInvite(id: id, email: inviteeEmail, code: code, status: InviteStatus(rawValue: status) ?? .pending)
    }
}

/// Reply from the `send_partner_invite` edge function. `sent` is false when the mailer isn't
/// configured or the send failed — the invite is still valid, so this is reported, not thrown.
struct EmailInviteResponse: Codable {
    var ok: Bool
    var sent: Bool
    var reason: String?
}

struct ProfileRow: Codable {
    var id: String
    var displayName: String?
    var partnerId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case partnerId = "partner_id"
    }
}

/// Just the preference columns of `profiles` — kept separate from `ProfileRow` so writing prefs
/// can't touch `display_name` or `partner_id`.
///
/// The theme column is the table's existing `theme` (NOT `theme_mode`): it already ships, other
/// clients may read it, and renaming a live column to match a doc would be gratuitous.
struct ProfilePrefsRow: Codable {
    var id: String
    var focusMode: String
    var theme: String
    var pushEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case focusMode = "focus_mode"
        case theme
        case pushEnabled = "push_enabled"
    }

    var domain: ProfilePrefs {
        ProfilePrefs(
            focusMode: FocusMode(rawValue: focusMode) ?? .prep,
            themeMode: ThemeMode(rawValue: theme) ?? .system,
            pushEnabled: pushEnabled
        )
    }

    init(id: String, prefs: ProfilePrefs) {
        self.id = id
        self.focusMode = prefs.focusMode.rawValue
        self.theme = prefs.themeMode.rawValue
        self.pushEnabled = prefs.pushEnabled
    }
}
