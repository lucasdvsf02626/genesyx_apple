import Foundation
import GenesyxCore

/// App preferences (theme, push toggle, current focus), persisted on-device.
/// `themeMode` drives the app's color scheme. Mirrors the Android `PreferencesRepository`.
@MainActor
final class PreferencesRepository: ObservableObject {

    @Published var themeMode: ThemeMode { didSet { store.setString(themeMode.rawValue, forKey: themeKey) } }
    @Published var pushEnabled: Bool { didSet { store.setBool(pushEnabled, forKey: pushKey) } }
    @Published var focusMode: FocusMode { didSet { store.setString(focusMode.rawValue, forKey: focusKey) } }
    /// Streak-milestone flags already celebrated (`Milestone.flagKey`), so each fires once.
    /// The StreakEngine clears a flag when its streak lapses, letting a re-achievement re-fire.
    var celebratedMilestones: Set<String> { didSet { store.save(celebratedMilestones, forKey: milestonesKey) } }

    private let store: LocalStore
    private let themeKey = "theme_mode"
    private let pushKey = "push_enabled"
    private let focusKey = "focus_mode"
    private let milestonesKey = "celebrated_milestones"

    init(store: LocalStore) {
        self.store = store
        self.themeMode = store.string(forKey: themeKey).flatMap(ThemeMode.init(rawValue:)) ?? .system
        self.pushEnabled = store.bool(forKey: pushKey, default: true)
        self.focusMode = store.string(forKey: focusKey).flatMap(FocusMode.init(rawValue:)) ?? .prep
        self.celebratedMilestones = store.load(Set<String>.self, forKey: milestonesKey) ?? []
    }
}
