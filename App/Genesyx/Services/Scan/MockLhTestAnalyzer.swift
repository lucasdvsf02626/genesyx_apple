#if DEBUG
import CoreGraphics
import Foundation
import GenesyxCore

/// A scripted outcome for the simulated LH scan. Never looks at pixels and never decides what a
/// signal means: it only produces signals, and `LhScanResolver` judges them.
enum MockLhScenario: Hashable, Sendable {
    case low                              // clear control line, weak test line
    case faintTestLine                    // clear control line, test line barely there
    case rising                           // ratio between the rising and positive thresholds
    case positive                         // ratio above the positive threshold
    case invalidNoControl                 // neither line
    case invalidTestLineOnly              // strong test line, no control line
    case lowConfidence                    // the `low` signals with confidence below the minimum
    case signalOutOfRange                 // a test signal of 1.4
    case unreadable(ScanQualityIssue)     // analyser reports unreadable with this issue

    init?(launchValue: String) {
        switch launchValue {
        case "low": self = .low
        case "faintTestLine": self = .faintTestLine
        case "rising": self = .rising
        case "positive": self = .positive
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

    /// `-uiTestLhScenario <value>` on the launch command line.
    static var fromLaunchArguments: MockLhScenario? {
        UserDefaults.standard.string(forKey: "uiTestLhScenario").flatMap(MockLhScenario.init(launchValue:))
    }
}

struct MockLhTestAnalyzer: LhTestAnalyzing {
    let scenario: MockLhScenario
    let delay: TimeInterval

    init(scenario: MockLhScenario, delay: TimeInterval = 0.6) {
        self.scenario = scenario
        self.delay = delay
    }

    func analyse(_ image: CGImage, configuration: LhStripConfiguration) async -> LhAnalysisOutcome {
        if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }

        // Signals come from the configuration it is given, so a new strip's thresholds change
        // nothing about what a scenario means. Nothing is clamped: bad output must stay bad.
        let c = (configuration.minimumControlSignal + 1) / 2
        let floor = min(configuration.positiveThreshold, configuration.risingThreshold)
        func result(test: Double, control: Double, confidence: Double = 0.95) -> LhAnalysisOutcome {
            .result(LhAnalysisResult(
                testSignal: test,
                controlSignal: control,
                confidence: confidence,
                configurationID: configuration.id,
                configurationVersion: configuration.version
            ))
        }
        switch scenario {
        case .low: return result(test: c * floor * 0.2, control: c)
        case .faintTestLine: return result(test: c * floor * 0.02, control: c)
        case .rising: return result(test: c * (configuration.risingThreshold + configuration.positiveThreshold) / 2, control: c)
        case .positive: return result(test: c * configuration.positiveThreshold * 1.1, control: c)
        case .invalidNoControl: return result(test: 0, control: configuration.minimumControlSignal * 0.25)
        case .invalidTestLineOnly: return result(test: 0.8, control: 0)
        case .lowConfidence: return result(test: c * floor * 0.2, control: c, confidence: configuration.minimumConfidence - 0.1)
        case .signalOutOfRange: return result(test: 1.4, control: c)
        case .unreadable(let issue): return .unreadable([issue])
        }
    }
}
#endif
