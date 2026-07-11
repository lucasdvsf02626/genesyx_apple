import Foundation
import GenesyxCore

// Codable persistence DTOs + mappers (mirrors the Android `data/local/Dtos.kt`). Keeps the
// `GenesyxCore` domain models free of storage concerns. Enums persist by their raw value.

struct DailyLogDTO: Codable {
    var mood: String?
    var energy: String?
    var symptoms: [String] = []
    var sleepMinutes: Int?
    var supplements: [String] = []
    var notes: String?
    var waterMl: Int = 0
}

extension DailyLog {
    var dto: DailyLogDTO {
        DailyLogDTO(
            mood: mood?.rawValue,
            energy: energy?.rawValue,
            symptoms: Array(symptoms),
            sleepMinutes: sleepMinutes,
            supplements: Array(supplements),
            notes: notes,
            waterMl: waterMl
        )
    }
}

extension DailyLogDTO {
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
}

/// The sync fields are optional so rows written by v1.0 still decode. A legacy row has never been
/// pushed anywhere, so it decodes as pending — which is what carries an existing on-device history
/// up to the cloud on the next sign-in.
struct PhReadingDTO: Codable {
    var id: String
    var phValue: Double
    var recordedAt: Date
    var notes: String?
    var updatedAt: Date? = nil
    var pendingSync: Bool? = nil
    var deleted: Bool? = nil
}

extension PhReading {
    var dto: PhReadingDTO { PhReadingDTO(id: id, phValue: phValue, recordedAt: recordedAt, notes: notes) }
}

extension PhReadingDTO {
    var domain: PhReading { PhReading(id: id, phValue: phValue, recordedAt: recordedAt, notes: notes) }

    var record: PhRecord {
        PhRecord(
            reading: domain,
            updatedAt: updatedAt ?? recordedAt,
            pendingSync: pendingSync ?? true,
            deleted: deleted ?? false
        )
    }
}

extension PhRecord {
    var dto: PhReadingDTO {
        PhReadingDTO(
            id: reading.id,
            phValue: reading.phValue,
            recordedAt: reading.recordedAt,
            notes: reading.notes,
            updatedAt: updatedAt,
            pendingSync: pendingSync,
            deleted: deleted
        )
    }
}
