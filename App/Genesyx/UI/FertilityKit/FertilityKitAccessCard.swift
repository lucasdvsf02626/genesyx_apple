import GenesyxCore
import SwiftUI

/// The one access card: six states, chosen only by `kit.accessState`. It is drawn in My Account,
/// on the kit home and on the gate, and leaves out the buttons that would lead to the screen she
/// is already on.
struct FertilityKitAccessCard: View {
    enum Placement { case account, kitHome, gate }

    private let placement: Placement

    @Environment(\.fertilityKit) private var kit
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var kitAccess: FertilityKitAccessService

    @State private var showActivation = false
    @State private var showStart = false
    @State private var restoreLine: String?
    @State private var waitingForRetry = false
    @State private var retried = false

    init(placement: Placement) {
        self.placement = placement
    }

    var body: some View {
        let state = kit.accessState
        VStack(alignment: .leading, spacing: 12) {
            switch state {
            case .noAccess: noAccess
            case .notStarted: notStarted
            case .scheduled(let startsOn, let days): scheduled(startsOn: startsOn, days: days)
            case .active(let day, let week, let phase): active(day: day, week: week, phase: phase)
            case .completed: completed
            case .stopped: stopped
            }
            #if DEBUG
            FertilityKitDebugControls()
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(GenesyxColor.card)
        .clipShape(RoundedRectangle(cornerRadius: placement == .account ? 16 : Theme.cardRadius))
        .sheet(isPresented: $showActivation) {
            FertilityKitActivationSheet().withAppEnvironment(container)
        }
        .sheet(isPresented: $showStart) {
            ProgrammeStartSheet(today: kit.today).withAppEnvironment(container)
        }
        .task { await refresh() }
        .onChange(of: kitAccess.isWorking) { _ in askAgainIfDue() }
    }

    private var opensKit: Bool { placement == .account }

    // MARK: The six states

    private var noAccess: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(FertilityKitCopy.premium, color: GenesyxColor.primary).accessibilityIdentifier("kit.access.premiumTag")
            Text(FertilityKitCopy.productName).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("kit.access.title")
            KitLine(FertilityKitCopy.noAccessDescription, muted: true)
            GxPrimaryButton(title: FertilityKitCopy.activate) { showActivation = true }
                .accessibilityIdentifier("kit.access.activate")
            GxGhostButton(title: FertilityKitAccessCopy.restore) { restore() }
                .disabled(kitAccess.isWorking)
                .accessibilityIdentifier("kit.access.restore")
            if let restoreLine {
                KitLine(restoreLine, muted: true).accessibilityIdentifier("kit.access.message")
            }
        }
        .kitContainer("kit.access.state.noAccess")
    }

    private var notStarted: some View {
        let items = FertilityKitCopy.includedItems(scanAvailable: kit.scanAvailable)
        return VStack(alignment: .leading, spacing: 12) {
            title(FertilityKitCopy.accessActive)
            KitLine(FertilityKitCopy.includedHeading, muted: true)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(GenesyxColor.primary)
                        Text(item).font(.gxBody).foregroundStyle(GenesyxColor.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .kitRow("kit.access.included.\(index)", label: item)
                }
            }
            ConsentWithdrawnBanner()
            GxPrimaryButton(title: FertilityKitCopy.startProgramme, enabled: kit.planInput.consentActive) {
                showStart = true
            }
            .accessibilityIdentifier("kit.access.start")
        }
        .kitContainer("kit.access.state.notStarted")
    }

    private func scheduled(startsOn: CalendarDate, days: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            title(FertilityKitCopy.accessActive)
            KitLines([FertilityKitAccessCopy.startsOn(FertilityKitDates.dayMonth(startsOn)),
                      days == 1 ? FertilityKitAccessCopy.startsTomorrow : FertilityKitAccessCopy.startsInDays(days)],
                     identifier: "kit.access.scheduledLine")
            if opensKit { openButton }
        }
        .kitContainer("kit.access.state.scheduled")
    }

    private func active(day: Int, week: Int, phase: ProgrammePhase) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(FertilityPictureCopy.dayOfProgramme(day)).font(.gxCardHeading)
                    .foregroundStyle(GenesyxColor.foreground)
                    .accessibilityIdentifier("kit.access.dayLabel")
                if let phaseTitle = ProgrammeContent.draft.phaseTitles[phase] {
                    Text(phaseTitle).font(.gxBody).foregroundStyle(GenesyxColor.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("kit.access.phase")
                }
                KitLine(FertilityKitCopy.weekOfProgramme(week), muted: true)
            }
            if opensKit {
                GxPrimaryButton(title: FertilityKitCopy.continueProgramme) { kit.open(.fertilityKit) }
                    .accessibilityIdentifier("kit.access.continue")
            }
        }
        .kitContainer("kit.access.state.active")
    }

    private var completed: some View {
        VStack(alignment: .leading, spacing: 12) {
            title(FertilityKitCopy.programmeCompleted)
            GxPrimaryButton(title: FertilityKitCopy.viewNinetyDayReview) { kit.open(.kitNinetyDayReview) }
                .accessibilityIdentifier("kit.access.viewReview")
            if opensKit {
                GxGhostButton(title: FertilityKitCopy.continueWithGenesyx) { kit.open(.fertilityKit) }
                    .accessibilityIdentifier("kit.access.continueWithGenesyx")
            }
        }
        .kitContainer("kit.access.state.completed")
    }

    private var stopped: some View {
        VStack(alignment: .leading, spacing: 12) {
            KitLine(FertilityKitAccessCopy.stopped)
            if opensKit { openButton }
        }
        .kitContainer("kit.access.state.stopped")
    }

    private var openButton: some View {
        // The button's own capsule is the card colour, which is invisible on this card: a tint
        // of the primary colour, the colour of its text, goes over it.
        KitSecondaryButton(title: FertilityKitCopy.openKit) { kit.open(.fertilityKit) }
            .overlay(Capsule().fill(GenesyxColor.primary.opacity(0.12)).allowsHitTesting(false))
            .accessibilityIdentifier("kit.access.open")
    }

    private func title(_ text: String) -> some View {
        Text(text).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("kit.access.title")
    }

    // MARK: Asking the service

    private func restore() {
        Task {
            let result = await kitAccess.restore()
            restoreLine = FertilityKitAccessPresentation.restoreLine(for: result)
        }
    }

    /// The answer shows nothing. A call that meets another in flight is asked again once, when
    /// the other has finished.
    private func refresh() async {
        let result = await kitAccess.refresh()
        if result == .busy {
            waitingForRetry = true
            askAgainIfDue()
        }
    }

    private func askAgainIfDue() {
        guard waitingForRetry, FertilityKitAccessPresentation.shouldAskAgain(
            after: .busy, isWorking: kitAccess.isWorking, alreadyRetried: retried) else { return }
        retried = true
        waitingForRetry = false
        Task { _ = await kitAccess.refresh() }
    }
}

/// What the access card and the activation sheet decide, as plain functions.
enum FertilityKitAccessPresentation {

    /// A `.busy` answer means another call was in flight: ask again once, when it has finished.
    static func shouldAskAgain(after result: FertilityKitVerificationResult, isWorking: Bool,
                               alreadyRetried: Bool) -> Bool {
        result == .busy && !isWorking && !alreadyRetried
    }

    /// Activation cannot be sent empty or while a call is running. Only what she typed is
    /// looked at: nothing is shaped.
    static func canSubmit(entry: String, isWorking: Bool) -> Bool {
        !isWorking && !entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// nil when another call was in flight: that says nothing to her.
    static func activationMessage(for result: FertilityKitActivationResult) -> String? {
        let outcome: FertilityKitAccessCopy.Activation
        switch result {
        case .activated: outcome = .activated
        case .alreadyActive: outcome = .alreadyActive
        case .empty: outcome = .empty
        case .notRecognised: outcome = .notRecognised
        case .notAvailableInThisBuild: outcome = .notAvailableInThisBuild
        case .couldNotReachProvider: outcome = .couldNotReachProvider
        case .signedOut: outcome = .signedOut
        case .busy: return nil
        }
        return FertilityKitAccessCopy.message(for: outcome)
    }

    /// nil when another call was in flight.
    static func restoreLine(for result: FertilityKitVerificationResult) -> String? {
        switch result {
        case .verified(let hasAccess): return FertilityKitAccessCopy.restoreMessage(verified: true, hasAccess: hasAccess)
        case .couldNotVerify(let hasAccess): return FertilityKitAccessCopy.restoreMessage(verified: false, hasAccess: hasAccess)
        case .signedOut: return FertilityKitAccessCopy.restoreSignedOut
        case .busy: return nil
        }
    }

    /// The activation succeeded, or the account already held access.
    static func isSuccess(_ result: FertilityKitActivationResult) -> Bool {
        result == .activated || result == .alreadyActive
    }
}

#if DEBUG
#Preview {
    ScrollView { FertilityKitAccessCard(placement: .account).padding(20) }
        .gxPageBackground()
        .withKitPreview(access: false)
}
#endif
