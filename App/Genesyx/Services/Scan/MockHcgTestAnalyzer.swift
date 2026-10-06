#if DEBUG
import CoreGraphics
import Foundation
import GenesyxCore

/// A scripted outcome for the simulated pregnancy test scan. Never looks at pixels and never
/// decides what a signal means: it only produces signals, and `HcgScanResolver` judges them.
enum MockHcgScenario: Hashable, Sendable {
    case testLineDetected                 // clear control line, clear test line
    case noTestLineDetected               // clear control line, test signal below the band
    case faintLine                        // clear control line, test signal inside the indeterminate band
    case invalidNoControl                 // neither line
    case invalidTestLineOnly              // strong test line, no control line
    case lowConfidence                    // the `testLineDetected` signals with confidence below the minimum
    case signalOutOfRange                 // a test signal of 1.4
    case unreadable(ScanQualityIssue)     // analyser reports unreadable with this issue

    init?(launchValue: String) {
        switch launchValue {
        case "detected": self = .testLineDetected
        case "notDetected": self = .noTestLineDetected
        case "faintLine": self = .faintLine
        case "invalidNoControl": self = .invalidNoControl
        case "invalidTestLineOnly": self = .invalidTestLineOnly
        case "lowConfidence": self = .lowConfidence
        case "signalOutOfRange": self = .signalOutOfRange
        default:
            let prefix = "unreadable-"
            guard launchValue.hasPrefix(prefix),
                  let issue = ScanQualityIssue(rawValue: String(launchValue.dropFirst(prefix.count))) else { return nil }
            self = .unreadable(issue)
        }
    }

    /// `-uiTestHcgScenario <value>` on the launch command line.
    static var fromLaunchArguments: MockHcgScenario? {
        UserDefaults.standard.string(forKey: "uiTestHcgScenario").flatMap(MockHcgScenario.init(launchValue:))
    }
}

struct MockHcgTestAnalyzer: HcgTestAnalyzing {
    let scenario: MockHcgScenario
    let delay: TimeInterval
    /// The camera's `awayReading` script, in place of `delay`.
    let awayScript: Bool

    init(scenario: MockHcgScenario, delay: TimeInterval = 0.6, awayScript: Bool = false) {
        self.scenario = scenario
        self.delay = delay
        self.awayScript = awayScript
    }

    func analyse(_ image: CGImage, configuration: HcgStripConfiguration) async -> HcgAnalysisOutcome {
        if awayScript {
            await MockScanScenario.awayAnalysis()
        } else if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        // Signals come from the configuration it is given, so a new strip's thresholds change
        // nothing about what a scenario means. Nothing is clamped: bad output must stay bad.
        let c = (configuration.minimumControlSignal + 1) / 2
        let lower = configuration.indeterminateLowerBound
        let detected = (configuration.detectionThreshold + 1) / 2
        func result(test: Double, control: Double, confidence: Double = 0.95) -> HcgAnalysisOutcome {
            .result(HcgAnalysisResult(
                testSignal: test,
                controlSignal: control,
                confidence: confidence,
                configurationID: configuration.id,
                configurationVersion: configuration.version
            ))
        }
        switch scenario {
        case .testLineDetected: return result(test: detected, control: c)
        case .noTestLineDetected: return result(test: lower * 0.2, control: c)
        case .faintLine: return result(test: (lower + configuration.detectionThreshold) / 2, control: c)
        case .invalidNoControl: return result(test: 0, control: configuration.minimumControlSignal * 0.25)
        case .invalidTestLineOnly: return result(test: detected, control: 0)
        case .lowConfidence: return result(test: detected, control: c, confidence: configuration.minimumConfidence - 0.1)
        case .signalOutOfRange: return result(test: 1.4, control: c)
        case .unreadable(let issue): return .unreadable([issue])
        }
    }
}
#endif
