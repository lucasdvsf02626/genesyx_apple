import SwiftUI
import GenesyxCore
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Decides the top-level surface: onboarding until complete, then the main tabs.
/// Also handles partner-invite deep links (custom scheme + Universal Links).
/// The dashboard is gated behind Auth: `onboardingComplete` only becomes true after a successful
/// sign-in inside the onboarding flow (Android parity), so the main tabs are unreachable otherwise.
struct RootView: View {

    @EnvironmentObject private var prefs: PreferencesRepository
    @EnvironmentObject private var session: SessionRepository
    @AppStorage("genesyx.onboardingComplete") private var onboardingComplete = false

    @State private var invite: InvitePresentation?
    @State private var showAuthFromInvite = false

    /// The invite she's mid-way through accepting, held across the sign-in detour. A partner
    /// arriving from a share link almost always has no account yet, so dropping the code here
    /// (as we used to) meant the invite silently vanished on the one path everybody takes.
    @State private var codeAwaitingSignIn: String?

    var body: some View {
        Group {
            if onboardingComplete {
                MainTabView()
            } else {
                OnboardingFlowView(onFinished: { onboardingComplete = true })
            }
        }
        .preferredColorScheme(colorScheme)
        .onOpenURL { url in
            #if canImport(GoogleSignIn)
            if GIDSignIn.sharedInstance.handle(url) { return }   // Google OAuth callback
            #endif
            if let code = DeepLink.inviteCode(from: url) { invite = InvitePresentation(code: code) }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL, let code = DeepLink.inviteCode(from: url) {
                invite = InvitePresentation(code: code)
            }
        }
        .sheet(item: $invite) { presentation in
            InviteView(
                code: presentation.code,
                onAccepted: { invite = nil },
                onBack: { invite = nil },
                onSignIn: { codeAwaitingSignIn = presentation.code; invite = nil; showAuthFromInvite = true }
            )
        }
        .sheet(isPresented: $showAuthFromInvite, onDismiss: {
            // Signed in? Bring her straight back to the invite she came here to accept.
            // Cancelled? Drop it, so she isn't trapped in a sign-in/invite loop.
            if let code = codeAwaitingSignIn, session.isSignedIn {
                invite = InvitePresentation(code: code)
            }
            codeAwaitingSignIn = nil
        }) {
            AuthView()
        }
    }

    private var colorScheme: ColorScheme? {
        switch prefs.themeMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
