import XCTest

extension XCTestCase {

    /// Asserts that the app's own card in the app switcher is one flat colour: the privacy cover,
    /// with no result, title, back button or tab bar showing through.
    func assertAppSwitcherCardIsFlat(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let spread = appSwitcherCardSpread(name, file: file, line: line) else { return }
        XCTAssertLessThan(spread, 8, "\(name): something shows through the privacy cover in the app switcher", file: file, line: line)
    }

    /// Opens the app switcher on the app in front and measures the app's own card: the widest gap
    /// between the darkest and the lightest value of any colour channel, 0 for one flat colour.
    /// Nil, with the test failed, when the card could not be measured.
    ///
    /// The card is found, not assumed: SpringBoard lists each card as an element whose identifier
    /// begins `card:<bundle id>:sceneID:`, with its frame. Whatever else is in the switcher
    /// (Safari left by another test, Settings, the test runner) is not measured. The whole
    /// interior of the card is measured, inset only far enough to clear its rounded corners.
    ///
    /// The screenshot is kept in the result bundle, and written as a PNG when the run names a
    /// folder (`TEST_RUNNER_SCAN_SHOTS_DIR=<folder> xcodebuild test …`).
    func appSwitcherCardSpread(_ name: String, bundleID: String = "com.genesyx.app",
                               file: StaticString = #filePath, line: UInt = #line) -> Int? {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let bottom = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.999))
        let middle = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        bottom.press(forDuration: 0.1, thenDragTo: middle, withVelocity: .slow, thenHoldForDuration: 1.5)
        Thread.sleep(forTimeInterval: 1)

        let cards = springboard.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'card:'"))
        let card = cards.matching(NSPredicate(format: "identifier BEGINSWITH %@", "card:\(bundleID):sceneID:")).firstMatch
        guard card.waitForExistence(timeout: 5) else {
            let found = cards.allElementsBoundByIndex.map(\.identifier)
            XCTFail("\(name): the app's card is not in the app switcher, so nothing was measured. Cards there: \(found)",
                    file: file, line: line)
            return nil
        }
        // With other apps in the switcher the newest card rests partly off the right-hand edge. A
        // slow drag across the middle of the screen brings it there, where it stays; the app is
        // still only inactive.
        let screen = springboard.frame
        for _ in 0..<3 where !screen.contains(card.frame) {
            let grip = springboard.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: screen.midX, dy: card.frame.midY))
            grip.press(forDuration: 0.3, thenDragTo: grip.withOffset(CGVector(dx: -120, dy: 0)),
                       withVelocity: .slow, thenHoldForDuration: 0.6)
            Thread.sleep(forTimeInterval: 1)
        }
        let cardFrame = card.frame

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let folder = ProcessInfo.processInfo.environment["SCAN_SHOTS_DIR"] {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name).png"))
        }

        // Clear of the rounded corners, and of nothing else: the title and the tab bar lie inside.
        let inset = cardFrame.width * 0.06
        let interior = cardFrame.insetBy(dx: inset, dy: inset)
        guard screen.contains(interior), interior.width > 100, interior.height > 200 else {
            XCTFail("\(name): the app's card is not wholly on screen (\(cardFrame) in \(screen)), so it cannot be measured",
                    file: file, line: line)
            return nil
        }
        // Cards are stacked oldest first, so only one further right can lie over this one.
        for other in cards.allElementsBoundByIndex where other.identifier != card.identifier && other.frame.minX > cardFrame.minX {
            XCTAssertFalse(other.frame.intersects(interior),
                           "\(name): \(other.identifier) lies over the app's card, so it cannot be measured", file: file, line: line)
        }

        guard let image = screenshot.image.cgImage else {
            XCTFail("no screenshot", file: file, line: line)
            return nil
        }
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = CGContext(data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8,
                                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let scale = CGFloat(image.width) / screen.width
        var lowest = [UInt8](repeating: 255, count: 3), highest = [UInt8](repeating: 0, count: 3)
        for y in stride(from: Int(interior.minY * scale), to: Int(interior.maxY * scale), by: 2) {
            for x in stride(from: Int(interior.minX * scale), to: Int(interior.maxX * scale), by: 2) {
                for channel in 0..<3 {
                    let value = pixels[(y * image.width + x) * 4 + channel]
                    lowest[channel] = min(lowest[channel], value)
                    highest[channel] = max(highest[channel], value)
                }
            }
        }
        let spread = (0..<3).map { Int(highest[$0]) - Int(lowest[$0]) }.max() ?? 255
        // In the log beside the result, so a failure can be read without the picture.
        XCTContext.runActivity(named: "App switcher, \(name): spread \(spread) over \(interior) of the card at \(cardFrame)") { _ in }
        return spread
    }
}
