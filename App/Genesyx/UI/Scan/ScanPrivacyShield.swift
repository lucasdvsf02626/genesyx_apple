import SwiftUI
import UIKit

/// Hides the whole app while it is not active and a test result is on screen, so the app-switcher
/// card is one flat colour: no result, and no title, back button or tab bar to say which screen
/// she was on.
///
/// A window of its own above everything the app draws, because a result can sit in a pushed
/// screen, a sheet, a full-screen cover or under an alert, and an overlay inside any one of them
/// leaves the others showing. Nothing underneath is touched, so the screen is exactly as she left
/// it when the window goes.
///
/// It follows UIKit's own notices and not the scene phase: the phase reaches a pushed or covered
/// screen a third of a second or more late, and the app-switcher peek never reaches the
/// background at all.
///
/// Built the first time a scan screen asks for it. Until then it observes nothing and owns no
/// window.
@MainActor
final class ScanPrivacyShield: NSObject, ObservableObject {
    static let shared = ScanPrivacyShield()

    /// False from the moment the app is about to stop being active until it is active again.
    @Published private(set) var appIsActive = UIApplication.shared.applicationState == .active

    /// The screens with a result showing now.
    private var onScreen: Set<UUID> = []
    private var cover: UIWindow?

    private override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(willResignActive),
                           name: UIApplication.willResignActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(didBecomeActive),
                           name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    func set(_ id: UUID, onScreen showing: Bool) {
        if showing { onScreen.insert(id) } else { onScreen.remove(id) }
        // A screen that arrives while the app is away is covered at once.
        if showing, !appIsActive { raise() }
    }

    @objc private func willResignActive() {
        appIsActive = false
        raise()
    }

    @objc private func didBecomeActive() {
        appIsActive = true
        cover?.isHidden = true
        cover = nil
    }

    private func raise() {
        guard cover == nil, !onScreen.isEmpty,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.isUserInteractionEnabled = false
        // The app's own light or dark setting, which a new window does not inherit.
        window.overrideUserInterfaceStyle = (scene.keyWindow ?? scene.windows.first)?.traitCollection.userInterfaceStyle ?? .unspecified
        let controller = UIViewController()
        controller.view.backgroundColor = UIColor(GenesyxColor.background)
        window.rootViewController = controller
        window.isHidden = false
        cover = window
    }
}

private struct TabIsSelectedKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// False inside a tab that is kept alive but is not the one showing. Set by `MainTabView`.
    var tabIsSelected: Bool {
        get { self[TabIsSelectedKey.self] }
        set { self[TabIsSelectedKey.self] = newValue }
    }
}

private struct ScanPrivacyShieldModifier: ViewModifier {
    let sensitive: Bool
    let presented: Bool

    @Environment(\.tabIsSelected) private var tabIsSelected
    @State private var id = UUID()

    func body(content: Content) -> some View {
        // A sheet or cover is on screen whatever tab is selected beneath it.
        let showing = sensitive && (presented || tabIsSelected)
        content
            .onAppear { ScanPrivacyShield.shared.set(id, onScreen: showing) }
            .onChange(of: showing) { ScanPrivacyShield.shared.set(id, onScreen: $0) }
            .onDisappear { ScanPrivacyShield.shared.set(id, onScreen: false) }
    }
}

extension View {
    /// Marks a screen whose content must not be seen while the app is not active. `sensitive` is
    /// whether it holds anything to hide at the moment; `presented` is true for the root of a
    /// sheet or a full-screen cover and false for a screen pushed inside a tab.
    func scanPrivacyShield(_ sensitive: Bool = true, presented: Bool) -> some View {
        modifier(ScanPrivacyShieldModifier(sensitive: sensitive, presented: presented))
    }
}
