// DayMarkers.swift
// What a single calendar cell should mark beyond its cycle phase.
// Pure and synchronous, with NO UI/SwiftUI imports.
//
// The month grid already spends its backgrounds on the four cycle phases, which are *predicted*
// and cover every day of the month. Markers are the opposite: sparse, and a record of what she
// actually did. Dots, not more tint — a fifth and sixth background would stop the phases reading
// at a glance, which is the calendar's whole job.

import Foundation

/// One thing a day is marked for, beyond its cycle phase.
///
/// `CaseIterable` in render order, so the dot row is stable from day to day: a marker never moves
/// position because a neighbouring one is absent, which is what makes a column scannable down a
/// month.
public enum DayMarker: String, CaseIterable, Sendable {
    /// She took a pH reading. That a test happened, not what it said — the value belongs on the pH
    /// tracker, where it arrives with its range and its disclaimer.
    case ph
    /// She recorded how the day felt: a symptom, or a note. Grouped because they answer the same
    /// question, and a day of free-text with no symptom chips is still a day she described.
    case symptoms
    /// She recorded sexual activity. On a conception-prep calendar this is the marker the fertile
    /// window exists to be read against, which is exactly why it is here.
    case intimacy
}

public enum DayMarkers {

    /// The markers for one day. Order follows `DayMarker.allCases`.
    ///
    /// Takes the pH flag separately rather than reading it off the log: pH readings are their own
    /// store, timestamped rather than keyed by day, and the caller is what knows how to collapse
    /// them onto a date.
    public static func markers(log: DailyLog, hasPhReading: Bool) -> [DayMarker] {
        DayMarker.allCases.filter { marker in
            switch marker {
            case .ph: return hasPhReading
            case .symptoms: return !log.symptoms.isEmpty || !(log.notes ?? "").isEmpty
            case .intimacy: return log.sexualActivity
            }
        }
    }
}
