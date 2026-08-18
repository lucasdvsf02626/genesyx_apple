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
    /// She arrived through a password-reset link. Outranks `mainTabs` — see `destination`.
    case passwordRecovery
    /// Signed in, but there is no Article 9 consent on record for the wording currently in force.
    /// Outranks `mainTabs` — see `destination`.
    case consentRequired
}

enum RootRouting {
    /// Session state is the credential. `onboardingComplete` is only a progress flag: it
    /// decides whether a signed-out user sees the quiz or the login screen, never whether
    /// she can see Home.
    ///
    /// Release builds with no backend fail closed (`unavailable`). Debug may run local-only.
    ///
    /// `passwordRecovery` is checked BEFORE session state, and that ordering is the point of it.
    /// Redeeming a reset link produces a genuine session, so a plain `switch` on `session` would
    /// send her to `mainTabs` — into the app, old password still valid, never asked to choose a new
    /// one. The link would be a way past the gate rather than a way to fix a lockout. It is
    /// deliberately NOT defaulted at the call site in `RootView`; it is defaulted here only so the
    /// existing routing tests, which are about a different question, keep compiling unchanged.
    /// `consentRequired` outranks `mainTabs` and is ranked BELOW `passwordRecovery`, which is the
    /// only ordering that works. A woman locked out of her account cannot meaningfully answer a
    /// consent question, and choosing a new password processes no health data — so the reset has to
    /// come first. Everything the tabs contain is special-category data, so consent comes before
    /// them. It is checked only for `signedIn` because the trail is hers: there is nobody to ask
    /// while the session is unresolved, and onboarding asks on its own screen before the quiz.
    ///
    /// Defaulted to `false` for the same reason `passwordRecovery` is — so the existing routing
    /// tests, which are about a different question, keep compiling — and it is deliberately NOT
    /// defaulted at the call site in `RootView`.
    static func destination(
        session: SessionAuthState,
        onboardingComplete: Bool,
        serviceAvailable: Bool,
        passwordRecovery: Bool = false,
        consentRequired: Bool = false
    ) -> RootDestination {
        guard serviceAvailable else { return .unavailable }
        if passwordRecovery { return .passwordRecovery }
        switch session {
        case .resolving:
            return .resolving
        case .signedIn:
            return consentRequired ? .consentRequired : .mainTabs
        case .signedOut:
            return onboardingComplete ? .mandatoryAuth : .onboarding
        }
    }
}
