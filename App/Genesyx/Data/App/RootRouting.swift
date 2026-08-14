import Foundation

/// The three states the root surface is allowed to know about. `resolving` exists so private
/// tabs cannot appear for a frame while a cached token is still being validated.
enum SessionAuthState: Equatable {
    case resolving
    case signedOut
    case signedIn
}

/// What `RootView` is allowed to mount. Kept as a pure function so a test can pin the gate
/// without launching SwiftUI, and so a later "restore the old onboarding-only route" cannot
/// pass by editing the view and leaving the decision table behind.
enum RootDestination: Equatable {
    case resolving
    case onboarding
    case mandatoryAuth
    case mainTabs
    case unavailable
}

enum RootRouting {
    /// Session state is the credential. `onboardingComplete` is only a progress flag: it
    /// decides whether a signed-out user sees the quiz or the login screen, never whether
    /// she can see Home.
    ///
    /// Release builds with no backend fail closed (`unavailable`). Debug may run local-only.
    static func destination(
        session: SessionAuthState,
        onboardingComplete: Bool,
        serviceAvailable: Bool
    ) -> RootDestination {
        guard serviceAvailable else { return .unavailable }
        switch session {
        case .resolving:
            return .resolving
        case .signedIn:
            return .mainTabs
        case .signedOut:
            return onboardingComplete ? .mandatoryAuth : .onboarding
        }
    }
}
