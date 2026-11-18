import GenesyxCore
import SwiftUI
import UIKit

/// Root of the LH scan cover: permission, camera, analysing, result. The presenter wraps it in
/// `.withAppEnvironment(container)`.
///
/// `ScanCaptureView` for the ovulation test strip: the same drivers over the same reducer, kept
/// line for line so the two covers behave alike. A lifecycle fix made to one belongs in the other.
struct LhScanCaptureView: View {
    let services: LhScanServices
    let onExit: (ScanExit) -> Void

    @EnvironmentObject private var lh: LhRepository
    @EnvironmentObject private var cycle: CycleRepository
    @EnvironmentObject private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase

    @State private var session: LhScanSession
    /// Nil until first appear, so a parent re-render never builds a second camera.
    @State private var source: (any ScanFrameSource)?
    @State private var attempt = 0
    @State private var saveState = ScanSaveState.unsaved
    /// Made once per result, so a second tap on Save rewrites the same result.
    @State private var resultID = UUID().uuidString
    @State private var capturedAt = Date()
    @State private var throttle = ScanAnnouncementThrottle()
    #if DEBUG
    /// Held only between the picker and the analyser; cleared as it is read.
    @State private var testImage: CGImage?
    #endif

    init(services: LhScanServices, onExit: @escaping (ScanExit) -> Void) {
        self.services = services
        self.onExit = onExit
        _session = State(initialValue: LhScanSession(configuration: services.configuration))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            content
        }
        .background(GenesyxColor.background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lh.capture")
        .scanPrivacyShield(showsResult, presented: true)
        .onAppear {
            guard source == nil else { return }
            source = services.makeFrameSource()
            begin()
        }
        .task(id: attempt) {
            guard let source else { return }
            for await event in source.events(assessor: services.makeAssessor(), configuration: services.configuration) {
                switch event {
                case .status(let status): session.handle(.camera(status))
                case .frame(let assessment, let time): session.handle(.frame(assessment, at: time))
                }
                announceGuidance()
            }
        }
        // Once per state entry: SwiftUI cancels the job when the state moves on, the cover goes
        // or the scan is suspended, and `perform` reports nothing once cancelled.
        .task(id: session.work) {
            guard let work = session.work, let source else { return }
            await services.perform(work, source: source, testImage: takeTestImage()) { event in
                // Asked of UIKit as the answer arrives, so it cannot come late: a scan that ends
                // while she is not looking at the app is dropped, never shown.
                if case .analysed = event, UIApplication.shared.applicationState != .active {
                    session.handle(.suspended)
                } else {
                    session.handle(event)
                }
            }
        }
        .onChange(of: session.wantsCamera) { wanted in
            if !wanted { source?.stop() }
        }
        // `.inactive` is ignored: the permission alert itself makes the scene inactive.
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                session.handle(.suspended)
            case .active:
                session.handle(.resumed)
                // Back from Settings with the camera switched on.
                if session.state == .permissionDenied, let source, source.access != .denied { begin() }
            default:
                break
            }
        }
        // The scene phase reaches this cover a third of a second or more after the app has gone,
        // and seconds after on a busy device. The scan is dropped on UIKit's own notice, posted
        // the moment the app has gone, so the camera and the analysis stop then and not later.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            session.handle(.suspended)
        }
        // And restarted on UIKit's notice: a scan dropped while the app was only inactive may
        // never see the scene phase change here, and would stay paused.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            session.handle(.resumed)
        }
        .onChange(of: session.state) { state in
            switch state {
            case .capturing:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .result(.reading):
                resultID = UUID().uuidString
                capturedAt = Date()
                saveState = .unsaved
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .result(.invalid), .result(.unreadable):
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            default:
                break
            }
            announceGuidance()
        }
        .onDisappear { source?.stop() }
    }

    /// A result is on screen. Nothing else on this cover needs hiding from the app switcher.
    private var showsResult: Bool {
        if case .result = session.state { return true }
        return false
    }

    private var topBar: some View {
        ZStack {
            Text(LhScanCopy.cameraTitle)
                .font(.gxCardHeadingSmall)
                .foregroundStyle(GenesyxColor.foreground)
                .accessibilityAddTraits(.isHeader)
            HStack {
                // Once the result is saved the way out is Done, not a button that reads as
                // undoing the save.
                if saveState != .saved {
                    Button(LhScanCopy.cancel) { onExit(.cancelled) }
                        .font(.gxBody)
                        .foregroundStyle(GenesyxColor.primary)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("scan.capture.cancel")
                }
                Spacer()
                #if DEBUG
                if session.state.isLiveGuidance {
                    ScanDebugTestImageButton { image in
                        guard session.state.isLiveGuidance else { return }
                        testImage = image
                        session.handle(.captureRequested)
                    }
                }
                #endif
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 20)
    }

    @ViewBuilder private var content: some View {
        switch session.state {
        case .result(let resolution):
            LhResultView(
                resolution: resolution,
                isSimulated: services.isSimulated,
                // A scripted result must never reach a real account.
                saveBlocked: services.isSimulated && container.backend != nil,
                saveState: saveState,
                onSave: { save(resolution) },
                onScanAgain: begin,
                onManualEntry: { onExit(.manualEntry) },
                onDone: { onExit(.saved) })
        default:
            ScanCaptureContent(
                state: session.state,
                guidance: LhScanCopy.guidance(for: session.state),
                expectedAspectRatio: services.configuration.expectedAspectRatio,
                preview: source?.makePreview() ?? AnyView(EmptyView()),
                // So the app-switcher snapshot holds no camera image.
                isObscured: scenePhase != .active,
                onManualEntry: { onExit(.manualEntry) },
                onOpenSettings: {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                },
                onTryAgain: begin)
        }
    }

    /// Open Camera, Scan Again, Scan New Test, Try Again. A new attempt gets a new event stream
    /// and assessor.
    private func begin() {
        guard let source else { return }
        attempt += 1
        // The last result's save state must not hide Cancel on the scan that follows it.
        saveState = .unsaved
        session.handle(.begin(source.access))
    }

    /// The classification and measurement come straight from the resolver's reading; nothing is
    /// recomputed. Only a reading is ever saved: the other screens have no Save.
    private func save(_ resolution: LhScanResolution) {
        guard case .reading(let classification, let measurement) = resolution else { return }
        let saved = lh.create(LhResult(
            id: resultID, recordedAt: capturedAt,
            cycleDay: LhCycleDay.snapshot(settings: cycle.settings, at: capturedAt),
            classification: classification, scan: measurement))
        saveState = saved ? .saved : .refused
    }

    /// Speaks the guidance line when VoiceOver is on. Asked on every event, so a line the
    /// throttle held back is spoken once its interval has passed.
    private func announceGuidance() {
        guard UIAccessibility.isVoiceOverRunning else { return }
        let text = LhScanCopy.guidance(for: session.state)
        let now = ProcessInfo.processInfo.systemUptime
        if throttle.shouldAnnounce(text, at: now, urgent: !session.state.isLiveGuidance) {
            UIAccessibility.post(notification: .announcement, argument: text)
        }
    }

    private func takeTestImage() -> CGImage? {
        #if DEBUG
        defer { testImage = nil }
        return testImage
        #else
        return nil
        #endif
    }
}

#if DEBUG
@MainActor
private func lhPreviewContent(_ state: LhScannerState) -> some View {
    ScanCaptureContent(
        state: state, guidance: LhScanCopy.guidance(for: state),
        expectedAspectRatio: LhStripConfiguration.developmentPlaceholder.expectedAspectRatio,
        preview: AnyView(Color.black), isObscured: false,
        onManualEntry: {}, onOpenSettings: {}, onTryAgain: {})
        .background(GenesyxColor.background)
        .withPreviewEnvironment()
}

#Preview("LH scan: searching") { lhPreviewContent(.searching) }
#Preview("LH scan: line areas not found") { lhPreviewContent(.qualityIssue(.reagentAreaNotFound)) }
#Preview("LH scan: ready") { lhPreviewContent(.ready) }
#Preview("LH scan: analysing") { lhPreviewContent(.analysing) }
#Preview("LH scan: paused") { lhPreviewContent(.interrupted(.other)) }
#Preview("LH scan: permission denied") { lhPreviewContent(.permissionDenied) }
#Preview("LH scan: camera unavailable") { lhPreviewContent(.cameraUnavailable) }

#Preview("LH capture: live") {
    LhScanCaptureView(services: .debug(scenario: .low, frames: .reading(4.4)), onExit: { _ in })
        .withPreviewEnvironment()
}
#endif
