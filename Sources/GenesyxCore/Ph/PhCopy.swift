import Foundation

/// User-facing vaginal-pH copy (British English). Single source of truth so the same strings are
/// used by the pure insight logic and every UI surface (no drift).
public enum PhCopy {
    /// Insight line when recent readings are in the healthy band.
    public static let healthy = "Your recent readings sit within the typical healthy range."

    /// Insight line when recent readings are elevated.
    public static let elevated = "Your recent readings are above the typical healthy range."

    /// Non-alarming signpost shown alongside an elevated insight.
    public static let elevatedSignpost = "If readings stay above the usual range over several days, a GP or pharmacist can talk it through with you."

    /// Shown on the pH detail + log surfaces.
    public static let disclaimer = "This tracker is for your own record and isn't medical advice. If a reading worries you, or a pattern persists, please speak to a GP, nurse, or pharmacist."

    /// Non-diagnostic accuracy caveat, shown where she logs and on the tracker. Timing guidance
    /// only — it names no condition, so it stays within the wellness framing and the banned-phrase
    /// guard. Several everyday things temporarily shift a reading; testing around them gives a
    /// truer picture of her own pattern.
    public static let accuracyCaveat = "For an accurate reading, test away from your period and at least 24 hours after sex. Lubricants, douches, and recent antibiotics can also shift the result."

    /// Cycle-context caveat shown on the pH tracker card and the Insights pH card. It names the
    /// note field on purpose: there is no cycle-day control on the log sheet, so copy that said
    /// "log your cycle day alongside each reading" was pointing at a field that does not exist.
    public static let cycleContextCaveat = "Vaginal pH naturally shifts across your cycle. Add your cycle day to the note when you log a reading — that context is what makes your own pattern readable."

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
