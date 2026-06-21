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

struct PhReadingRow: Codable {
    var id: String
    var userId: String
    var phValue: Double
    var recordedAt: String
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case phValue = "ph_value"
        case recordedAt = "recorded_at"
        case notes
    }

    var domain: PhReading { PhReading(id: id, phValue: phValue, recordedAt: parseISO(recordedAt), notes: notes) }

    init(userId: String, reading: PhReading) {
        self.id = reading.id
        self.userId = userId
        self.phValue = reading.phValue
        self.recordedAt = isoFormatter.string(from: reading.recordedAt)
        self.notes = reading.notes
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
