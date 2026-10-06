import XCTest
@testable import Genesyx
import GenesyxCore

final class HcgAnalyserTests: XCTestCase {

    private let placeholder = HcgStripConfiguration.developmentPlaceholder

    /// Other values than the placeholder's.
    private let otherConfig = HcgStripConfiguration(
        id: "test_hcg_other", version: "9.9.9",
        expectedAspectRatio: 10,
        testLineRegion: NormalisedRect(x: 0.4, y: 0.1, width: 0.05, height: 0.8),
        controlLineRegion: NormalisedRect(x: 0.55, y: 0.1, width: 0.05, height: 0.8),
        minimumControlSignal: 0.3,
        indeterminateLowerBound: 0.2,
        detectionThreshold: 0.5,
        minimumConfidence: 0.9,
        developmentTimeSeconds: 0,
        maximumReadTimeSeconds: nil,
        stableDetectionMilliseconds: 300
    )

    private func testImage() -> CGImage {
        CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
    }

    private func outcome(_ scenario: MockHcgScenario, _ config: HcgStripConfiguration) async -> HcgAnalysisOutcome {
        await MockHcgTestAnalyzer(scenario: scenario, delay: 0).analyse(testImage(), configuration: config)
    }

    private func resolve(_ scenario: MockHcgScenario, _ config: HcgStripConfiguration) async -> HcgScanResolution {
        HcgScanResolver.resolve(await outcome(scenario, config), configuration: config)
    }

    private func classification(_ resolution: HcgScanResolution) -> HcgClassification? {
        if case .reading(let classification, _) = resolution { return classification }
        return nil
    }

    func testEveryScenarioMeansTheSameOnBothConfigurations() async {
        XCTAssertTrue(otherConfig.isUsable)
        for config in [placeholder, otherConfig] {
            let detected = await resolve(.testLineDetected, config)
            XCTAssertEqual(classification(detected), .testLineDetected, config.id)
            let notDetected = await resolve(.noTestLineDetected, config)
            XCTAssertEqual(classification(notDetected), .noTestLineDetected, config.id)
            let faint = await resolve(.faintLine, config)
            XCTAssertEqual(faint, .unreadable(.indeterminateTestLine), "a faint line is never a result")
            let noControl = await resolve(.invalidNoControl, config)
            XCTAssertEqual(noControl, .invalid, config.id)
            let testOnly = await resolve(.invalidTestLineOnly, config)
            XCTAssertEqual(testOnly, .invalid, "a test line without a control line is invalid, never detected")
            let lowConfidence = await resolve(.lowConfidence, config)
            XCTAssertEqual(lowConfidence, .unreadable(.quality([])), config.id)
            let outOfRange = await resolve(.signalOutOfRange, config)
            XCTAssertEqual(outOfRange, .unreadable(.quality([])), "a signal above 1 is never clamped into a result")
            let glare = await resolve(.unreadable(.glare), config)
            XCTAssertEqual(glare, .unreadable(.quality([.glare])), config.id)
        }
    }

    func testResultCarriesTheGivenConfiguration() async {
        guard case .result(let result) = await outcome(.testLineDetected, otherConfig) else {
            return XCTFail("testLineDetected scenario should return a result")
        }
        XCTAssertEqual(result.configurationID, "test_hcg_other")
        XCTAssertEqual(result.configurationVersion, "9.9.9")
        XCTAssertTrue(result.qualityFlags.isEmpty)

        guard case .reading(_, let provenance) = await resolve(.testLineDetected, otherConfig) else {
            return XCTFail("testLineDetected scenario should resolve to a reading")
        }
        XCTAssertEqual(provenance.configurationID, "test_hcg_other")
        XCTAssertEqual(provenance.configurationVersion, "9.9.9")
    }

    func testLaunchValuesParse() {
        let plain: [(String, MockHcgScenario)] = [
            ("detected", .testLineDetected), ("notDetected", .noTestLineDetected), ("faintLine", .faintLine),
            ("invalidNoControl", .invalidNoControl), ("invalidTestLineOnly", .invalidTestLineOnly),
            ("lowConfidence", .lowConfidence), ("signalOutOfRange", .signalOutOfRange)
        ]
        for (value, scenario) in plain {
            XCTAssertEqual(MockHcgScenario(launchValue: value), scenario, value)
        }
        for issue in ScanQualityIssue.allCases {
            XCTAssertEqual(MockHcgScenario(launchValue: "unreadable-\(issue.rawValue)"), .unreadable(issue))
        }
        XCTAssertNil(MockHcgScenario(launchValue: "nonsense"))
        XCTAssertNil(MockHcgScenario(launchValue: "unreadable-nonsense"))
    }
}
