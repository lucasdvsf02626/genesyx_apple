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
    /// Optional so days written before the column existed still decode — as `false`, which is the
    /// only honest reading of a day that was never asked the question.
    var sexualActivity: Bool? = nil
    /// Optional for the same reason: a day written before food logging existed decodes as nothing
    /// recorded, which is what it was.
    var foodGroups: [String]? = nil
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
            waterMl: waterMl,
            sexualActivity: sexualActivity,
            foodGroups: Array(foodGroups)
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
            waterMl: waterMl,
            sexualActivity: sexualActivity ?? false,
            foodGroups: Set(foodGroups ?? [])
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
    /// Optional so rows persisted before the migration decode as legacy `urine` (see `domain`).
    var measurementType: String? = nil
    /// Optional for the same reason: rows written before scanning existed carry none, and decode
    /// as `.manual`. An unrecognised value also decodes as `.manual`, so a reading is never hidden
    /// or lost over a source this build does not know.
    var source: String? = nil
    var scanScannerVersion: String? = nil
    var scanConfigurationID: String? = nil
    var scanConfigurationVersion: String? = nil
    var scanConfidence: Double? = nil
}

extension PhReadingDTO {
    var domain: PhReading {
        var scan: PhScanMetadata?
        if source.flatMap(PhReadingSource.init(rawValue:)) == .cameraScan, let scannerVersion = scanScannerVersion,
           let configurationID = scanConfigurationID, let configurationVersion = scanConfigurationVersion,
           let confidence = scanConfidence {
            scan = PhScanMetadata(scannerVersion: scannerVersion, configurationID: configurationID,
                                  configurationVersion: configurationVersion, confidence: confidence)
        }
        // A camera scan only when all four metadata fields are present; otherwise manual.
        return PhReading(id: id, phValue: phValue, recordedAt: recordedAt, notes: notes,
                  // Absent or unrecognised → legacy urine. NEVER default to vaginal.
                  measurementType: measurementType.flatMap(PhMeasurementType.init(rawValue:)) ?? .urine,
                  source: scan == nil ? .manual : .cameraScan, scan: scan)
    }

    var record: PhRecord {
        PhRecord(
            reading: domain,
            updatedAt: updatedAt ?? recordedAt,
            pendingSync: pendingSync ?? true,
            deleted: deleted ?? false
        )
    }
}

/// The only DTO the repository persists through. `measurementType` has to travel with it: without
/// it every reload decodes as legacy `urine` and `PhRepository` hides the whole history.
extension PhRecord {
    var dto: PhReadingDTO {
        PhReadingDTO(
            id: reading.id,
            phValue: reading.phValue,
            recordedAt: reading.recordedAt,
            notes: reading.notes,
            updatedAt: updatedAt,
            pendingSync: pendingSync,
            deleted: deleted,
            measurementType: reading.measurementType.rawValue,
            source: reading.source.rawValue,
            scanScannerVersion: reading.scan?.scannerVersion,
            scanConfigurationID: reading.scan?.configurationID,
            scanConfigurationVersion: reading.scan?.configurationVersion,
            scanConfidence: reading.scan?.confidence
        )
    }
}

/// The persisted form of a `SupplementRecord`.
///
/// Every sync field is optional with a defaulting read, because the shape it replaced had none of
/// them: the list used to be a bare `[CustomSupplement]` array, and a decode that insisted on
/// `updatedAt` would fail on the first launch after upgrading and take her whole list with it.
/// `pendingSync` defaults to **true** for the same reason it does on `PhReadingDTO` — a record with
/// no bookkeeping has never been pushed by definition, and assuming it was synced would strand it
/// on the phone forever.
struct SupplementRecordDTO: Codable {
    var id: String
    var name: String
    var dose: String?
    var timeOfDay: String?
    var updatedAt: Date?
    var pendingSync: Bool?
    var deleted: Bool?
}

extension SupplementRecordDTO {
    init(_ record: SupplementRecord) {
        self.id = record.supplement.id
        self.name = record.supplement.name
        self.dose = record.supplement.dose
        self.timeOfDay = record.supplement.timeOfDay?.rawValue
        self.updatedAt = record.updatedAt
        self.pendingSync = record.pendingSync
        self.deleted = record.deleted
    }

    var record: SupplementRecord {
        SupplementRecord(
            supplement: CustomSupplement(id: id, name: name, dose: dose ?? "",
                                         timeOfDay: SupplementTime.parse(timeOfDay)),
            updatedAt: updatedAt ?? Date(timeIntervalSince1970: 0),
            pendingSync: pendingSync ?? true,
            deleted: deleted ?? false
        )
    }
}

/// The persisted form of an `LhRecord`. Everything but `id`, `recordedAt` and `classification` is
/// optional with a defaulting read, so a list written by an earlier build still decodes. A record
/// with no bookkeeping has never been pushed, so `pendingSync` defaults to true.
struct LhResultDTO: Codable {
    var id: String
    var recordedAt: Date
    var classification: String
    var cycleDay: Int? = nil
    /// "manual" or "cameraScan". Informational only: `scan` is rebuilt from the fields below.
    var source: String? = nil
    var testSignal: Double? = nil
    var controlSignal: Double? = nil
    var testControlRatio: Double? = nil
    var scanConfidence: Double? = nil
    var scannerVersion: String? = nil
    var scanConfigurationID: String? = nil
    var scanConfigurationVersion: String? = nil
    var updatedAt: Date? = nil
    var pendingSync: Bool? = nil
    var deleted: Bool? = nil
}

extension LhResultDTO {
    /// Nil when `classification` is not a value this build knows: a result is never guessed, so
    /// the row is dropped on read.
    var record: LhRecord? {
        guard let classification = LhClassification(rawValue: classification) else { return nil }
        // A scan only when all seven measurement fields are present; otherwise manual.
        var scan: LhScanMeasurement?
        if let testSignal, let controlSignal, let testControlRatio, let scanConfidence,
           let scannerVersion, let scanConfigurationID, let scanConfigurationVersion {
            scan = LhScanMeasurement(testSignal: testSignal, controlSignal: controlSignal,
                                     testControlRatio: testControlRatio, confidence: scanConfidence,
                                     scannerVersion: scannerVersion, configurationID: scanConfigurationID,
                                     configurationVersion: scanConfigurationVersion)
        }
        return LhRecord(
            result: LhResult(id: id, recordedAt: recordedAt, cycleDay: cycleDay,
                             classification: classification, scan: scan),
            updatedAt: updatedAt ?? recordedAt,
            pendingSync: pendingSync ?? true,
            deleted: deleted ?? false
        )
    }
}

/// The only DTO `LhRepository` persists through.
extension LhRecord {
    var dto: LhResultDTO {
        LhResultDTO(
            id: result.id,
            recordedAt: result.recordedAt,
            classification: result.classification.rawValue,
            cycleDay: result.cycleDay,
            source: result.source.rawValue,
            testSignal: result.scan?.testSignal,
            controlSignal: result.scan?.controlSignal,
            testControlRatio: result.scan?.testControlRatio,
            scanConfidence: result.scan?.confidence,
            scannerVersion: result.scan?.scannerVersion,
            scanConfigurationID: result.scan?.configurationID,
            scanConfigurationVersion: result.scan?.configurationVersion,
            updatedAt: updatedAt,
            pendingSync: pendingSync,
            deleted: deleted
        )
    }
}

/// The persisted form of an `HcgResult`. Only `id`, `recordedAt` and `classification` are
/// required. On-device only, so there is no sync bookkeeping, and nothing measured is kept: no
/// signal, no confidence, no cycle day.
struct HcgResultDTO: Codable {
    var id: String
    var recordedAt: Date
    var classification: String
    var scannerVersion: String? = nil
    var scanConfigurationID: String? = nil
    var scanConfigurationVersion: String? = nil
}

extension HcgResultDTO {
    /// Nil when `classification` is not a value this build knows: a result is never guessed, so
    /// the entry is dropped on read.
    var result: HcgResult? {
        guard let classification = HcgClassification(rawValue: classification) else { return nil }
        // A scan only when all three version fields are present; otherwise manual.
        var scan: HcgScanProvenance?
        if let scannerVersion, let scanConfigurationID, let scanConfigurationVersion {
            scan = HcgScanProvenance(scannerVersion: scannerVersion, configurationID: scanConfigurationID,
                                     configurationVersion: scanConfigurationVersion)
        }
        return HcgResult(id: id, recordedAt: recordedAt, classification: classification, scan: scan)
    }
}

/// The only DTO `HcgRepository` persists through.
extension HcgResult {
    var dto: HcgResultDTO {
        HcgResultDTO(
            id: id,
            recordedAt: recordedAt,
            classification: classification.rawValue,
            scannerVersion: scan?.scannerVersion,
            scanConfigurationID: scan?.configurationID,
            scanConfigurationVersion: scan?.configurationVersion
        )
    }
}

/// The persisted form of a `StoredPeriodRecord`. The dates are stored as `CalendarDate` encodes
/// itself, the same way `CycleSettings.lastPeriodDate` is kept. Every field is optional with a
/// defaulting read, and each is decoded on its own, so one unreadable value costs that value and
/// never the list. A record with no bookkeeping has never been pushed, so `pendingSync` defaults
/// to true.
struct PeriodRecordDTO: Codable {
    var startDate: CalendarDate? = nil
    var endDate: CalendarDate? = nil
    var source: String? = nil
    var updatedAt: Date? = nil
    var pendingSync: Bool? = nil
    var deleted: Bool? = nil
}

extension PeriodRecordDTO {
    init(from decoder: Decoder) throws {
        let values = try? decoder.container(keyedBy: CodingKeys.self)
        startDate = try? values?.decode(CalendarDate.self, forKey: .startDate)
        endDate = try? values?.decode(CalendarDate.self, forKey: .endDate)
        source = try? values?.decode(String.self, forKey: .source)
        updatedAt = try? values?.decode(Date.self, forKey: .updatedAt)
        pendingSync = try? values?.decode(Bool.self, forKey: .pendingSync)
        deleted = try? values?.decode(Bool.self, forKey: .deleted)
    }

    /// Nil when the start date is missing or unreadable: the start is the record's identity, so
    /// the entry is dropped on read. An unknown source reads as `recorded`, so a period is never
    /// lost over a source this build does not know.
    var record: StoredPeriodRecord? {
        guard let startDate else { return nil }
        return StoredPeriodRecord(
            period: PeriodRecord(startDate: startDate, endDate: endDate,
                                 source: source.flatMap(PeriodSource.init(rawValue:)) ?? .recorded),
            updatedAt: updatedAt ?? Date(timeIntervalSince1970: 0),
            pendingSync: pendingSync ?? true,
            deleted: deleted ?? false
        )
    }
}

/// The only DTO `PeriodRepository` persists through.
extension StoredPeriodRecord {
    var dto: PeriodRecordDTO {
        PeriodRecordDTO(
            startDate: period.startDate,
            endDate: period.endDate,
            source: period.source.rawValue,
            updatedAt: updatedAt,
            pendingSync: pendingSync,
            deleted: deleted
        )
    }
}
