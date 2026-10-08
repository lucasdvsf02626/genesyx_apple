import Foundation

/// DRAFT WORDING: pending editorial review.
///
/// The words of the Fertility Kit's account area: activating, restoring and starting the 90-Day
/// Programme. Nothing here hints that internal codes exist or what a valid one looks like.
public enum FertilityKitAccessCopy {

    // MARK: Activation

    public static let activationTitle = "Activate your Fertility Kit"
    public static let activationBody = "Enter the activation code from your kit. Activating gives you access. Your 90-Day Programme starts only when you choose to start it."
    public static let fieldLabel = "Activation code"
    public static let activateAction = "Activate"

    /// What came of one attempt to activate. The app maps its own result to this; a result that
    /// has nothing to say (another call was in flight) maps to none.
    public enum Activation: CaseIterable {
        case activated, alreadyActive, empty, notRecognised, notAvailableInThisBuild, couldNotReachProvider, signedOut
    }

    public static func message(for activation: Activation) -> String {
        switch activation {
        case .activated: return "Your Fertility Kit is active. You can start your 90-Day Programme whenever you are ready."
        case .alreadyActive: return "This account already has Fertility Kit access."
        case .empty: return "Enter your activation code."
        case .notRecognised: return "That code was not recognised. Check it and try again."
        case .notAvailableInThisBuild: return "Activation is not available in this version of the app."
        case .couldNotReachProvider: return "We could not check your code. Check your connection and try again."
        case .signedOut: return "Sign in to activate your Fertility Kit."
        }
    }

    // MARK: Restore

    public static let restore = "Restore access"
    public static let restoreSignedOut = "Sign in to restore your Fertility Kit access."

    public static func restoreMessage(verified: Bool, hasAccess: Bool) -> String {
        switch (verified, hasAccess) {
        case (true, true): return "Your Fertility Kit access is active."
        case (true, false): return "We could not find Fertility Kit access for this account."
        case (false, true): return "We could not check just now. Your access is still active on this device."
        case (false, false): return "We could not check just now. Try again when you are online."
        }
    }

    // MARK: Starting the programme

    public static let startTitle = "Start your 90-Day Programme"
    public static let startBody = "Day 1 is the date you choose. You can start today or pick a later date."
    /// A later date is final from the moment it is confirmed, before day 1.
    public static let finalNote = "Once you confirm, the start date cannot be changed."
    public static let startToday = "Start today"
    public static let startLater = "Choose a later date"
    public static let startDateLabel = "Start date"

    public static func startOn(_ date: String) -> String { "Start on \(date)" }

    public static let reviewToday = "Your programme will start today."

    public static func reviewLater(_ date: String) -> String { "Your programme will start on \(date)." }

    public static let commit = "Start My Programme"

    public static func alreadyStarted(_ date: String) -> String { "Your programme already has a start date: \(date)." }

    public static let refusedNoAccess = "Activate your Fertility Kit to start the programme."
    public static let refusedNoConsent = "The programme needs your health data permission."

    // MARK: The card

    public static func startsOn(_ date: String) -> String { "Your programme starts on \(date)" }

    public static let startsTomorrow = "Starts tomorrow"

    public static func startsInDays(_ days: Int) -> String { "Starts in \(days) days" }

    public static let stopped = "Your 90-Day Programme is not running."

    // MARK: Registry

    /// Every constant, and one or two samples of every function.
    public static var allSurfaces: [String] {
        [activationTitle, activationBody, fieldLabel, activateAction, restore, restoreSignedOut,
         restoreMessage(verified: true, hasAccess: true), restoreMessage(verified: true, hasAccess: false),
         restoreMessage(verified: false, hasAccess: true), restoreMessage(verified: false, hasAccess: false),
         startTitle, startBody, finalNote, startToday, startLater, startDateLabel, startOn("12 October"),
         reviewToday, reviewLater("12 October"), commit, alreadyStarted("12 October"),
         refusedNoAccess, refusedNoConsent, startsOn("12 October"), startsTomorrow, startsInDays(3), stopped]
            + Activation.allCases.map(message(for:))
    }
}
