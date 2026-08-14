import SwiftUI
import GenesyxCore
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Top-level surface. Session state is the credential; `onboardingComplete` is only a progress
/// flag. Private tabs never mount while the session is unresolved, missing, expired or revoked.
struct RootView: View {

    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var prefs: PreferencesRepository
    @EnvironmentObject private var session: SessionRepository
    @EnvironmentObject private var notifications: NotificationService
    @AppStorage("genesyx.onboardingComplete") private var onboardingComplete = false

    @State private var invite: InvitePresentation?
    @State private var showAuthFromInvite = false
    @State private var heldInviteCode: String?

    var body: some View {
        Group {
            switch destination {
            case .resolving:
                SessionResolvingView()
            case .unavailable:
                ServiceUnavailableView()
            case .onboarding:
                OnboardingFlowView(onFinished: { onboardingComplete = true })
            case .mandatoryAuth:
                AuthView(allowsDismissal: false)
            case .mainTabs:
                MainTabView()
            }
        }
        .preferredColorScheme(colorScheme)
        .onOpenURL { url in
            #if canImport(GoogleSignIn)
            if GIDSignIn.sharedInstance.handle(url) { return }   // Google OAuth callback
            #endif
            if let code = DeepLink.inviteCode(from: url) { receiveInvite(code) }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL, let code = DeepLink.inviteCode(from: url) {
                receiveInvite(code)
            }
        }
        .onChange(of: session.state) { new in
            if new == .signedIn {
                resumeHeldInvite()
            } else {
                invite = nil
                showAuthFromInvite = false
            }
        }
        .sheet(item: $invite) { presentation in
            InviteView(
                code: presentation.code,
                onAccepted: { invite = nil },
                onBack: { invite = nil },
                onSignIn: { heldInviteCode = presentation.code; invite = nil; showAuthFromInvite = true }
            )
        }
        .sheet(isPresented: $showAuthFromInvite, onDismiss: {
            if session.isSignedIn {
                resumeHeldInvite()
            }
        }) {
            AuthView(allowsDismissal: true)
        }
    }

    private var destination: RootDestination {
        RootRouting.destination(
            session: session.state,
            onboardingComplete: onboardingComplete,
            serviceAvailable: container.isServiceAvailable
        )
    }

    /// A signed-out invite is held, never used to mount private tabs. After a successful
    /// sign-in the same code is presented again.
    private func receiveInvite(_ code: String) {
        if session.isSignedIn {
            invite = InvitePresentation(code: code)
        } else {
            heldInviteCode = code
        }
    }

    private func resumeHeldInvite() {
        guard session.isSignedIn, let code = heldInviteCode else { return }
        heldInviteCode = nil
        invite = InvitePresentation(code: code)
    }

    private var colorScheme: ColorScheme? {
        switch prefs.themeMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Neutral branded hold while a cached token is validated. No tab chrome, no copy that
/// implies she is already inside the app.
private struct SessionResolvingView: View {
    var body: some View {
        ZStack {
            GenesyxColor.background.ignoresSafeArea()
            ProgressView()
                .tint(GenesyxColor.primary)
                .accessibilityIdentifier("root.resolving")
        }
    }
}

/// Release fail-closed: no backend, no mock login, no private tabs.
private struct ServiceUnavailableView: View {
    var body: some View {
        ZStack {
            GenesyxColor.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("GENESYX")
                    .font(.gxCardHeading)
                    .tracking(2)
                    .foregroundStyle(GenesyxColor.foreground)
                Text("Genesyx can’t reach its service right now.")
                    .font(.gxTitle)
                    .foregroundStyle(GenesyxColor.foreground)
                    .multilineTextAlignment(.center)
                Text("Check your connection and try again later. Your data on this phone is unchanged.")
                    .font(.gxBody)
                    .foregroundStyle(GenesyxColor.mutedForeground)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .accessibilityIdentifier("root.unavailable")
        }
    }
}
