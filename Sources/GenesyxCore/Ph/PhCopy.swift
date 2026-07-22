import Foundation

/// User-facing vaginal-pH copy (British English). Single source of truth so the same strings are
/// used by the pure insight logic and every UI surface (no drift).
public enum PhCopy {
    /// Canonical legacy marker — lowercase, used verbatim on every surface (no casing drift).
    public static let legacyMarker = "urine (legacy)"

    /// Insight line when recent readings are in the healthy band.
    public static let healthy = "Your recent readings sit within the typical healthy range."

    /// Insight line when recent readings are elevated.
    public static let elevated = "Your recent readings are above the typical healthy range."

    /// Non-alarming signpost shown alongside an elevated insight.
    public static let elevatedSignpost = "If readings stay above the usual range over several days, a GP or pharmacist can talk it through with you."

    /// Shown on the pH detail + log surfaces.
    public static let disclaimer = "This tracker is for your own record and isn't medical advice. If a reading worries you, or a pattern persists, please speak to a GP, nurse, or pharmacist."

    /// One-time migration notice, shown on the first visit to the pH section after the update.
    public static let oneTimeNotice = "This tracker now records vaginal pH. Your earlier readings are kept and marked 'urine (legacy)'. New readings are saved as vaginal pH, on a different scale."
}
