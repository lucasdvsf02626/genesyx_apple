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
    /// This build is below the server's minimum supported build. Outranks everything — see
    /// `destination` — because an out-of-date client cannot be trusted to talk to the backend.
    case updateRequired
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
    /// `updateRequired` is checked FIRST and outranks everything, including `unavailable`: a client
    /// the server has stopped supporting must be sent to update before it tries anything else. It is
    /// defaulted to `false` — like `passwordRecovery` / `consentRequired` — so the existing routing
    /// tests keep compiling, and is set for real only after a successful `app_config` read
    /// (fail-open: any missing config, malformed value, or network error leaves it false).
    static func destination(
        session: SessionAuthState,
        onboardingComplete: Bool,
        serviceAvailable: Bool,
        passwordRecovery: Bool = false,
        consentRequired: Bool = false,
        updateRequired: Bool = false
    ) -> RootDestination {
        if updateRequired { return .updateRequired }
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

/// The minimum-supported-build gate, kept pure so the comparison is unit-testable without a network
/// or SwiftUI. Everything here is fail-open: any input it cannot make sense of means "no opinion",
/// and the app proceeds. The only outcome that blocks launch is a build strictly below a numeric
/// minimum the server actually supplied.
enum VersionGate {
    /// This build (`CFBundleVersion`), the value compared against the server's minimum. `0` if the
    /// key is somehow absent or non-numeric — which, being below any real minimum, fails open by
    /// never exceeding a minimum that was set, and only gates if a minimum above 0 is configured.
    static func currentBuild() -> Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    }

    /// Parses the server's stored value. `nil` (absent / non-numeric / empty) means "no opinion".
    static func parseBuild(_ value: String?) -> Int? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespaces), let build = Int(trimmed) else { return nil }
        return build
    }

    /// True only when there is a numeric minimum AND this build is strictly below it.
    static func requiresUpdate(currentBuild: Int, minimumSupportedBuild: Int?) -> Bool {
        guard let minimum = minimumSupportedBuild else { return false }
        return currentBuild < minimum
    }

    /// Where the Update button sends her. Prefers an `APPSTORE_URL` from Info.plist (set it to the
    /// numeric listing — `https://apps.apple.com/app/idXXXXXXXX` — once the app has one); otherwise
    /// falls back to opening the App Store app so she can search for the update.
    static var appStoreURL: URL {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "APPSTORE_URL") as? String,
           !configured.isEmpty, let url = URL(string: configured) {
            return url
        }
        return URL(string: "itms-apps://apps.apple.com/")!
    }
}
