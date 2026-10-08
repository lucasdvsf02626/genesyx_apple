import GenesyxCore
import SwiftUI

enum ProgrammeGuidePresentation {
    /// The guide in order, without the section on scanning where scanning is not available.
    static func sections(in kit: FertilityKitContext) -> [ProgrammeGuideSection] {
        ProgrammeGuideDraft.sections.filter { FertilityKitRoutes.isVisible($0, in: kit) }
    }
}

/// The Programme Guide: a list of short sections, each read on its own screen that More hosts.
struct ProgrammeGuideView: View {
    @Environment(\.fertilityKit) private var kit

    init() {}

    var body: some View {
        let sections = ProgrammeGuidePresentation.sections(in: kit)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                KitLine(ProgrammeReaderCopy.guideIntro, muted: true)
                    .accessibilityIdentifier("kit.guide.intro")
                    .padding(.bottom, 4)
                ForEach(sections) { section in
                    KitRow(icon: "book", title: section.title, detail: nil,
                           identifier: "kit.guide.section.\(section.slug)") {
                        kit.openGuideSection(section.slug)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            .kitContainer("kit.guide")
        }
        .frame(maxWidth: .infinity)
        .gxPageBackground()
        .navigationTitle(FertilityKitCopy.programmeGuide)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    ProgrammeGuideView().withKitPreview()
}
#endif
