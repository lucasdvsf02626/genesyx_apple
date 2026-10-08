import GenesyxCore
import SwiftUI

enum ProgrammeGuideSectionPresentation {
    struct Button: Equatable {
        let label: String
        let route: FertilityKitRoute
    }

    /// The section's button, or nil where its route is unavailable (the text stays).
    static func button(for section: ProgrammeGuideSection, in kit: FertilityKitContext) -> Button? {
        let route = FertilityKitRoutes.route(forGuideSection: section, in: kit)
        return route == .unavailable ? nil : Button(label: section.callToAction.label, route: route)
    }
}

/// One guide section, read in full. Built by More and wrapped in the host like every kit screen.
struct ProgrammeGuideSectionView: View {
    private let section: ProgrammeGuideSection

    @Environment(\.fertilityKit) private var kit
    @State private var route: FertilityKitRoute?

    init(section: ProgrammeGuideSection) {
        self.section = section
    }

    var body: some View {
        let button = ProgrammeGuideSectionPresentation.button(for: section, in: kit)
        let showsRelated = !ProgrammeRelatedPresentation.rows(section.relatedContent, in: kit).isEmpty
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(section.title).font(.gxTitle).foregroundStyle(GenesyxColor.foreground)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("kit.guide.reader.title")
                ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                    KitLine(paragraph).accessibilityIdentifier("kit.guide.reader.paragraph.\(index)")
                }
                if showsRelated {
                    KitSectionTitle(ProgrammeReaderCopy.relatedHeading)
                        .accessibilityIdentifier("kit.guide.reader.relatedHeading")
                    ProgrammeRelatedContentList(references: section.relatedContent)
                }
                if let button {
                    GxPrimaryButton(title: button.label) { route = button.route }
                        .accessibilityIdentifier("kit.guide.reader.cta")
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            .kitContainer("kit.guide.reader")
        }
        .frame(maxWidth: .infinity)
        .gxPageBackground()
        .navigationTitle(FertilityKitCopy.programmeGuide)
        .navigationBarTitleDisplayMode(.inline)
        .fertilityKitRoute($route)
    }
}

#if DEBUG
#Preview {
    if let section = ProgrammeGuideDraft.sections.first {
        ProgrammeGuideSectionView(section: section).withKitPreview()
    }
}
#endif
