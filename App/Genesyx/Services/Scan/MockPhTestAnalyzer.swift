#if DEBUG
import CoreGraphics
import CoreVideo
import Foundation
import GenesyxCore
import UIKit

/// A scripted outcome for the simulated scan. Never looks at pixels.
enum MockScanScenario: Hashable, Sendable {
    case reading(Double)                 // confident result at this value
    case slowReading                     // reading 4.4 after a 3 second analysis
    case awayReading                     // reading 4.4 the moment the app stops being active; 3 seconds after that
    case lowConfidence                   // result 4.4 with confidence below the configuration minimum
    case outOfRange                      // confident result at 7.6
    case unreadable(ScanQualityIssue)    // analyser reports unreadable with this issue
    case liveIssue(ScanQualityIssue)     // frames report this issue for ever; never ready
    case permissionDenied                // fake source only
    case cameraUnavailable               // fake source only

    init?(launchValue: String) {
        switch launchValue {
        case "slowReading": self = .slowReading
        case "awayReading": self = .awayReading
        case "lowConfidence": self = .lowConfidence
        case "outOfRange": self = .outOfRange
        case "permissionDenied": self = .permissionDenied
        case "cameraUnavailable": self = .cameraUnavailable
        default:
            if let value = launchValue.dropping(prefix: "reading-").flatMap({ Double($0) }) {
                self = .reading(value)
            } else if let issue = launchValue.dropping(prefix: "unreadable-").flatMap({ ScanQualityIssue(rawValue: $0) }) {
                self = .unreadable(issue)
            } else if let issue = launchValue.dropping(prefix: "issue-").flatMap({ ScanQualityIssue(rawValue: $0) }) {
                self = .liveIssue(issue)
            } else {
                return nil
            }
        }
    }

    /// `-uiTestScanScenario <value>` on the launch command line.
    static var fromLaunchArguments: MockScanScenario? {
        UserDefaults.standard.string(forKey: "uiTestScanScenario").flatMap(MockScanScenario.init(launchValue:))
    }

    /// Whether the first `awayReading` analysis is over.
    private static var firstAwayAnalysisOver = false

    /// The `awayReading` analysis. The first is over the moment the app stops being active and
    /// never sooner, so a test that leaves mid-analysis is not racing a timer. Any after it
    /// takes the slow script's three seconds, so the scan that restarts on her return is not
    /// over before the test has looked.
    @MainActor
    static func awayAnalysis() async {
        guard !firstAwayAnalysisOver else {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            return
        }
        firstAwayAnalysisOver = true
        while UIApplication.shared.applicationState == .active, !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private extension String {
    func dropping(prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}

struct MockPhTestAnalyzer: PhTestAnalyzing {
    let scenario: MockScanScenario

    func analyse(_ image: CGImage, configuration: PhStripConfiguration) async -> PhAnalysisOutcome {
        if scenario == .awayReading {
            await MockScanScenario.awayAnalysis()
        } else {
            try? await Task.sleep(nanoseconds: scenario == .slowReading ? 3_000_000_000 : 600_000_000)
        }
        func result(_ ph: Double, _ confidence: Double) -> PhAnalysisOutcome {
            .result(PhAnalysisResult(
                estimatedPH: ph,
                confidence: confidence,
                configurationID: configuration.id,
                configurationVersion: configuration.version
            ))
        }
        switch scenario {
        case .reading(let value): return result(value, 0.95)
        case .slowReading, .awayReading: return result(4.4, 0.95)
        case .lowConfidence: return result(4.4, configuration.minimumConfidence - 0.1)
        case .outOfRange: return result(7.6, 0.95)
        case .unreadable(let issue): return .unreadable([issue])
        case .liveIssue, .permissionDenied, .cameraUnavailable: return .unreadable([])
        }
    }
}

/// Scripted live guidance: a few frames of searching, a strip, then ready. Never reads the buffer.
final class MockScanFrameAssessor: ScanFrameAssessing, @unchecked Sendable {
    private let scenario: MockScanScenario
    private let lock = NSLock()
    private var frames = 0

    init(scenario: MockScanScenario) {
        self.scenario = scenario
    }

    func assess(_ frame: CVPixelBuffer, configuration: any ScanStripGeometry) -> FrameAssessment {
        let count = lock.withLock { () -> Int in
            frames += 1
            return frames
        }
        if case .liveIssue(let issue) = scenario { return .issue(issue) }
        switch count {
        case ...4: return .searching
        case 5, 6: return .stripDetected
        default: return .ready
        }
    }
}

extension ScanServices {
    static func debug(scenario: MockScanScenario) -> ScanServices {
        ScanServices(
            configuration: .developmentPlaceholder,
            isSimulated: true,
            makeFrameSource: {
                #if targetEnvironment(simulator)
                return FakeScanFrameSource(scenario: scenario)
                #else
                if MockScanScenario.fromLaunchArguments != nil { return FakeScanFrameSource(scenario: scenario) }
                return CameraSessionManager()
                #endif
            },
            makeAssessor: { MockScanFrameAssessor(scenario: scenario) },
            analyser: MockPhTestAnalyzer(scenario: scenario)
        )
    }
}
#endif
