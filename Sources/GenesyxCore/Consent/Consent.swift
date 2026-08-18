import Foundation

/// UK GDPR Article 9 explicit consent for special-category (health) data.
///
/// Mirrors the Supabase `consent_events` table (`20260818_consent_events.sql`), which is append-only:
/// a withdrawal is a new row, never an edit to the grant. The reasoning lives in that migration.

public enum ConsentAction: String, Codable, Sendable, CaseIterable {
    case granted, withdrawn
}

/// One consent event. `version` is the copy version she was shown, not the app version, because the
/// question in an audit is what she was told rather than which build told her.
public struct ConsentEvent: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let version: String
    public let action: ConsentAction
    public let occurredAt: Date

    public init(
        id: String = UUID().uuidString,
        version: String,
        action: ConsentAction,
        occurredAt: Date
    ) {
        self.id = id
        self.version = version
        self.action = action
        self.occurredAt = occurredAt
    }
}

public enum ConsentLogic {
    /// The event that decides current state, or nil if she has never been asked.
    ///
    /// Ties break on `granted` losing to `withdrawn`. Two events can share a timestamp when a grant
    /// and a withdrawal sync from different devices in the same second, and in that case the safe
    /// reading is the one that stops processing. Consent is the permission to hold her data; a
    /// coin-flip must not resolve in favour of keeping it.
    public static func latest(_ events: [ConsentEvent]) -> ConsentEvent? {
        events.max { a, b in
            if a.occurredAt != b.occurredAt { return a.occurredAt < b.occurredAt }
            if a.action != b.action { return a.action == .withdrawn ? false : true }
            return a.id < b.id
        }
    }

    /// True only if her most recent event is a grant AND it names the version currently in force.
    ///
    /// The version check is the whole point of versioning. If the wording changes materially, a
    /// grant against the old wording is not consent to the new one, so this returns false and the
    /// app asks again. Failing closed on an unrecognised version is deliberate: an unknown version
    /// is either a downgrade or corrupt local state, and both should re-ask rather than assume.
    public static func isActive(_ events: [ConsentEvent], version: String = ConsentPolicy.currentVersion) -> Bool {
        guard let latest = latest(events) else { return false }
        return latest.action == .granted && latest.version == version
    }

    /// Whether she should be shown the consent question now. Distinct from `!isActive`, and the
    /// difference is the entire design of the prompt.
    ///
    /// * **Never asked → ask.** This is the case that matters on upgrade: everyone already using
    ///   Genesyx has an empty trail, because the app never asked. They are not grandfathered in —
    ///   there is no record of consent, so under Article 7(1) there is no consent.
    /// * **Granted, but against superseded wording → ask again.** The point of versioning.
    /// * **Granted on the current wording → don't.**
    /// * **Withdrawn → don't.** She has answered. `isActive` is false and nothing is collected, but
    ///   re-posing the question every launch is how a refusal gets worn down, and Article 7(4) is
    ///   about consent being freely given. Profile is where she changes her mind, on her own time.
    public static func needsAsking(_ events: [ConsentEvent], version: String = ConsentPolicy.currentVersion) -> Bool {
        guard let latest = latest(events) else { return true }
        return latest.action == .granted && latest.version != version
    }
}

/// The consent copy itself, and the version that identifies it.
///
/// ⚠️ LEGAL REVIEW REQUIRED BEFORE RELEASE. This wording is written to satisfy Article 9(2)(a) and
/// the Article 7 conditions (specific, informed, unambiguous, as easy to withdraw as to give), but
/// it has not been reviewed by a solicitor. It is engineering's best effort at the mechanism, not
/// signed-off legal copy.
///
/// **Bump `currentVersion` whenever any string below changes materially.** `ConsentLogic.isActive`
/// compares against it exactly, so a changed sentence with an unchanged version silently keeps
/// relying on consent nobody gave for it. That is the failure this design exists to prevent.
public enum ConsentPolicy {
    /// Date-stamped rather than sequential so an audit years from now can place it without the repo.
    public static let currentVersion = "2026-08-18.v2"

    public static let title = "Your health data, and your permission"

    /// Names the controller, the data, and the purpose. Article 9 consent has to be explicit and
    /// informed, which means saying what is collected in plain terms rather than pointing at a
    /// policy and hoping.
    public static let body = "Genesyx records information about your cycle, your vaginal pH readings, your daily symptoms and mood, and — if you choose to log it — your sexual activity. UK data protection law treats all of this as especially sensitive, so we need your clear permission before collecting any of it."

    public static let purpose = "We use it to show you your own patterns and your fertile window, and to tailor the guidance you see. We do not sell it, and we do not use it to advertise to you."

    /// Article 7(3): withdrawal must be as easy as giving it, and she must be told so beforehand.
    public static let withdrawal = "You can withdraw your permission at any time in Profile. If you do, Genesyx stops collecting new health data straight away, and you can delete everything you have recorded whenever you choose."

    /// The affirmative action. Article 9 needs an explicit statement, not an implied one, so this is
    /// the label on a control she has to actively operate rather than something pre-ticked.
    public static let agreeLabel = "I agree to Genesyx collecting the health and intimate data described above"

    public static let continueLabel = "Continue"

    /// Shown when she declines. Deliberately not a dead end and deliberately not a nag: without this
    /// permission there is no lawful basis to record anything, so the honest thing is to say what is
    /// unavailable rather than to keep asking.
    public static let declinedTitle = "No problem"
    public static let declinedBody = "Without this permission we cannot record your cycle, vaginal pH, sexual activity, or daily logs. You can still read everything in the Learn library. If you change your mind, you can turn this on in Profile at any time."

    // ── Withdrawal, shown in Profile ──

    public static let withdrawTitle = "Withdraw consent"
    public static let withdrawBody = "Genesyx will stop collecting new health data straight away. What you have already recorded stays on your device and in your account until you delete it, which you can do from this screen at any time."
    public static let withdrawConfirm = "Withdraw consent"
    public static let withdrawCancel = "Keep it on"

    /// Shown on tracking surfaces once consent is withdrawn, in place of the entry controls.
    public static let blockedBody = "You have withdrawn permission for Genesyx to collect health data, so logging is turned off. You can turn it back on in Profile."

    /// Every user-facing string here, so the banned-phrase guards scan all of them. Same reasoning as
    /// `PhCopy.allSurfaces`: a guard holding its own copy of the list misses whatever nobody
    /// remembered to add to it.
    public static let allSurfaces: [String] = [
        title, body, purpose, withdrawal, agreeLabel, continueLabel,
        declinedTitle, declinedBody,
        withdrawTitle, withdrawBody, withdrawConfirm, withdrawCancel, blockedBody,
    ]
}
