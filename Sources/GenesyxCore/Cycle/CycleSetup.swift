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

    /// Whether the date picker belongs on screen.
    ///
    /// Asking for the picker and choosing a date are two different events, and this is the rule that
    /// keeps them apart. They used to be one: the editor had no way to show a picker without handing
    /// it a date to bind to, so the empty-state button assigned "today" — the exact fabrication the
    /// note at the top of this file forbids, and it enabled Save on the way past.
    public static func showsDatePicker(lastPeriod: CalendarDate?, isPicking: Bool) -> Bool {
        lastPeriod != nil || isPicking
    }
}
