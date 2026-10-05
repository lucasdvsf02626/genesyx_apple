import GenesyxCore
import SwiftUI
import UIKit

/// How the cover ended. The presenter acts on it once the cover has gone.
enum ScanExit { case cancelled, manualEntry, saved }

/// `PhRepository.create` answers at once, so saving has no in-progress phase to show.
enum ScanSaveState { case unsaved, saved, refused }

/// Root of the scan cover: permission, camera, analysing, result. The presenter wraps it in
/// `.withAppEnvironment(container)`.
///
/// It holds no rules. `PhScanSession` decides every transition; this view feeds it events, runs
/// the one job each state is waiting on, and draws the state it is given.
struct ScanCaptureView: View {
    let services: ScanServices
    let onExit: (ScanExit) -> Void

    @EnvironmentObject private var ph: PhRepository
    @EnvironmentObject private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase

    @State private var session: PhScanSession
    /// Nil until first appear, so a parent re-render never builds a second camera.
    @State private var source: (any ScanFrameSource)?
    @State private var attempt = 0
    @State private var saveState = ScanSaveState.unsaved
    /// Made once per result, so a second tap on Save rewrites the same reading.
    @State private var readingID = UUID().uuidString
    @State private var capturedAt = Date()
    @State private var throttle = ScanAnnouncementThrottle()
    #if DEBUG
    /// Held only between the picker and the analyser; cleared as it is read.
    @State private var testImage: CGImage?
    #endif

    init(services: ScanServices, onExit: @escaping (ScanExit) -> Void) {
        self.services = services
        self.onExit = onExit
        _session = State(initialValue: PhScanSession(configuration: services.configuration))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            content
        }
        .background(GenesyxColor.background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scan.capture")
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
            case .result(.reading):
                readingID = UUID().uuidString
                capturedAt = Date()
                saveState = .unsaved
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .result(.unreadable):
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            default:
                break
            }
            announceGuidance()
        }
        .onDisappear { source?.stop() }
    }

    private var topBar: some View {
        ZStack {
            Text(PhScanCopy.cameraTitle)
                .font(.gxCardHeadingSmall)
                .foregroundStyle(GenesyxColor.foreground)
                .accessibilityAddTraits(.isHeader)
            HStack {
                // Once the reading is saved the way out is her history, not a button that reads
                // as undoing the save.
                if saveState != .saved {
                    Button(PhScanCopy.cancel) { onExit(.cancelled) }
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
        case .result(.reading(let value, let metadata)):
            ScanResultView(
                value: value,
                isSimulated: services.isSimulated,
                // A scripted value must never reach a real account.
                saveBlocked: services.isSimulated && container.backend != nil,
                saveState: saveState,
                onSave: { save(value, metadata) },
                onScanAgain: begin,
                onViewHistory: { onExit(.saved) })
        case .result(.unreadable(let issues)):
            ScanUnreadableView(issues: issues, onScanAgain: begin, onManualEntry: { onExit(.manualEntry) })
        default:
            ScanCaptureContent(
                state: session.state,
                configuration: services.configuration,
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

    /// Open Camera, Scan Again, Try Again. A new attempt gets a new event stream and assessor.
    private func begin() {
        guard let source else { return }
        attempt += 1
        // The last result's save state must not hide Cancel on the scan that follows it.
        saveState = .unsaved
        session.handle(.begin(source.access))
    }

    /// The value and metadata come straight from the resolver's reading; nothing is recomputed.
    private func save(_ value: Double, _ metadata: PhScanMetadata) {
        let saved = ph.create(PhReading(
            id: readingID, phValue: value, recordedAt: capturedAt,
            measurementType: .vaginal, source: .cameraScan, scan: metadata))
        saveState = saved ? .saved : .refused
    }

    /// Speaks the guidance line when VoiceOver is on. Asked on every event, so a line the
    /// throttle held back is spoken once its interval has passed.
    private func announceGuidance() {
        guard UIAccessibility.isVoiceOverRunning else { return }
        let text = PhScanCopy.guidance(for: session.state)
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

/// Stateless: draws one state of a scan flow. Exists so every state has a preview. Generic over
/// what a scan resolves to, so every strip type shares one camera screen.
struct ScanCaptureContent<Resolution: Hashable & Sendable>: View {
    let state: ScanFlowState<Resolution>
    /// The state's own line, in the wording of the strip being scanned.
    let guidance: String
    /// Width over height of the strip as laid for scanning: at or below 1 the guide stands tall,
    /// above 1 it lies across the frame.
    let expectedAspectRatio: Double
    let preview: AnyView
    let isObscured: Bool
    let onManualEntry: () -> Void
    let onOpenSettings: () -> Void
    let onTryAgain: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(state: ScanFlowState<Resolution>, guidance: String, expectedAspectRatio: Double, preview: AnyView,
         isObscured: Bool, onManualEntry: @escaping () -> Void, onOpenSettings: @escaping () -> Void,
         onTryAgain: @escaping () -> Void) {
        self.state = state
        self.guidance = guidance
        self.expectedAspectRatio = expectedAspectRatio
        self.preview = preview
        self.isObscured = isObscured
        self.onManualEntry = onManualEntry
        self.onOpenSettings = onOpenSettings
        self.onTryAgain = onTryAgain
    }

    var body: some View {
        Group {
            switch state {
            case .idle, .requestingPermission, .preparingCamera:
                waiting(identifier: "scan.capture.guidance")
            case .searching, .stripDetected, .qualityIssue, .ready, .capturing:
                camera
            case .analysing:
                waiting(identifier: "scan.analysing")
            case .interrupted:
                notice { heading(identifier: "scan.paused") }
            case .permissionDenied:
                notice {
                    heading(identifier: "scan.permissionDenied")
                    Text(PhScanCopy.permissionDeniedBody)
                        .font(.gxBody)
                        .foregroundStyle(GenesyxColor.mutedForeground)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    GxPrimaryButton(title: PhScanCopy.openSettings, action: onOpenSettings)
                        .accessibilityIdentifier("scan.openSettings")
                    manualEntryButton
                }
            case .cameraUnavailable:
                notice {
                    heading(identifier: "scan.cameraUnavailable")
                    GxPrimaryButton(title: PhScanCopy.tryAgain, action: onTryAgain)
                        .accessibilityIdentifier("scan.tryAgain")
                    manualEntryButton
                }
            case .result:
                EmptyView()   // the parent draws results
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: state)
    }

    private var camera: some View {
        VStack(spacing: 0) {
            ZStack {
                if isObscured { GenesyxColor.background } else { preview }
                guide
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // Guidance sits on an opaque panel, never over live video.
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .accessibilityHidden(true)
                    Text(guidance)
                        .font(.gxCardHeading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)   // shrink before truncating
                        .accessibilityIdentifier("scan.capture.guidance")
                }
                .foregroundStyle(GenesyxColor.foreground)
                // A fixed slot, so the preview does not jump when the spinner comes and goes.
                ZStack {
                    if isHolding {
                        ProgressView()
                            .tint(GenesyxColor.primary)
                            .accessibilityLabel(guidance)
                            .accessibilityIdentifier("scan.capture.progress")
                    }
                }
                .frame(height: 24)
                manualEntryButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(GenesyxColor.card)
        }
    }

    /// Where to hold the strip. Decorative: the line of text below says the same thing. The
    /// outline goes from dashed to solid and its symbol changes, so nothing rests on colour.
    @ViewBuilder private var guide: some View {
        if expectedAspectRatio > 1 {
            // A strip laid across the frame: most of the width, and never too thin to see.
            GeometryReader { proxy in
                let width = proxy.size.width * 0.86
                outline
                    .frame(width: width, height: max(width / CGFloat(expectedAspectRatio), 28))
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .accessibilityHidden(true)
        } else {
            outline
                .aspectRatio(CGFloat(expectedAspectRatio), contentMode: .fit)
                .padding(.top, 44)
                .padding(.bottom, 16)
                .accessibilityHidden(true)
        }
    }

    private var outline: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(guideColour, style: StrokeStyle(lineWidth: 3, dash: isHolding ? [] : [10, 6]))
            .overlay(alignment: .top) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(guideColour)
                    .offset(y: -30)
            }
    }

    private var isHolding: Bool { state == .ready || state == .capturing }

    private var guideColour: Color {
        if isHolding { return GenesyxColor.phHealthy }
        if case .qualityIssue = state { return GenesyxColor.phElevated }
        return .white
    }

    private var symbol: String {
        switch state {
        case .stripDetected: return "viewfinder.circle"
        case .qualityIssue: return "exclamationmark.triangle"
        case .ready: return "checkmark.circle.fill"
        case .capturing: return "camera"
        default: return "viewfinder"
        }
    }

    private func waiting(identifier: String) -> some View {
        notice {
            ProgressView()
                .tint(GenesyxColor.primary)
                .accessibilityHidden(true)
            heading(identifier: identifier)
        }
    }

    private func heading(identifier: String) -> some View {
        Text(guidance)
            .font(.gxCardHeading)
            .foregroundStyle(GenesyxColor.foreground)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(identifier)
    }

    private var manualEntryButton: some View {
        GxGhostButton(title: PhScanCopy.enterManually, action: onManualEntry)
            .accessibilityIdentifier("scan.enterManually")
    }

    private func notice<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 16) { content() }
            .padding(24)
    }
}

extension ScanCaptureContent where Resolution == PhScanResolution {
    /// The pH flow's initialiser, unchanged for its callers.
    init(state: ScannerState, configuration: PhStripConfiguration, preview: AnyView,
         isObscured: Bool, onManualEntry: @escaping () -> Void, onOpenSettings: @escaping () -> Void,
         onTryAgain: @escaping () -> Void) {
        self.init(state: state, guidance: PhScanCopy.guidance(for: state),
                  expectedAspectRatio: configuration.expectedAspectRatio, preview: preview,
                  isObscured: isObscured, onManualEntry: onManualEntry, onOpenSettings: onOpenSettings,
                  onTryAgain: onTryAgain)
    }
}
