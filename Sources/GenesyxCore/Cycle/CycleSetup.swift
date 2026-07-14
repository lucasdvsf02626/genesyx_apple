// CycleSetup.swift
// Pure rules for the "Your cycle" editor so the empty-state behaviour is testable without SwiftUI.
//
// The bug this guards against: a brand-new user (no saved settings) must NOT have a last-period
// date fabricated for them (e.g. defaulting to "today"). The field starts empty and Save stays
// disabled until she actively picks a date. Editing existing settings prefills the saved value.

import Foundation

public enum CycleSetup {

    /// The date the editor should open on.
    /// `nil` for a new user (no settings yet) — the UI must not invent "today".
    /// For an existing user, the previously saved last-period date.
    public static func initialLastPeriod(from current: CycleSettings?) -> CalendarDate? {
        current?.lastPeriodDate
    }

    /// Save is only permitted once a real last-period date has been chosen.
    public static func canSave(lastPeriod: CalendarDate?) -> Bool {
        lastPeriod != nil
    }
}
