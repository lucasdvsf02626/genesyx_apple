import CoreGraphics
import GenesyxCore

/// What the scan flow is built from. Phase 1 has only a simulated set, and only in DEBUG.
struct ScanServices {
    let configuration: PhStripConfiguration
    /// True when results are scripted, not measured. The UI labels them and refuses to save them
    /// to a real account.
    let isSimulated: Bool
    let makeFrameSource: @MainActor () -> any ScanFrameSource
    /// A fresh assessor per scan attempt (the mock keeps a frame counter).
    let makeAssessor: @Sendable () -> any ScanFrameAssessing
    let analyser: any PhTestAnalyzing

    /// Nil outside DEBUG: there is no real analyser yet, so a Release build has nothing to scan with.
    static var current: ScanServices? {
        #if DEBUG
        return .debug(scenario: MockScanScenario.fromLaunchArguments ?? .reading(4.4))
        #else
        return nil
        #endif
    }

    /// Runs the job a `PhScanSession` state is waiting on and reports back through `emit`.
    /// Checks `Task.isCancelled` after every await and emits nothing once cancelled.
    @MainActor
    func perform(_ work: ScanWork, source: any ScanFrameSource, testImage: CGImage? = nil,
                 emit: @MainActor (ScanEvent) -> Void) async {
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
