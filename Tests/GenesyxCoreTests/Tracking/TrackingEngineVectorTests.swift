// TrackingEngineVectorTests.swift
// Runs the shared cross-platform contract (`tracking_test_vectors.json`) against TrackingEngine.
// The JSON is mirrored byte-for-byte in the Android repo — if a case fails here, the platforms
// have diverged and one of them is wrong. Keep the file, not the assertions, as the source of truth.

import XCTest
@testable import GenesyxCore

final class TrackingEngineVectorTests: XCTestCase {

    // MARK: JSON shapes

    private struct VectorFile: Decodable { let cases: [VectorCase] }

    private struct VectorCase: Decodable {
        let name: String
        let today: String
        let goalMl: Int?
        let weeklyMinDays: Int?
        let days: [VectorDay]
        let expect: Expect
    }

    private struct VectorDay: Decodable {
        let date: String
        let waterMl: Int
        let meaningful: Bool
        let ph: Bool
    }

    private struct Expect: Decodable {
        let dailyLogStreak: Int
        let hydrationLogStreak: Int
        let daysOnGoal: Int
        let weeklyStreak: Int
        let bestDailyStreak: Int
    }

    /// Minimal `TrackingLoggable` the vectors drive the engine with.
    private struct VectorLog: TrackingLoggable {
        let waterMl: Int
        let isMeaningfulLog: Bool
    }

    // MARK: Test

    func testSharedTrackingVectors() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "tracking_test_vectors", withExtension: "json"),
            "tracking_test_vectors.json missing from the test bundle")
        let file = try JSONDecoder().decode(VectorFile.self, from: Data(contentsOf: url))
        XCTAssertFalse(file.cases.isEmpty, "vector file has no cases")

        for c in file.cases {
            var logs: [CalendarDate: VectorLog] = [:]
            var phByDate: Set<CalendarDate> = []
            for day in c.days {
                let date = try Self.parse(day.date)
                logs[date] = VectorLog(waterMl: day.waterMl, isMeaningfulLog: day.meaningful)
                if day.ph { phByDate.insert(date) }
            }

            let metrics = TrackingEngine.compute(
                logsByDate: logs,
                phByDate: phByDate,
                today: try Self.parse(c.today),
                goalMl: c.goalMl ?? TrackingEngine.defaultWaterGoalMl,
                weeklyMinDays: c.weeklyMinDays ?? TrackingEngine.defaultWeeklyMinDays)

            XCTAssertEqual(metrics.dailyLogStreak, c.expect.dailyLogStreak, "[\(c.name)] dailyLogStreak")
            XCTAssertEqual(metrics.hydrationLogStreak, c.expect.hydrationLogStreak, "[\(c.name)] hydrationLogStreak")
            XCTAssertEqual(metrics.daysOnGoal, c.expect.daysOnGoal, "[\(c.name)] daysOnGoal")
            XCTAssertEqual(metrics.weeklyStreak, c.expect.weeklyStreak, "[\(c.name)] weeklyStreak")
            XCTAssertEqual(metrics.bestDailyStreak, c.expect.bestDailyStreak, "[\(c.name)] bestDailyStreak")
        }
    }

    private static func parse(_ iso: String) throws -> CalendarDate {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            throw NSError(domain: "TrackingVectors", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "bad date '\(iso)'"])
        }
        return CalendarDate(parts[0], parts[1], parts[2])
    }
}
