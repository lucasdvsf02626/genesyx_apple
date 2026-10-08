import GenesyxCore
import SwiftUI
import UIKit

/// Wraps every Fertility Kit screen. It is the one place that observes the repositories for the
/// kit, works out today, and decides access: a change in any repository rebuilds the context and
/// every screen that reads it.
///
/// Built only by More, so outside More the environment default applies and nothing of the kit
/// renders. It reads nothing about pregnancy test records.
struct FertilityKitHost<Content: View>: View {
    private let gated: Bool
    private let scanAvailable: Bool
    private let cycleHistoryAvailable: Bool
    private let navigation: FertilityKitNavigation
    private let content: Content

    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var kitAccess: FertilityKitAccessService
    @EnvironmentObject private var programme: ProgrammeRepository
    @EnvironmentObject private var dailyLog: DailyLogRepository
    @EnvironmentObject private var ph: PhRepository
    @EnvironmentObject private var lh: LhRepository
    @EnvironmentObject private var periods: PeriodRepository
    @EnvironmentObject private var cycle: CycleRepository
    @EnvironmentObject private var prefs: PreferencesRepository
    @EnvironmentObject private var consent: ConsentRepository
    @EnvironmentObject private var session: SessionRepository

    /// Read again when a screen appears, when the app becomes active and when the calendar day
    /// changes, so a screen left open over midnight moves on. Not on the scene phase: pushed
    /// content hears it late or not at all.
    @State private var today = FertilityKitClock.current()

    /// `gated` screens show only the access card until the account holds access. The plan
    /// service does not check access, so it is decided here and nowhere else.
    init(gated: Bool = true, scanAvailable: Bool, cycleHistoryAvailable: Bool,
         navigation: FertilityKitNavigation, @ViewBuilder content: () -> Content) {
        self.gated = gated
        self.scanAvailable = scanAvailable
        self.cycleHistoryAvailable = cycleHistoryAvailable
        self.navigation = navigation
        self.content = content()
    }

    var body: some View {
        let context = makeContext()
        Group {
            if gated && !context.hasAccess {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        FertilityKitAccessCard(placement: .gate)
                    }
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
                    .kitContainer("kit.gate")
                }
                .frame(maxWidth: .infinity)
                .gxPageBackground()
                .navigationBarTitleDisplayMode(.inline)
            } else {
                content
            }
        }
        .environment(\.fertilityKit, context)
        .onAppear { today = FertilityKitClock.current() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            today = FertilityKitClock.current()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: DispatchQueue.main)) { _ in
            today = FertilityKitClock.current()
        }
    }

    private func makeContext() -> FertilityKitContext {
        let source = ProgrammePlanSource(programme: programme, dailyLog: dailyLog, ph: ph, lh: lh, periods: periods,
                                         cycle: cycle, prefs: prefs, consent: consent,
                                         scanFeaturesAvailable: scanAvailable)
        return FertilityKitContext(
            isHosted: container.fertilityKit,
            today: today,
            scanAvailable: scanAvailable,
            cycleHistoryAvailable: cycleHistoryAvailable,
            hasAccess: container.fertilityKit && kitAccess.hasAccess,
            planInput: source.input(today: today),
            cycles: periods.cycles,
            refusedPeriodStarts: Set(periods.refusedStarts),
            phReadings: ph.readings,
            lhResults: scanAvailable ? lh.results : [],
            navigation: navigation)
    }
}
