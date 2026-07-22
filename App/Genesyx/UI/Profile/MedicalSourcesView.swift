import SwiftUI

/// Settings → "Medical Sources & Disclaimer". A single place listing the app's medical
/// disclaimer and every source referenced across the app (Guideline 1.4.1).
struct MedicalSourcesView: View {
    private let sources = MedicalSourceStore.shared.sources

    var body: some View {
        List {
            Section("Medical Disclaimer") {
                Text("Genesyx provides general health and wellness information for educational purposes only. It is not a medical device and is not a substitute for professional medical advice, diagnosis, or treatment. Hydration goals and insights are general guidance, and vaginal pH readings are for wellness tracking only — not for diagnosing or monitoring any medical condition. Always consult a qualified healthcare provider with any questions about your health, and do not rely on this app for contraception.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Sources & References") {
                ForEach(sources) { source in
                    Link(destination: source.url) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.title)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text(source.organisation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("medSource.\(source.id)")
                }
            }
        }
        .navigationTitle("Medical Sources")
        .navigationBarTitleDisplayMode(.inline)
    }
}
