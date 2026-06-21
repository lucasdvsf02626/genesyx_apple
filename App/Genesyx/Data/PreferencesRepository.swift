import Foundation
import GenesyxCore

/// App preferences (theme, push toggle, current focus), persisted on-device.
/// `themeMode` drives the app's color scheme. Mirrors the Android `PreferencesRepository`.
@MainActor
final class PreferencesRepository: ObservableObject {

    @Published var themeMode: ThemeMode { didSet { store.setString(themeMode.rawValue, forKey: themeKey) } }
    @Published var pushEnabled: Bool { didSet { store.setBool(pushEnabled, forKey: pushKey) } }
    @Published var focusMode: FocusMode { didSet { store.setString(focusMode.rawValue, forKey: focusKey) } }

    private let store: LocalStore
    private let themeKey = "theme_mode"
    private let pushKey = "push_enabled"
    private let focusKey = "focus_mode"

    init(store: LocalStore) {
        self.store = store
        self.themeMode = store.string(forKey: themeKey).flatMap(ThemeMode.init(rawValue:)) ?? .system
        self.pushEnabled = store.bool(forKey: pushKey, default: true)
        self.focusMode = store.string(forKey: focusKey).flatMap(FocusMode.init(rawValue:)) ?? .prep
    }
}
