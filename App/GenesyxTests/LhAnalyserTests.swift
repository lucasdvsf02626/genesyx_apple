import XCTest
@testable import Genesyx
import GenesyxCore

final class LhAnalyserTests: XCTestCase {

    private let placeholder = LhStripConfiguration.developmentPlaceholder

    /// Other values than the placeholder's, with rising on.
    private let risingConfig = LhStripConfiguration(
        id: "test_lh_rising", version: "9.9.9",
        expectedAspectRatio: 10,
        testLineRegion: NormalisedRect(x: 0.4, y: 0.1, width: 0.05, height: 0.8),
        controlLineRegion: NormalisedRect(x: 0.55, y: 0.1, width: 0.05, height: 0.8),
        minimumControlSignal: 0.3,
        positiveThreshold: 0.8,
        risingThreshold: 0.4,
        risingEnabled: true,
        minimumConfidence: 0.8,
        developmentTimeSeconds: 0,
        maximumReadTimeSeconds: nil,
        stableDetectionMilliseconds: 300
    )

    private func testImage() -> CGImage {
        CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
    }

    private func outcome(_ scenario: MockLhScenario, _ config: LhStripConfiguration) async -> LhAnalysisOutcome {
        await MockLhTestAnalyzer(scenario: scenario, delay: 0).analyse(testImage(), configuration: config)
    }

    private func resolve(_ scenario: MockLhScenario, _ config: LhStripConfiguration) async -> LhScanResolution {
        LhScanResolver.resolve(await outcome(scenario, config), configuration: config)
    }

    private func classification(_ resolution: LhScanResolution) -> LhClassification? {
        if case .reading(let classification, _) = resolution { return classification }
        return nil
    }

    func testPlaceholderScenarios() async {
        let low = await resolve(.low, placeholder)
        XCTAssertEqual(classification(low), .low)
        let faint = await resolve(.faintTestLine, placeholder)
        XCTAssertEqual(classification(faint), .low)
        let positive = await resolve(.positive, placeholder)
        XCTAssertEqual(classification(positive), .positive)
        let rising = await resolve(.rising, placeholder)
        XCTAssertEqual(classification(rising), .low, "rising is disabled on the placeholder")
        let noControl = await resolve(.invalidNoControl, placeholder)
        XCTAssertEqual(noControl, .invalid)
        let testOnly = await resolve(.invalidTestLineOnly, placeholder)
        XCTAssertEqual(testOnly, .invalid)
        let lowConfidence = await resolve(.lowConfidence, placeholder)
        XCTAssertEqual(lowConfidence, .unreadable([]))
        let outOfRange = await resolve(.signalOutOfRange, placeholder)
        XCTAssertEqual(outOfRange, .unreadable([]))
        let glare = await resolve(.unreadable(.glare), placeholder)
        XCTAssertEqual(glare, .unreadable([.glare]))
    }

    func testRisingEnabledConfiguration() async {
        let rising = await resolve(.rising, risingConfig)
        XCTAssertEqual(classification(rising), .rising)
        let positive = await resolve(.positive, risingConfig)
        XCTAssertEqual(classification(positive), .positive)
        let low = await resolve(.low, risingConfig)
        XCTAssertEqual(classification(low), .low)
    }

    func testResultCarriesTheGivenConfiguration() async {
        guard case .result(let result) = await outcome(.positive, risingConfig) else {
            return XCTFail("positive scenario should return a result")
        }
        XCTAssertEqual(result.configurationID, "test_lh_rising")
        XCTAssertEqual(result.configurationVersion, "9.9.9")
        XCTAssertTrue(result.qualityFlags.isEmpty)
    }

    func testLaunchValuesParse() {
        let plain: [(String, MockLhScenario)] = [
            ("low", .low), ("faintTestLine", .faintTestLine), ("rising", .rising), ("positive", .positive),
            ("invalidNoControl", .invalidNoControl), ("invalidTestLineOnly", .invalidTestLineOnly),
            ("lowConfidence", .lowConfidence), ("signalOutOfRange", .signalOutOfRange)
        ]
        for (value, scenario) in plain {
            XCTAssertEqual(MockLhScenario(launchValue: value), scenario, value)
        }
        for issue in ScanQualityIssue.allCases {
            XCTAssertEqual(MockLhScenario(launchValue: "unreadable-\(issue.rawValue)"), .unreadable(issue))
        }
        XCTAssertNil(MockLhScenario(launchValue: "nonsense"))
        XCTAssertNil(MockLhScenario(launchValue: "unreadable-nonsense"))
    }

    func testTestLineWithoutControlIsNeverPositive() async {
        for config in [placeholder, risingConfig] {
            let resolution = await resolve(.invalidTestLineOnly, config)
            XCTAssertNotEqual(classification(resolution), .positive, "a missing control line is invalid, never positive")
            XCTAssertEqual(resolution, .invalid)
        }
    }
}
