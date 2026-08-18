import Foundation
import GenesyxCore

/// App preferences (theme, push toggle, current focus), persisted on-device and mirrored to her
/// `profiles` row when a `ProfileBackend` is provided. `themeMode` drives the app's color scheme.
/// Mirrors the Android `PreferencesRepository`.
///
/// Same contract as the other repositories: the local write always wins, a failed push stays owed,
/// and a pull never overwrites a preference she changed while the server was unreachable.
@MainActor
final class PreferencesRepository: ObservableObject {

    @Published var themeMode: ThemeMode { didSet { store.setString(themeMode.rawValue, forKey: themeKey); pushPrefs() } }
    @Published var pushEnabled: Bool { didSet { store.setBool(pushEnabled, forKey: pushKey); pushPrefs() } }
    @Published var focusMode: FocusMode { didSet { store.setString(focusMode.rawValue, forKey: focusKey); pushPrefs() } }

    /// Hour (0–23) of the daily evening check-in reminder. Device-local — a reminder time belongs to
    /// the phone in her hand, not her synced profile. Defaults to 19:00.
    @Published var reminderHour: Int { didSet { store.setInt(reminderHour, forKey: reminderHourKey) } }

    /// Notification categories she has switched off. Stored as what she *muted*, not what she kept,
    /// so a category added in a later build arrives on rather than silently off for everyone who
    /// upgraded. Device-local for the same reason as `reminderHour`.
    @Published var mutedNotifications: Set<NotificationCategory> {
        didSet { store.save(mutedNotifications.map(\.rawValue), forKey: mutedNotificationsKey) }
    }

    /// Hour of the day she wants reminding about one supplement, keyed by `SupplementReminder.id`.
    /// Absent means no reminder, which is the default for every supplement — the plan is hers to
    /// follow at her own pace, and four unrequested alarms a day is how an app gets muted entirely.
    ///
    /// Held here rather than on `CustomSupplement` on purpose: that type's shape is frozen until the
    /// shared Android schema is confirmed, and keying by id covers the fixed Genesyx essentials too,
    /// which have no record of their own to hang a field on.
    @Published var supplementReminders: [String: Int] {
        didSet { store.save(supplementReminders, forKey: supplementRemindersKey) }
    }

    /// What she answered in onboarding, keyed by `QuizQuestion.id`. Read-only from outside:
    /// `recordQuizAnswers` is the one way in, because it is also what owes the answers to the
    /// server. Empty until she answers, and empty again after sign-out.
    @Published private(set) var quizAnswers: [String: String] {
        didSet { store.save(quizAnswers, forKey: quizAnswersKey) }
    }

    /// Guards `recordQuizAnswers` only. The rest of this repository is device preferences — theme,
    /// push, reminder hour — which are not special-category data and are not what the Article 9
    /// question was about. The quiz is: it asks her where she is in trying to conceive.
    var isCollectionPermitted: HealthDataCollectionGate = { true }

    private let store: LocalStore
    private let backend: ProfileBackend?
    private let themeKey = "theme_mode"
    private let pushKey = "push_enabled"
    private let focusKey = "focus_mode"
    private let reminderHourKey = "reminder_hour"
    private let mutedNotificationsKey = "muted_notifications"
    private let supplementRemindersKey = "supplement_reminders"
    private let quizAnswersKey = "quiz_answers"
    private let pendingKey = "profile_pending"
    private let themeMigratedKey = "theme_default_migrated"

    /// Set while applying a pulled profile, so writing those values doesn't bounce them straight
    /// back up as a fresh push.
    private var isApplyingRemote = false

    private var pendingPush: Bool {
        didSet { store.setBool(pendingPush, forKey: pendingKey) }
    }

    /// Streak milestones already celebrated, by `Milestone.flagKey`. Device-local: a celebration is
    /// a moment, not a record, and re-celebrating on a second device would be noise.
    private(set) var celebratedMilestones: Set<String> {
        didSet { store.save(Array(celebratedMilestones), forKey: celebratedKey) }
    }
    private let celebratedKey = "celebrated_milestones"

    func celebrate(_ flagKeys: [String]) {
        guard !flagKeys.isEmpty else { return }
        celebratedMilestones.formUnion(flagKeys)
    }

    /// Un-flag milestones whose streak has since lapsed, so re-achieving one celebrates again.
    func clearCelebrations(_ flagKeys: Set<String>) {
        guard !flagKeys.isEmpty else { return }
        celebratedMilestones.subtract(flagKeys)
    }

    /// Wipe the notification state derived from the signed-out user's data. Her milestone flags are
    /// as personal as a log — leaving them behind would mean the next user on this device found her
    /// celebrations already spent. Theme and push are device preferences and stay; focus mode is
    /// not one, and leaves via `clearFocusMode()`.
    func clearNotificationState() {
        celebratedMilestones = []
        store.remove(forKey: celebratedKey)
        // Keyed to supplements that are themselves wiped on sign-out. Left behind, the next user on
        // this device would be woken at 8am for someone else's magnesium.
        supplementReminders = [:]
        store.remove(forKey: supplementRemindersKey)
    }

    init(store: LocalStore, backend: ProfileBackend? = nil) {
        self.store = store
        self.backend = backend
        // Defaults to light, not system: the warm palette is the designed look, and following a
        // phone that happens to be in dark mode showed first-time users a scheme nobody signed off.
        // `.system` stays available in Profile for anyone who wants it.
        self.themeMode = store.string(forKey: themeKey).flatMap(ThemeMode.init(rawValue:)) ?? .light
        // Defaults to FALSE. "On" must mean she asked for reminders — defaulting it true made the
        // Profile toggle read as on before iOS had ever been asked for permission, so the
        // pre-prompt never appeared, permission was never requested, and nothing was ever
        // scheduled. The toggle said yes and the app sent nothing.
        self.pushEnabled = store.bool(forKey: pushKey, default: false)
        self.focusMode = store.string(forKey: focusKey).flatMap(FocusMode.init(rawValue:)) ?? .prep
        self.reminderHour = store.int(forKey: reminderHourKey, default: 19)
        self.mutedNotifications = Set((store.load([String].self, forKey: mutedNotificationsKey) ?? [])
            .compactMap(NotificationCategory.init(rawValue:)))
        self.supplementReminders = store.load([String: Int].self, forKey: supplementRemindersKey) ?? [:]
        self.quizAnswers = store.load([String: String].self, forKey: quizAnswersKey) ?? [:]
        self.pendingPush = store.bool(forKey: pendingKey, default: false)
        self.celebratedMilestones = Set(store.load([String].self, forKey: celebratedKey) ?? [])
    }

    /// Record what she answered in onboarding. The quiz runs *before* sign-up, so at the moment she
    /// answers there is no session to write under and no row to write to — hence the local write
    /// and the owed push, which sign-in drains once a user id exists. Without this the answers only
    /// had to survive four screens of navigation to be lost.
    func recordQuizAnswers(_ answers: [String: String]) {
        guard isCollectionPermitted() else { return }
        quizAnswers = answers
        pushPrefs()
    }

    /// An intake questionnaire is as personal as a log, so it leaves with her. Deliberately does
    /// *not* push the wipe: at sign-out there is no session to write under, and the retry would
    /// land on whoever signs in next. Her answers stay on the server, and come back on her next
    /// profile pull.
    func clearQuizAnswers() {
        quizAnswers = [:]
        store.remove(forKey: quizAnswersKey)
    }

    /// Fertility Prep vs Pregnancy is a health answer about her body, not a preference about this
    /// phone, so it leaves with her — it was sitting alongside theme and push, and the next user on
    /// the device opened Profile to find "Pregnancy" already selected. Worse for a new sign-up:
    /// there is no `profiles` row yet, so `refresh()` seeds one from whatever this device still
    /// holds, writing the previous user's pregnancy status permanently into hers.
    ///
    /// Suppresses the push for the reason `clearQuizAnswers` gives, plus one of its own: pushing
    /// `.prep` at sign-out would reset the *departing* user's row and lose the answer she gave.
    /// Her value stays on the server and comes back on her next profile pull.
    func clearFocusMode() {
        isApplyingRemote = true
        focusMode = .prep
        isApplyingRemote = false
        store.remove(forKey: focusKey)
    }

    /// Drop a profile write the server never received. Sign-out only: the flag outlived the session
    /// that owed it, so the next account's first refresh drained *her* theme, focus mode and push
    /// flag up into *their* row, then pulled the clobbered values back down.
    func clearOwedProfileWrite() {
        pendingPush = false
        store.remove(forKey: pendingKey)
    }

    /// Let the light-mode migration run again for the next account on this phone.
    ///
    /// The flag records that *an* account has been migrated, but the thing it corrects — a stored
    /// `.system` nobody chose — lives in the **server row**, per account. Latched, it meant: the
    /// first user signs in and her `.system` is corrected to `.light`; she signs out; a second
    /// legacy account signs in on the same phone, `refresh()` pulls her uncorrected `.system`, and
    /// `migrateLegacySystemTheme` returns at the guard. She lands in dark mode having never seen
    /// the palette.
    func clearThemeMigrationFlag() {
        store.remove(forKey: themeMigratedKey)
    }

    private var prefs: ProfilePrefs {
        ProfilePrefs(focusMode: focusMode, themeMode: themeMode, pushEnabled: pushEnabled,
                     quizAnswers: quizAnswers)
    }

    /// Push what's owed, then pull. A profile the server has never seen is created from the local
    /// prefs — the one-time migration for an existing on-device user.
    func refresh() async {
        guard let backend else { return }
        await drainPending()
        guard !pendingPush else { return }

        // do/catch, not `try?`: a failed call and "no profile row yet" are different answers, and
        // `try?` would flatten them into the same nil.
        let fetched: ProfilePrefs?
        do { fetched = try await backend.fetch() } catch { return }

        // Re-read after the suspension. If she changed a preference while the fetch was in flight,
        // hers is newer than what came back and `apply` would silently overwrite it — and because
        // `apply` sets `isApplyingRemote`, the overwrite would not even be re-queued.
        guard !pendingPush else { return }

        guard let remote = fetched else {       // nothing up there yet: seed it from this device
            pendingPush = true
            await drainPending()
            return
        }
        apply(remote)
        migrateLegacySystemTheme()
    }

    /// One-shot, and the reason the light default looked undone on every account that predates it.
    ///
    /// Before `560591e` the default was `.system`, and a first sync seeds the profile row from
    /// whatever this device holds — so accounts created back then carry `.system` as a stored
    /// preference she never actually expressed. Pulling it down is what puts a returning user on a
    /// dark phone straight back into dark, with the palette nowhere in sight.
    ///
    /// Only `.system` is corrected: a `.dark` she went to Profile and chose is a real preference and
    /// is left alone. After this runs once, a `.system` she picks herself syncs like anything else.
    private func migrateLegacySystemTheme() {
        guard !store.bool(forKey: themeMigratedKey, default: false) else { return }
        store.setBool(true, forKey: themeMigratedKey)
        guard themeMode == .system else { return }
        themeMode = .light   // didSet persists it and owes the push, which corrects the row too
    }

    /// Retry the write the server never received. Called on launch/sign-in and app foreground.
    func drainPending() async {
        guard let backend, pendingPush else { return }
        let snapshot = prefs
        guard (try? await backend.upsert(snapshot)) != nil else { return }
        if prefs == snapshot { pendingPush = false }   // unless she changed one meanwhile
    }

    /// Note the split. Theme and push are settings about this phone and are applied unconditionally.
    /// Focus mode (trying vs pregnant) and the intake answers are health data about her body, so
    /// they sit behind the Article 9 gate exactly as the writes do: after a withdrawal there is no
    /// lawful basis to pull them back down. Whatever this device already holds is left alone —
    /// withdrawal stops processing, it is not erasure.
    ///
    /// This is a field-level gate rather than a gate on `refresh()` because the row carries both
    /// kinds of value; refusing the whole profile would take her theme away to protect her health
    /// data, which is not a trade the gate is for.
    private func apply(_ remote: ProfilePrefs) {
        isApplyingRemote = true
        themeMode = remote.themeMode
        pushEnabled = remote.pushEnabled
        if isCollectionPermitted() {
            focusMode = remote.focusMode
            quizAnswers = remote.quizAnswers
        }
        isApplyingRemote = false
    }

    private func pushPrefs() {
        guard !isApplyingRemote else { return }
        pendingPush = true
        guard backend != nil else { return }
        Task { await drainPending() }
    }
}
