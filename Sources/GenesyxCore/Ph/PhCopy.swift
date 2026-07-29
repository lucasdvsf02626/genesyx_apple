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

    // ── pH "product spine" sections (shown on the full pH detail view; all cited) ──

    /// a. Why pH matters (general wellness framing; rendered with a Sources footer).
    public static let spineWhyTitle = "Why pH matters"
    public static let spineWhyBody = "Your vaginal pH is a simple, everyday signal of intimate wellbeing. It shifts naturally across your cycle, so your own pattern over time tells you more than any single reading."

    /// b. What this result means — the interpretation reuses `healthy` / `elevated` per band.
    public static let spineMeaningTitle = "What this result means"

    /// c. What to do next — per band. Healthy uses this line; elevated reuses `elevatedSignpost`.
    public static let spineNextTitle = "What to do next"
    public static let spineNextHealthy = "Keep logging as you go — a steady record is what makes your trend meaningful."

    /// d. Genesyx supplements connection (navigational; no causal pH claim).
    public static let spineSupplementsTitle = "Genesyx supplements"
    public static let spineSupplementsBody = "A consistent daily routine supports your overall wellbeing. Explore your Genesyx supplement plan whenever you're ready."
}
