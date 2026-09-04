import SwiftUI
import AuthenticationServices
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
    @EnvironmentObject private var consent: ConsentRepository
    @EnvironmentObject private var notifications: NotificationService
    @AppStorage("genesyx.onboardingComplete") private var onboardingComplete = false

    @State private var invite: InvitePresentation?
    @State private var showAuthFromInvite = false
    @State private var heldInviteCode: String?
    /// Set when a recovery link fails to redeem. Held in the view rather than the repository
    /// because a failed exchange leaves no session and lowers `passwordRecoveryActive` again — so
    /// without this she would be bounced back to the sign-in screen with no explanation, which is
    /// indistinguishable from the link doing nothing at all.
    @State private var recoveryLinkError: String?

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
            case .consentRequired:
                // Declining here records the refusal rather than merely dismissing the screen. It
                // has to leave a trace: an unanswered question comes back next launch, and a woman
                // re-asked on every launch has not been given a free choice. `withdraw()` is the
                // accurate word for it — as of this moment Genesyx has no permission, and that is
                // what the trail should say.
                //
                // No back arrow: this surface is a root destination with nothing behind it, and the
                // arrow used to record the same withdrawal as "Not now" — an existing user upgrading
                // into this new screen could refuse without ever reading the question, which then
                // read as every logging control in the app being broken. Only an answer leaves.
                ConsentView(
                    onAgree: { consent.grant() },
                    onDecline: { consent.withdraw() },
                    onBack: nil)
            case .updateRequired:
                UpdateRequiredView()
            case .mainTabs:
                MainTabView()
            case .passwordRecovery:
                ResetPasswordView(linkError: recoveryLinkError,
                                  onFinished: { recoveryLinkError = nil })
            }
        }
        .preferredColorScheme(colorScheme)
        .onOpenURL { url in
            #if canImport(GoogleSignIn)
            if GIDSignIn.sharedInstance.handle(url) { return }   // Google OAuth callback
            #endif
            // Checked before the invite parser: a recovery URL is not an invite, and until now it
            // fell through both branches and was discarded without a trace.
            if DeepLink.isPasswordRecovery(url) { receiveRecovery(url); return }
            if let code = DeepLink.inviteCode(from: url) { receiveInvite(code) }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL, let code = DeepLink.inviteCode(from: url) {
                receiveInvite(code)
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: ASAuthorizationAppleIDProvider.credentialRevokedNotification
        )) { _ in
            session.handleAppleCredentialRevoked()
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
            serviceAvailable: container.isServiceAvailable,
            passwordRecovery: session.passwordRecoveryActive || recoveryLinkError != nil,
            consentRequired: ConsentLogic.needsAsking(consent.events),
            updateRequired: container.updateRequired
        )
    }

    /// Redeems a recovery link. Any failure is turned into copy she can act on rather than a
    /// silent return to the sign-in screen. The underlying error is deliberately not shown or
    /// logged: it can carry the token and the reason, and neither belongs on screen or in a log.
    private func receiveRecovery(_ url: URL) {
        recoveryLinkError = nil
        Task {
            do {
                try await session.beginPasswordRecovery(url: url)
            } catch {
                recoveryLinkError = "This reset link has expired or has already been used. "
                    + "Ask for a new one, and open it on this phone."
            }
        }
    }

    /// A signed-out invite is held, never used to mount private tabs. After a successful
    /// sign-in the same code is presented again.
    ///
    /// Partner linking is intentionally excluded from the 1.2.0 public release, and this is the
    /// only place `invite` or `heldInviteCode` is ever set — both the custom-scheme and the
    /// universal-link handler call through here, and `resumeHeldInvite` can only replay a code
    /// this function stored. So the single guard below closes every route to `InviteView`: an
    /// invite URL opens the app and then does nothing at all. See `FeatureFlags`.
    private func receiveInvite(_ code: String) {
        guard FeatureFlags.partnerInvites else { return }
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

/// Shown when this build is below the server's minimum supported build. A hard stop with no
/// dismissal — it is a root destination, so `RootView` simply never mounts anything else while it
/// is current. Modelled on `ServiceUnavailableView`.
private struct UpdateRequiredView: View {
    @Environment(\.openURL) private var openURL
    var body: some View {
        ZStack {
            GenesyxColor.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("GENESYX")
                    .font(.gxCardHeading)
                    .tracking(2)
                    .foregroundStyle(GenesyxColor.foreground)
                Text("This version of Genesyx is no longer supported.")
                    .font(.gxTitle)
                    .foregroundStyle(GenesyxColor.foreground)
                    .multilineTextAlignment(.center)
                Text("Please update to continue.")
                    .font(.gxBody)
                    .foregroundStyle(GenesyxColor.mutedForeground)
                    .multilineTextAlignment(.center)
                Button(action: { openURL(VersionGate.appStoreURL) }) {
                    Text("Update")
                        .font(.gxLabel).frame(maxWidth: .infinity).frame(height: 48)
                        .background(GenesyxColor.primary).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .accessibilityIdentifier("root.updateRequired.update")
            }
            .frame(maxWidth: 360)
            .padding(24)
            .accessibilityIdentifier("root.updateRequired")
        }
    }
}
