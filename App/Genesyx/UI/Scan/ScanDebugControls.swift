#if DEBUG
import GenesyxCore
import ImageIO
import PhotosUI
import SwiftUI

// DEBUG-only scan UI: the notice that a result is scripted, a way to push a chosen image through
// the capture path, and a preview of every scan state. Compiled only in DEBUG; never ships.

/// Sits above every simulated result, so a scripted number is never mistaken for a reading.
struct ScanDebugBanner: View {
    let saveBlocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Simulated result. Not a real reading.")
                .font(.gxLabel)
                .accessibilityIdentifier("scan.debug.simulatedBanner")
            if saveBlocked {
                Text("Saving is off for simulated results while a backend is connected.")
                    .font(.gxBodySmall)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("scan.debug.saveBlocked")
            }
        }
        .foregroundStyle(GenesyxColor.foreground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(GenesyxColor.muted)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Picks a photo and hands it over decoded. The image is decoded in memory and passed straight
/// on: nothing is written to disk and nothing is kept here.
struct ScanDebugTestImageButton: View {
    let onImage: (CGImage) -> Void

    @State private var item: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $item, matching: .images) {
            Text("Use Test Image")
                .font(.gxBodySmall.weight(.medium))
                .frame(minHeight: 44)
        }
        .accessibilityIdentifier("scan.debug.useTestImage")
        .task(id: item) {
            guard let item else { return }
            if let data = try? await item.loadTransferable(type: Data.self),
               let source = CGImageSourceCreateWithData(data as CFData, nil),
               let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                onImage(image)
            }
            self.item = nil
        }
    }
}

@MainActor
private func scanPreviewContent(_ state: ScannerState) -> some View {
    ScanCaptureContent(
        state: state, configuration: .developmentPlaceholder, preview: AnyView(Color.black),
        isObscured: false, onManualEntry: {}, onOpenSettings: {}, onTryAgain: {})
        .background(GenesyxColor.background)
        .withPreviewEnvironment()
}

@MainActor
private func scanPreviewResult(_ value: Double, _ saveState: ScanSaveState = .unsaved, saveBlocked: Bool = false) -> some View {
    ScanResultView(
        value: value, isSimulated: true, saveBlocked: saveBlocked, saveState: saveState,
        onSave: {}, onScanAgain: {}, onViewHistory: {})
        .background(GenesyxColor.background)
        .withPreviewEnvironment()
}

#Preview("Scan: preparing") { scanPreviewContent(.preparingCamera) }
#Preview("Scan: searching") { scanPreviewContent(.searching) }
#Preview("Scan: strip detected") { scanPreviewContent(.stripDetected) }
#Preview("Scan: too dark") { scanPreviewContent(.qualityIssue(.tooDark)) }
#Preview("Scan: ready") { scanPreviewContent(.ready) }
#Preview("Scan: analysing") { scanPreviewContent(.analysing) }
#Preview("Scan: paused") { scanPreviewContent(.interrupted(.other)) }
#Preview("Scan: permission denied") { scanPreviewContent(.permissionDenied) }
#Preview("Scan: camera unavailable") { scanPreviewContent(.cameraUnavailable) }

#Preview("Scan result: healthy") { scanPreviewResult(4.2) }
#Preview("Scan result: elevated") { scanPreviewResult(5.2) }
#Preview("Scan result: saved") { scanPreviewResult(4.2, .saved) }
#Preview("Scan result: refused") { scanPreviewResult(4.2, .refused) }
#Preview("Scan result: save blocked") { scanPreviewResult(4.2, saveBlocked: true) }

#Preview("Scan unreadable") {
    ScanUnreadableView(issues: [], onScanAgain: {}, onManualEntry: {})
        .background(GenesyxColor.background)
        .withPreviewEnvironment()
}
#Preview("Scan unreadable: glare") {
    ScanUnreadableView(issues: [.glare], onScanAgain: {}, onManualEntry: {})
        .background(GenesyxColor.background)
        .withPreviewEnvironment()
}

#Preview("Scan capture: live") {
    ScanCaptureView(services: .debug(scenario: .reading(4.4)), onExit: { _ in })
        .withPreviewEnvironment()
}
#endif
