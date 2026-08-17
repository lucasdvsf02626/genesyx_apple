import GenesyxCore
import PDFKit
import SwiftUI

/// The bundled starter guide. Opened from onboarding before there is an account, and from
/// Learn → Guides after there is one — both entry points resolve this one file, so the name it is
/// bundled under lives here once rather than being typed at each call site.
enum FreeGuide {
    static let title = "7-Day Fertility Nutrition Starter Guide"
    static let resourceName = "Genesyx_7_Day_Fertility_Nutrition_Starter_Guide"

    /// `nil` only when the PDF has fallen out of the target's Copy Bundle Resources phase. That is
    /// a build misconfiguration rather than a runtime condition, and it is silent — the button
    /// still opens, the screen is just empty. `FreeGuideBundleTests` is what catches it, because a
    /// file sitting in the repository proves nothing about what shipped.
    static var url: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: "pdf")
    }
}

/// PDFKit is UIKit-only, so the reader is a wrapped `PDFView`.
private struct GuidePdfView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(url: url)
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .systemBackground
        view.delegate = context.coordinator
        view.accessibilityIdentifier = "guide.pdf"
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}

    /// Implementing `pdfViewWillClick(onLink:)` is what stops PDFKit handing an embedded link
    /// straight to Safari. The guide is meant to open before registration and with no connection,
    /// so a tap that silently leaves the app for the web would break both of those promises.
    final class Coordinator: NSObject, PDFViewDelegate {
        func pdfViewWillClick(onLink sender: PDFView, with url: URL) {}
    }
}

/// The text equivalent of the guide, rendered as native SwiftUI so VoiceOver can navigate it by
/// heading and Dynamic Type can resize it. `FreeGuideContent` explains where it deliberately
/// departs from the printed page.
private struct GuideTextView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(FreeGuideContent.pages) { page in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(page.heading)
                            .font(.gxCardHeading)
                            .foregroundStyle(GenesyxColor.foreground)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(Array(page.blocks.enumerated()), id: \.offset) { _, block in
                            blockView(block)
                        }
                        // Printed page numbers are announced so a VoiceOver user and a sighted
                        // reader can refer to the same place in the same document.
                        Text("Page \(page.number)")
                            .font(.gxBodySmall)
                            .foregroundStyle(GenesyxColor.mutedForeground)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .gxPageBackground()
        .accessibilityIdentifier("guide.text")
    }

    @ViewBuilder
    private func blockView(_ block: FreeGuideContent.Block) -> some View {
        switch block {
        case .subheading(let t):
            Text(t)
                .font(.gxBody.weight(.semibold))
                .foregroundStyle(GenesyxColor.foreground)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 4)
        case .paragraph(let t):
            Text(t).font(.gxBody).foregroundStyle(GenesyxColor.foreground.opacity(0.85))
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(GenesyxColor.primary).frame(width: 5, height: 5).padding(.top, 8)
                        Text(item).font(.gxBody).foregroundStyle(GenesyxColor.foreground.opacity(0.85))
                    }
                    // The bullet glyph is decoration; without this VoiceOver reads the dot.
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// The guide screen itself. Presented as a sheet from both entry points, so dismissing always
/// returns to whatever opened it.
struct FreeGuideScreen: View {
    @Environment(\.dismiss) private var dismiss
    /// VoiceOver users get the text version by default, because the PDF is untagged and reads to
    /// them as one unnavigable image. Everyone else gets the designed pages, and can switch.
    @State private var showsText = UIAccessibility.isVoiceOverRunning

    var body: some View {
        NavigationStack {
            Group {
                if showsText {
                    GuideTextView()
                } else if let url = FreeGuide.url {
                    GuidePdfView(url: url)
                        // The PDF is not accessibility-tagged, so VoiceOver would otherwise land on
                        // an unlabelled view. The text version above is the equivalent; this names
                        // the image for anyone who switches back to it.
                        .accessibilityLabel(FreeGuide.title)
                } else {
                    unavailable
                }
            }
            .ignoresSafeArea(edges: showsText ? [] : .bottom)
            .navigationTitle(FreeGuide.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(showsText ? "Pages" : "Text") {
                        showsText.toggle()
                    }
                    .accessibilityIdentifier("guide.textToggle")
                    .accessibilityLabel(showsText
                                        ? "Show the designed pages"
                                        : "Show the text version")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("guide.done")
                }
            }
        }
        .accessibilityIdentifier("guide.screen")
    }

    private var unavailable: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 32)).foregroundStyle(GenesyxColor.mutedForeground)
            Text("The guide couldn't be opened.")
                .font(.gxBody).foregroundStyle(GenesyxColor.foreground)
            Text("Please update to the latest version of Genesyx.")
                .font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gxPageBackground()
    }
}
