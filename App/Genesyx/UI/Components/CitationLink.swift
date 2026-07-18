import SwiftUI

/// Compact inline citation for insight cards — one tappable source that opens in the browser.
struct CitationLink: View {
    let sourceID: String
    @Environment(\.openURL) private var openURL

    init(_ sourceID: String) { self.sourceID = sourceID }

    var body: some View {
        if let source = MedicalSourceStore.shared.source(sourceID) {
            Button {
                openURL(source.url)
            } label: {
                Label("Source: \(source.organisation)", systemImage: "text.book.closed")
                    .font(.caption2)
                    .foregroundStyle(GenesyxColor.mutedForeground)
                    .underline()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View medical source: \(source.title)")
            .accessibilityIdentifier("citation.\(sourceID)")
        }
    }
}

/// Multi-source footer for long-form sections (e.g. "Why hydration?", Learn articles).
struct SourcesFooter: View {
    let sourceIDs: [String]
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sources")
                .font(.caption.weight(.semibold))
                .foregroundStyle(GenesyxColor.mutedForeground)
            ForEach(sourceIDs, id: \.self) { id in
                if let source = MedicalSourceStore.shared.source(id) {
                    Button {
                        openURL(source.url)
                    } label: {
                        Text("• \(source.title) — \(source.organisation)")
                            .font(.caption2)
                            .foregroundStyle(GenesyxColor.mutedForeground)
                            .underline()
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View medical source: \(source.title)")
                    .accessibilityIdentifier("source.\(id)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}
