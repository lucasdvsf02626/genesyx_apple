import Foundation

// The one producer of pattern statements. My Fertility Picture shows them and the 90-day review
// receives them; nobody else writes one.
//
// A statement is a count or a length and nothing more. No reading, result, mood, symptom or phase
// is read for what it was, and the intimacy field is not read at all. Each level speaks only once
// its own minimum of recorded data exists; below that it says nothing.

public enum FertilityPicturePatterns {

    public static let minimumRecordedDaysInWeek = 3
    public static let minimumRecordedDaysInCycle = 10
    public static let minimumLhResultsInCycle = 2
    public static let minimumPhReadingsInCycle = 4

    /// Lowest level first. Empty when nothing is supported.
    public static func statements(_ input: FertilityPictureInput) -> [ProgrammeEvidenceStatement] {
        guard input.consentActive else { return [] }
        let today = input.today
        let readings = input.vaginalReadings
        // A day counts as recorded on the app's existing rule: a log with anything in it, or a pH
        // reading. One call, then counted inside each window.
        let recordedDays = TrackingEngine.meaningfulDays(
            logsByDate: input.logsByDate,
            phByDate: Set(readings.map { input.localDate($0.recordedAt) }))

        var statements: [ProgrammeEvidenceStatement] = []
        func say(_ level: ProgrammeEvidenceLevel, _ text: String) {
            statements.append(ProgrammeEvidenceStatement(level: level, text: text))
        }

        // Level 1: the length of her last closed cycle, whatever it was, and only when she recorded
        // it at both ends. A cycle closed by a start dated after today is the one she is still in,
        // so it is not the last. When the last one rests on the seeded record nothing is said: the
        // recorded cycle before it is not her last.
        if let last = input.cycles.last(where: { $0.end.map { $0 < today } == true }), last.isRecorded,
           let length = last.length {
            say(.observation, FertilityPictureCopy.lastCycleLength(length))
        }

        // Level 2: recorded days in the seven days ending today.
        let weekStart = today.minusDays(ProgrammeCalendar.daysPerWeek - 1)
        let daysThisWeek = recordedDays.filter { (weekStart...today).contains($0) }.count
        if daysThisWeek >= minimumRecordedDaysInWeek {
            say(.withinWeekTrend, FertilityPictureCopy.recordedDaysThisWeek(daysThisWeek))
        }

        // Level 3: counts inside the cycle she is in, and only when she recorded its start. A
        // cycle opened by the seeded record is not one she recorded.
        if let cycle = CycleHistory.cycle(containing: today, in: input.cycles), cycle.source == .recorded,
           let cycleDay = CycleHistory.cycleDay(on: today, in: input.cycles) {
            /// How many of these dated records fall in that cycle, up to today.
            func countInCycle<Record>(_ records: [Record], date: (Record) -> CalendarDate) -> Int {
                (CycleHistory.group(records, by: input.cycles, date: date)[cycle.start] ?? [])
                    .filter { date($0) <= today }.count
            }

            let days = countInCycle(Array(recordedDays)) { $0 }
            if days >= minimumRecordedDaysInCycle {
                say(.withinCyclePattern, FertilityPictureCopy.recordedDaysInCycle(days, of: cycleDay))
            }
            let lhResults = countInCycle(input.readableLhResults) { input.localDate($0.recordedAt) }
            if input.scanFeaturesAvailable, lhResults >= minimumLhResultsInCycle {
                say(.withinCyclePattern, FertilityPictureCopy.lhResultsInCycle(lhResults))
            }
            let phReadings = countInCycle(readings) { input.localDate($0.recordedAt) }
            if input.phLoggingAvailable, phReadings >= minimumPhReadingsInCycle {
                say(.withinCyclePattern, FertilityPictureCopy.phReadingsInCycle(phReadings))
            }
        }

        // Level 4: only once enough cycles have been recorded at both ends, and over those alone.
        // The lengths are stated and nothing is said about them. When she has also recorded a
        // cycle outside the lengths that are counted, the sentence names the ones it is about, so
        // it never speaks for a cycle it left out.
        if CycleHistory.canMakeCrossCycleStatement(input.cycles) {
            let lengths = CycleHistory.countableCycles(input.cycles).compactMap(\.length)
            let allRecorded = input.cycles.filter { $0.isRecorded && $0.length != nil }.count
            let counted = lengths.count < allRecorded ? CycleEngine.cycleLengthRange : nil
            if let shortest = lengths.min(), let longest = lengths.max() {
                say(.crossCyclePattern, shortest == longest
                    ? FertilityPictureCopy.cycleLengthsEqual(cycles: lengths.count, length: shortest, ofLength: counted)
                    : FertilityPictureCopy.cycleLengthRange(
                        cycles: lengths.count, shortest: shortest, longest: longest, ofLength: counted))
            }
        }
        return statements
    }

    /// True until something can be said across cycles.
    public static func isStillLearning(_ input: FertilityPictureInput) -> Bool {
        !CycleHistory.canMakeCrossCycleStatement(input.cycles)
    }
}
