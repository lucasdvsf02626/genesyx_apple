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

    private let store: LocalStore
    private let backend: ProfileBackend?
    private let themeKey = "theme_mode"
    private let pushKey = "push_enabled"
    private let focusKey = "focus_mode"
    private let pendingKey = "profile_pending"

    /// Set while applying a pulled profile, so writing those values doesn't bounce them straight
    /// back up as a fresh push.
    private var isApplyingRemote = false

    private var pendingPush: Bool {
        didSet { store.setBool(pendingPush, forKey: pendingKey) }
    }

    init(store: LocalStore, backend: ProfileBackend? = nil) {
        self.store = store
        self.backend = backend
        self.themeMode = store.string(forKey: themeKey).flatMap(ThemeMode.init(rawValue:)) ?? .system
        self.pushEnabled = store.bool(forKey: pushKey, default: true)
        self.focusMode = store.string(forKey: focusKey).flatMap(FocusMode.init(rawValue:)) ?? .prep
        self.pendingPush = store.bool(forKey: pendingKey, default: false)
    }

    private var prefs: ProfilePrefs {
        ProfilePrefs(focusMode: focusMode, themeMode: themeMode, pushEnabled: pushEnabled)
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

        guard let remote = fetched else {       // nothing up there yet: seed it from this device
            pendingPush = true
            await drainPending()
            return
        }
        apply(remote)
    }

    /// Retry the write the server never received. Called on launch/sign-in and app foreground.
    func drainPending() async {
        guard let backend, pendingPush else { return }
        let snapshot = prefs
        guard (try? await backend.upsert(snapshot)) != nil else { return }
        if prefs == snapshot { pendingPush = false }   // unless she changed one meanwhile
    }

    private func apply(_ remote: ProfilePrefs) {
        isApplyingRemote = true
        themeMode = remote.themeMode
        pushEnabled = remote.pushEnabled
        focusMode = remote.focusMode
        isApplyingRemote = false
    }

    private func pushPrefs() {
        guard !isApplyingRemote else { return }
        pendingPush = true
        guard backend != nil else { return }
        Task { await drainPending() }
    }
}
