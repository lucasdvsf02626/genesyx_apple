import Foundation

/// User-facing pH copy. Final strings are finalised in the copy step (3/5); the one-time migration
/// notice is a placeholder for now.
enum PhCopy {
    /// Canonical legacy marker — lowercase, used verbatim on every surface (no casing drift).
    static let legacyMarker = "urine (legacy)"

    /// PLACEHOLDER — the verbatim vaginal-pH migration notice copy arrives in step 3.
    static let oneTimeNotice = "This tracker now records vaginal pH. (Notice copy is finalised in step 3.)"
}
