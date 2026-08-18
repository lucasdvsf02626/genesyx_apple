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
    /// Optional on decode so a row missing the column tolerates as legacy `urine` (see `domain`).
    /// Always sent on insert/upsert as the reading's real type ('vaginal' for new readings).
    var measurementType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case phValue = "ph_value"
        case recordedAt = "recorded_at"
        case notes
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case measurementType = "measurement_type"
    }

    var domain: PhRecord {
        PhRecord(
            reading: PhReading(
                id: id, phValue: phValue, recordedAt: parseISO(recordedAt), notes: notes,
                // Absent or unrecognised → legacy urine. NEVER default to vaginal.
                measurementType: measurementType.flatMap(PhMeasurementType.init(rawValue:)) ?? .urine),
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
        self.measurementType = record.reading.measurementType.rawValue
    }
}

/// Row-level security on `daily_logs` is what actually keeps this private — a partner holds a
/// `partner_id` link, not a read grant, and nothing in the app ever selects another user's logs.
/// That matters more here than on the other tables because of `sexual_activity`.
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
    /// Optional on decode so a row from before the column existed tolerates as `false`.
    var sexualActivity: Bool?
    /// Optional on the same grounds. `20260812_daily_logs_food_groups.sql` was applied 13 Aug, so
    /// this now tolerates old *rows*, not an absent column. Keep it optional anyway: these meals
    /// count toward the streak on both clients, and a decode failure here would zero it.
    var foodGroups: [String]?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case date
        case mood, energy, symptoms, notes, supplements
        case sleepMinutes = "sleep_minutes"
        case waterMl = "water_ml"
        case sexualActivity = "sexual_activity"
        case foodGroups = "food_groups"
    }

    var domain: DailyLog {
        DailyLog(
            mood: mood.flatMap(Mood.init(rawValue:)),
            energy: energy.flatMap(EnergyLevel.init(rawValue:)),
            symptoms: Set(symptoms),
            sleepMinutes: sleepMinutes,
            supplements: Set(supplements),
            notes: notes,
            waterMl: waterMl,
            sexualActivity: sexualActivity ?? false,
            foodGroups: Set(foodGroups ?? [])
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
        self.sexualActivity = log.sexualActivity
        self.foodGroups = Array(log.foodGroups)
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

/// Read-only. `authenticated` has no UPDATE privilege on `profiles.partner_id` — only the
/// `accept_partner_invite` / `unlink_partner` Edge Functions write it, with the service role — so
/// upserting this struct would fail with SQLSTATE 42501 the moment the encoder emitted that key.
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

    /// Quiz answers live in their own table, so they arrive separately and are merged in here.
    func domain(quizAnswers: [String: String]) -> ProfilePrefs {
        ProfilePrefs(
            focusMode: FocusMode(rawValue: focusMode) ?? .prep,
            // An unrecognised string falls back to the product default, not `.system`. `.system`
            // stays a valid stored choice, so this branch is only reached by a value no build
            // understands — and landing that on `.system` put her in the one state the theme
            // migration in `PreferencesRepository` exists to move people off.
            themeMode: ThemeMode(rawValue: theme) ?? .light,
            pushEnabled: pushEnabled,
            quizAnswers: quizAnswers
        )
    }

    init(id: String, prefs: ProfilePrefs) {
        self.id = id
        self.focusMode = prefs.focusMode.rawValue
        self.theme = prefs.themeMode.rawValue
        self.pushEnabled = prefs.pushEnabled
    }
}

/// Her onboarding quiz answers, in a table only she can read.
///
/// `profiles` is partner-readable (`profiles_select` grants a linked partner the whole row), and
/// Postgres RLS filters rows, never columns — so the only way to keep an answer set the quiz calls
/// "just for you" out of a partner's reach is to keep it out of that row.
struct QuizAnswersRow: Codable {
    var userId: String
    var answers: [String: String]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case answers
    }

    /// `nil` when there is nothing to write. A device with no answers has *nothing to say* about
    /// the quiz, which is not the same as saying she answered nothing — onboarding runs once, so
    /// most installs are in that state. Written as empty, one theme toggle on a reinstalled phone
    /// would erase what she answered before.
    init?(userId: String, answers: [String: String]) {
        guard !answers.isEmpty else { return nil }
        self.userId = userId
        self.answers = answers
    }
}

/// A row of `consent_events` — one Article 9 consent grant or withdrawal.
///
/// The only DTO here with no update path, because the table has no UPDATE policy. `occurred_at` is
/// sent by the client rather than defaulted server-side: consent is captured during onboarding,
/// which runs before sign-up, so the row is inserted minutes to hours after the moment it records
/// and `now()` would time-stamp the sync instead of the consent. The whole point of the trail is
/// when she was asked.
///
/// An unrecognised `action` decodes to `.withdrawn`. That is deliberate rather than lenient: this
/// column is CHECK-constrained to two values, so anything else is corruption, and the safe reading
/// of corrupt consent state is the one that stops processing.
struct ConsentEventRow: Codable {
    var id: String
    var userId: String
    var version: String
    var action: String
    var occurredAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case version
        case action
        case occurredAt = "occurred_at"
    }

    var domain: ConsentEvent {
        ConsentEvent(id: id, version: version,
                     action: ConsentAction(rawValue: action) ?? .withdrawn,
                     occurredAt: parseISO(occurredAt))
    }

    init(userId: String, event: ConsentEvent) {
        self.id = event.id
        self.userId = userId
        self.version = event.version
        self.action = event.action.rawValue
        self.occurredAt = isoFormatter.string(from: event.occurredAt)
    }
}

/// A row of `user_supplements` — the table Android has been reading and writing since 13 Aug 2026,
/// which is why the column names below are a contract rather than a choice.
///
/// Two of the columns are nullable on purpose and the mapping has to respect that:
/// `updated_at` is only stamped on update, so a row inserted and never touched again has none —
/// falling back to `created_at` is what stops a freshly-created remote row looking infinitely old
/// and losing every merge. `time_of_day` is null for "she didn't say", and is constrained to the
/// four `SupplementTime` values, so anything unrecognised is read as unset rather than guessed at.
///
/// `product_id` is Android's link to the Genesyx catalogue (`genesyx_products`, `ON DELETE SET
/// NULL`). iOS has no catalogue picker, so it is never sent — and that omission is what preserves
/// it. Swift leaves nil optionals out of the encoded body rather than writing null, so an upsert
/// from this device (in practice only a tombstone) does not touch the column. Encoded as an
/// explicit null instead, deleting a supplement here would silently unlink one she added on her
/// other phone. Same reasoning for `created_at`, which is a server default.
struct UserSupplementRow: Codable {
    var id: String
    var userId: String
    var name: String
    var dose: String?
    var timeOfDay: String?
    var productId: String?
    var createdAt: String?
    var updatedAt: String?
    var deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case dose
        case timeOfDay = "time_of_day"
        case productId = "product_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    var domain: SupplementRecord {
        SupplementRecord(
            supplement: CustomSupplement(id: id, name: name, dose: dose ?? "",
                                         timeOfDay: SupplementTime.parse(timeOfDay)),
            updatedAt: parseISO(updatedAt ?? createdAt ?? ""),
            pendingSync: false,
            deleted: deletedAt != nil
        )
    }

    init(userId: String, record: SupplementRecord, productId: String? = nil) {
        self.id = record.supplement.id
        self.userId = userId
        // Trimmed to satisfy `char_length(btrim(name)) between 1 and 60`. The UI already bounds it;
        // this is the last gate before a row the server would reject sits in the queue retrying.
        self.name = String(record.supplement.name.trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(CustomSupplement.nameMaxLength))
        self.dose = record.supplement.dose.isEmpty ? nil : record.supplement.dose
        self.timeOfDay = record.supplement.timeOfDay?.rawValue
        self.productId = productId
        self.createdAt = nil          // server default; never overwritten from the client
        self.updatedAt = isoFormatter.string(from: record.updatedAt)
        // The deletion's timestamp is the edit that made it, so a later edit on another device
        // still wins the merge.
        self.deletedAt = record.deleted ? isoFormatter.string(from: record.updatedAt) : nil
    }
}
