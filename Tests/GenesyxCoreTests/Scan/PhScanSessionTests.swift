import XCTest
@testable import GenesyxCore

/// The scan flow's transition table, one test per row, plus the stability window, the work each
/// state waits on and the announcement throttle. Every row is checked from every state, so an
/// event that is not listed for a state is proved to change nothing.
final class PhScanSessionTests: XCTestCase {

    private let configuration = PhStripConfiguration.developmentPlaceholder

    private var goodOutcome: PhAnalysisOutcome {
        .result(PhAnalysisResult(estimatedPH: 4.4, confidence: 0.95, configurationID: configuration.id,
                                 configurationVersion: configuration.version))
    }

    private var reading: ScannerState {
        .result(.reading(value: 4.4, metadata: PhScanMetadata(scannerVersion: PhScanResolver.scannerVersion,
                                                              configurationID: configuration.id,
                                                              configurationVersion: configuration.version,
                                                              confidence: 0.95)))
    }

    private let unreadable = ScannerState.result(.unreadable([]))
    private let restartable: [ScannerState] = [.idle, .permissionDenied, .cameraUnavailable,
                                               .result(.unreadable([]))]
    private let live: [ScannerState] = [.searching, .stripDetected, .qualityIssue(.glare), .ready]
    private let interrupted: [ScannerState] = [.interrupted(.other), .interrupted(.backgrounded)]

    /// Every state the flow can be in, one representative per case with an associated value
    /// (two for results and interruptions, whose values change what is legal).
    private var everyState: [ScannerState] {
        [.idle, .requestingPermission, .permissionDenied, .cameraUnavailable, .preparingCamera,
         .capturing, .analysing, unreadable, reading] + live + interrupted
    }

    /// A session driven to `state` by legal events only, the way the app would get there.
    private func session(in state: ScannerState, line: UInt = #line) -> PhScanSession {
        var session = PhScanSession(configuration: configuration)
        let events: [ScanEvent]
        let toSearching: [ScanEvent] = [.begin(.authorised), .camera(.running)]
        switch state {
        case .idle: events = []
        case .requestingPermission: events = [.begin(.notDetermined)]
        case .permissionDenied: events = [.begin(.denied)]
        case .cameraUnavailable: events = [.begin(.restricted)]
        case .preparingCamera: events = [.begin(.authorised)]
        case .searching: events = toSearching
        case .stripDetected: events = toSearching + [.frame(.stripDetected, at: 0)]
        case .qualityIssue(let issue): events = toSearching + [.frame(.issue(issue), at: 0)]
        case .ready: events = toSearching + [.frame(.ready, at: 0)]
        case .capturing: events = toSearching + [.captureRequested]
        case .analysing: events = toSearching + [.captureRequested, .stillCaptured]
        case .result(.unreadable(let issues)):
            events = toSearching + [.captureRequested, .stillCaptured, .analysed(.unreadable(issues))]
        case .result(.reading):
            events = toSearching + [.captureRequested, .stillCaptured, .analysed(goodOutcome)]
        case .interrupted(let reason): events = [.begin(.authorised), .camera(.interrupted(reason))]
        }
        events.forEach { session.handle($0) }
        XCTAssertEqual(session.state, state, "could not reach the starting state", line: line)
        return session
    }

    /// `event` moves each state in `from` to `expected` and leaves every other state alone.
    private func assertRow(_ event: ScanEvent, from: [ScannerState], to expected: ScannerState, line: UInt = #line) {
        for start in everyState {
            var session = session(in: start, line: line)
            session.handle(event)
            XCTAssertEqual(session.state, from.contains(start) ? expected : start,
                           "\(event) from \(start)", line: line)
        }
    }

    // MARK: - begin

    func testANewSessionIsIdle() {
        XCTAssertEqual(PhScanSession(configuration: configuration).state, .idle)
    }

    func testBeginAuthorisedPreparesTheCamera() {
        assertRow(.begin(.authorised), from: restartable + [reading], to: .preparingCamera)
    }

    func testBeginNotDeterminedAsksForPermission() {
        assertRow(.begin(.notDetermined), from: restartable + [reading], to: .requestingPermission)
    }

    func testBeginDeniedIsPermissionDenied() {
        assertRow(.begin(.denied), from: restartable + [reading], to: .permissionDenied)
    }

    func testBeginRestrictedIsCameraUnavailable() {
        assertRow(.begin(.restricted), from: restartable + [reading], to: .cameraUnavailable)
    }

    // MARK: - Permission

    func testPermissionGrantedPreparesTheCamera() {
        assertRow(.permissionResolved(granted: true), from: [.requestingPermission], to: .preparingCamera)
    }

    func testPermissionRefusedIsPermissionDenied() {
        assertRow(.permissionResolved(granted: false), from: [.requestingPermission], to: .permissionDenied)
    }

    // MARK: - Camera status

    func testCameraRunningStartsSearching() {
        assertRow(.camera(.running), from: [.preparingCamera] + interrupted, to: .searching)
    }

    func testCameraUnavailableOrFailedIsCameraUnavailable() {
        let from = [.preparingCamera, .capturing] + live + interrupted
        assertRow(.camera(.unavailable), from: from, to: .cameraUnavailable)
        assertRow(.camera(.failed), from: from, to: .cameraUnavailable)
    }

    func testACameraInterruptionKeepsItsReason() {
        let from = [.preparingCamera, .capturing] + live
        assertRow(.camera(.interrupted(.inUseByAnotherApp)), from: from, to: .interrupted(.inUseByAnotherApp))
        assertRow(.camera(.interrupted(.systemPressure)), from: from, to: .interrupted(.systemPressure))
    }

    func testCameraIdleAndPreparingChangeNothing() {
        assertRow(.camera(.idle), from: [], to: .idle)
        assertRow(.camera(.preparing), from: [], to: .idle)
    }

    // MARK: - Frames

    func testASearchingFrameIsSearching() {
        assertRow(.frame(.searching, at: 0.1), from: live, to: .searching)
    }

    func testAStripDetectedFrameIsStripDetected() {
        assertRow(.frame(.stripDetected, at: 0.1), from: live, to: .stripDetected)
    }

    func testAnIssueFrameIsThatQualityIssue() {
        assertRow(.frame(.issue(.tooDark), at: 0.1), from: live, to: .qualityIssue(.tooDark))
    }

    func testAReadyFrameIsReadyUntilTheWindowHasElapsed() {
        assertRow(.frame(.ready, at: 0.1), from: live, to: .ready)
    }

    // MARK: - Capture and analysis

    func testCaptureRequestedCapturesFromAnyLiveState() {
        assertRow(.captureRequested, from: live, to: .capturing)
    }

    func testStillCapturedStartsAnalysing() {
        assertRow(.stillCaptured, from: [.capturing], to: .analysing)
    }

    func testCaptureFailedIsUnreadableForNoNamedReason() {
        assertRow(.captureFailed, from: [.capturing], to: unreadable)
    }

    func testAnalysedBecomesWhatTheResolverSays() {
        assertRow(.analysed(goodOutcome), from: [.analysing], to: reading)
        assertRow(.analysed(.unreadable([.glare])), from: [.analysing], to: .result(.unreadable([.glare])))
    }

    // MARK: - Leaving and returning to the foreground

    func testSuspendedPausesAnythingBeforeAResult() {
        assertRow(.suspended, from: [.preparingCamera, .capturing, .analysing] + live + interrupted,
                  to: .interrupted(.backgrounded))
    }

    func testResumedRestartsOnlyABackgroundedScan() {
        assertRow(.resumed, from: [.interrupted(.backgrounded)], to: .preparingCamera)
    }

    // MARK: - Unlisted pairs

    /// The four the flow depends on, named: a late answer from cancelled work, a frame that
    /// arrives after capture, a second tap, and a permission answer nobody asked for.
    func testEventsThatAreNotLegalInAStateAreIgnored() {
        var notAnalysing = session(in: .searching)
        notAnalysing.handle(.analysed(goodOutcome))
        XCTAssertEqual(notAnalysing.state, .searching)

        var analysing = session(in: .analysing)
        analysing.handle(.frame(.ready, at: 1))
        analysing.handle(.frame(.searching, at: 2))
        XCTAssertEqual(analysing.state, .analysing)

        var searching = session(in: .searching)
        searching.handle(.begin(.denied))
        XCTAssertEqual(searching.state, .searching)

        var idle = session(in: .idle)
        idle.handle(.permissionResolved(granted: true))
        XCTAssertEqual(idle.state, .idle)
    }

    // MARK: - Stability

    /// The placeholder's window is 450 ms.
    func testReadyMustBeHeldForTheWholeWindowBeforeCapture() {
        var session = session(in: .searching)

        session.handle(.frame(.ready, at: 0.0))
        XCTAssertEqual(session.state, .ready)
        session.handle(.frame(.ready, at: 0.449))
        XCTAssertEqual(session.state, .ready)
        session.handle(.frame(.ready, at: 0.45))
        XCTAssertEqual(session.state, .capturing)
    }

    func testANonReadyFrameRestartsTheWindow() {
        var session = session(in: .searching)

        session.handle(.frame(.ready, at: 0.0))
        session.handle(.frame(.issue(.moving), at: 0.25))
        session.handle(.frame(.ready, at: 0.5))
        XCTAssertEqual(session.state, .ready, "0.5 s after the first ready frame, but the run was broken")
        session.handle(.frame(.ready, at: 0.75))
        XCTAssertEqual(session.state, .ready)
        session.handle(.frame(.ready, at: 1.0))
        XCTAssertEqual(session.state, .capturing)
    }

    func testABackwardsTimestampRestartsTheWindow() {
        var session = session(in: .searching)

        session.handle(.frame(.ready, at: 10.0))
        session.handle(.frame(.ready, at: 4.0))
        XCTAssertEqual(session.state, .ready)
        session.handle(.frame(.ready, at: 4.25))
        XCTAssertEqual(session.state, .ready)
        session.handle(.frame(.ready, at: 4.5))
        XCTAssertEqual(session.state, .capturing)
    }

    /// The window belongs to one run of live frames: an interruption must not leave half of it behind.
    func testLeavingTheLiveStatesClearsTheWindow() {
        var session = session(in: .searching)

        session.handle(.frame(.ready, at: 0.0))
        session.handle(.camera(.interrupted(.other)))
        session.handle(.camera(.running))
        session.handle(.frame(.ready, at: 5.0))
        XCTAssertEqual(session.state, .ready)
    }

    // MARK: - Rule 1 through the session

    func testALowConfidenceOutcomeIsUnreadable() {
        var session = session(in: .analysing)
        session.handle(.analysed(.result(PhAnalysisResult(estimatedPH: 4.4,
                                                          confidence: configuration.minimumConfidence - 0.01,
                                                          configurationID: configuration.id,
                                                          configurationVersion: configuration.version))))
        XCTAssertEqual(session.state, unreadable)
    }

    func testAnOutOfRangeOutcomeIsNeverClamped() {
        for outside in [3.0, 7.6, 14.0] {
            var session = session(in: .analysing)
            session.handle(.analysed(.result(PhAnalysisResult(estimatedPH: outside, confidence: 0.99,
                                                              configurationID: configuration.id,
                                                              configurationVersion: configuration.version))))
            XCTAssertEqual(session.state, unreadable, "\(outside) must not come back as a reading")
        }
    }

    // MARK: - Work and camera

    func testWorkAndWantsCameraForEveryState() {
        let expected: [(ScannerState, ScanWork?, Bool)] = [
            (.idle, nil, false),
            (.requestingPermission, .requestPermission, false),
            (.permissionDenied, nil, false),
            (.cameraUnavailable, nil, false),
            (.preparingCamera, .startCamera, true),
            (.searching, nil, true),
            (.stripDetected, nil, true),
            (.qualityIssue(.glare), nil, true),
            (.ready, nil, true),
            (.capturing, .captureAndAnalyse, true),
            (.analysing, .captureAndAnalyse, true),
            (unreadable, nil, false),
            (reading, nil, false),
            (.interrupted(.other), nil, true),
            (.interrupted(.inUseByAnotherApp), nil, true),
            (.interrupted(.backgrounded), nil, false),
        ]
        XCTAssertGreaterThanOrEqual(expected.count, everyState.count)
        for (state, work, wantsCamera) in expected {
            let session = session(in: state)
            XCTAssertEqual(session.work, work, "\(state)")
            XCTAssertEqual(session.wantsCamera, wantsCamera, "\(state)")
        }
    }

    func testLiveStatesAreExactlyTheGuidanceOnes() {
        for state in everyState {
            XCTAssertEqual(state.isLiveGuidance, live.contains(state), "\(state)")
        }
    }

    // MARK: - Announcement throttle

    func testTheSameTextIsNeverAnnouncedTwiceInARow() {
        var throttle = ScanAnnouncementThrottle()

        XCTAssertTrue(throttle.shouldAnnounce("Hold steady", at: 0, urgent: false))
        XCTAssertFalse(throttle.shouldAnnounce("Hold steady", at: 10, urgent: false))
        XCTAssertFalse(throttle.shouldAnnounce("Hold steady", at: 20, urgent: true))
    }

    func testADifferentLineWaitsForTheInterval() {
        var throttle = ScanAnnouncementThrottle()

        XCTAssertTrue(throttle.shouldAnnounce("Move closer", at: 0, urgent: false))
        XCTAssertFalse(throttle.shouldAnnounce("Hold steady", at: 2.4, urgent: false))
        XCTAssertTrue(throttle.shouldAnnounce("Hold steady", at: 2.5, urgent: false),
                      "a suppressed line is spoken once the interval has passed")
        XCTAssertFalse(throttle.shouldAnnounce("Move closer", at: 4.9, urgent: false),
                       "the interval runs from the last line spoken, not the last one asked about")
        XCTAssertEqual(ScanAnnouncementThrottle.minimumInterval, 2.5)
    }

    func testAnUrgentLineIsNotHeldBack() {
        var throttle = ScanAnnouncementThrottle()

        XCTAssertTrue(throttle.shouldAnnounce("Hold steady", at: 0, urgent: false))
        XCTAssertTrue(throttle.shouldAnnounce("Analysing test…", at: 0.1, urgent: true))
        XCTAssertFalse(throttle.shouldAnnounce("Hold steady", at: 0.2, urgent: false))
    }
}
