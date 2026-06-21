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

struct PhReadingDTO: Codable {
    var id: String
    var phValue: Double
    var recordedAt: Date
    var notes: String?
}

extension PhReading {
    var dto: PhReadingDTO { PhReadingDTO(id: id, phValue: phValue, recordedAt: recordedAt, notes: notes) }
}

extension PhReadingDTO {
    var domain: PhReading { PhReading(id: id, phValue: phValue, recordedAt: recordedAt, notes: notes) }
}
