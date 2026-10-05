import CoreGraphics
import GenesyxCore

/// What the LH scan flow is built from: `ScanServices` for the ovulation test strip. The camera
/// and the live-frame assessor are the pH scan's; only the analyser and the configuration differ.
struct LhScanServices {
    let configuration: LhStripConfiguration
    /// True when results are scripted, not measured. The UI labels them and refuses to save them
    /// to a real account.
    let isSimulated: Bool
    let makeFrameSource: @MainActor () -> any ScanFrameSource
    /// A fresh assessor per scan attempt (the mock keeps a frame counter).
    let makeAssessor: @Sendable () -> any ScanFrameAssessing
    let analyser: any LhTestAnalyzing

    /// Nil outside DEBUG: there is no real analyser yet, so a Release build has nothing to scan with.
    static var current: LhScanServices? {
        #if DEBUG
        return .debug(scenario: MockLhScenario.fromLaunchArguments ?? .low,
                      frames: MockScanScenario.fromLaunchArguments ?? .reading(4.4))
        #else
        return nil
        #endif
    }

    /// Runs the job an `LhScanSession` state is waiting on and reports back through `emit`.
    /// Checks `Task.isCancelled` after every await and emits nothing once cancelled.
    @MainActor
    func perform(_ work: ScanWork, source: any ScanFrameSource, testImage: CGImage? = nil,
                 emit: @MainActor (LhScanEvent) -> Void) async {
        switch work {
        case .requestPermission:
            let granted = await source.requestAccess()
            guard !Task.isCancelled else { return }
            emit(.permissionResolved(granted: granted))
        case .startCamera:
            await source.start()
        case .captureAndAnalyse:
            let image: CGImage
            if let testImage {
                image = testImage
            } else {
                do { image = try await source.captureStill() } catch {
                    guard !Task.isCancelled else { return }
                    emit(.captureFailed)
                    return
                }
            }
            guard !Task.isCancelled else { return }
            emit(.stillCaptured)
            let outcome = await analyser.analyse(image, configuration: configuration)
            guard !Task.isCancelled else { return }
            emit(.analysed(outcome))
        }
    }
}

#if DEBUG
extension LhScanServices {
    /// `scenario` scripts what the strip shows; `frames` scripts the camera (live issues,
    /// permission, no camera), exactly as it does for the pH scan. `delay` nil is the analyser's
    /// own, or three seconds on the pH scan's slow script.
    static func debug(scenario: MockLhScenario, frames: MockScanScenario, delay: Double? = nil) -> LhScanServices {
        LhScanServices(
            configuration: .developmentPlaceholder,
            isSimulated: true,
            makeFrameSource: {
                #if targetEnvironment(simulator)
                return FakeScanFrameSource(scenario: frames)
                #else
                if MockLhScenario.fromLaunchArguments != nil || MockScanScenario.fromLaunchArguments != nil {
                    return FakeScanFrameSource(scenario: frames)
                }
                return CameraSessionManager()
                #endif
            },
            makeAssessor: { MockScanFrameAssessor(scenario: frames) },
            analyser: MockLhTestAnalyzer(scenario: scenario, delay: delay ?? (frames == .slowReading ? 3 : 0.6))
        )
    }
}
#endif
