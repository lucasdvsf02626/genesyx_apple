import GenesyxCore
import SwiftUI
import UIKit

/// Root of the pregnancy test scan cover: permission, camera, analysing, result. The presenter
/// wraps it in `.withAppEnvironment(container)`.
///
/// `LhScanCaptureView` for the pregnancy test strip: the same drivers over the same reducer. It
/// differs on purpose in three ways: every scan ending gives the same haptic, the whole cover
/// (a result included) is hidden while the app is not active, and nothing about her cycle is read.
struct HcgScanCaptureView: View {
    let services: HcgScanServices
    let onExit: (ScanExit) -> Void

    @EnvironmentObject private var hcg: HcgRepository
    @EnvironmentObject private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase

    @State private var session: HcgScanSession
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

    init(services: HcgScanServices, onExit: @escaping (ScanExit) -> Void) {
        self.services = services
        self.onExit = onExit
        _session = State(initialValue: HcgScanSession(configuration: services.configuration))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            content
        }
        .background(GenesyxColor.background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hcg.capture")
        // Over the result as well as the camera.
        .hcgPrivacyCover(scenePhase != .active)
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
            await services.perform(work, source: source, testImage: takeTestImage()) { session.handle($0) }
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
        .onChange(of: session.state) { state in
            switch state {
            case .capturing:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .result(let resolution):
                if case .reading = resolution {
                    resultID = UUID().uuidString
                    capturedAt = Date()
                    saveState = .unsaved
                }
                // One haptic for every way a scan ends: it must not tell the outcomes apart.
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            default:
                break
            }
            announceGuidance()
        }
        .onDisappear { source?.stop() }
    }

    private var topBar: some View {
        ZStack {
            Text(HcgScanCopy.cameraTitle)
                .font(.gxCardHeadingSmall)
                .foregroundStyle(GenesyxColor.foreground)
                .accessibilityAddTraits(.isHeader)
            HStack {
                // Once the result is saved the way out is Done, not a button that reads as
                // undoing the save.
                if saveState != .saved {
                    Button(HcgScanCopy.cancel) { onExit(.cancelled) }
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
            HcgResultView(
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
                guidance: HcgScanCopy.guidance(for: session.state),
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
    /// and assessor, and starts unsaved, so Cancel is back for the whole of the new scan.
    private func begin() {
        guard let source else { return }
        saveState = .unsaved
        attempt += 1
        session.handle(.begin(source.access))
    }

    /// The classification and provenance come straight from the resolver's reading; nothing is
    /// recomputed. Only a reading is ever saved: the other screens have no Save.
    private func save(_ resolution: HcgScanResolution) {
        guard case .reading(let classification, let provenance) = resolution else { return }
        let saved = hcg.create(HcgResult(
            id: resultID, recordedAt: capturedAt, classification: classification, scan: provenance))
        saveState = saved ? .saved : .refused
    }

    /// Speaks the guidance line when VoiceOver is on. Asked on every event, so a line the
    /// throttle held back is spoken once its interval has passed.
    private func announceGuidance() {
        guard UIAccessibility.isVoiceOverRunning else { return }
        let text = HcgScanCopy.guidance(for: session.state)
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
private func hcgPreviewContent(_ state: HcgScannerState) -> some View {
    ScanCaptureContent(
        state: state, guidance: HcgScanCopy.guidance(for: state),
        expectedAspectRatio: HcgStripConfiguration.developmentPlaceholder.expectedAspectRatio,
        preview: AnyView(Color.black), isObscured: false,
        onManualEntry: {}, onOpenSettings: {}, onTryAgain: {})
        .background(GenesyxColor.background)
        .withPreviewEnvironment()
}

#Preview("Pregnancy test scan: searching") { hcgPreviewContent(.searching) }
#Preview("Pregnancy test scan: line areas not found") { hcgPreviewContent(.qualityIssue(.reagentAreaNotFound)) }
#Preview("Pregnancy test scan: ready") { hcgPreviewContent(.ready) }
#Preview("Pregnancy test scan: analysing") { hcgPreviewContent(.analysing) }
#Preview("Pregnancy test scan: paused") { hcgPreviewContent(.interrupted(.other)) }
#Preview("Pregnancy test scan: permission denied") { hcgPreviewContent(.permissionDenied) }
#Preview("Pregnancy test scan: camera unavailable") { hcgPreviewContent(.cameraUnavailable) }

#Preview("Pregnancy test capture: live") {
    HcgScanCaptureView(services: .debug(scenario: .noTestLineDetected, frames: .reading(4.4)), onExit: { _ in })
        .withPreviewEnvironment()
}
#endif
