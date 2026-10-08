import GenesyxCore
import SwiftUI

/// My Fertility Picture: what she has recorded, assembled by core. This screen draws what core
/// hands it and adds nothing: no row, no condition, no wording of its own beyond two sentences.
struct FertilityPictureView: View {
    @Environment(\.fertilityKit) private var kit
    @State private var route: FertilityKitRoute?

    init() {}

    var body: some View {
        let picture = FertilityPictureLogic.picture(kit.pictureInput())
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch FertilityPicturePresentation.screen(for: picture) {
                case .withheld:
                    ConsentWithdrawnBanner().kitContainer("kit.picture.withheld")
                case .empty:
                    KitNote(FertilityPictureScreenCopy.empty, boxed: true)
                        .accessibilityIdentifier("kit.picture.empty")
                case .sections:
                    KitNote(FertilityPictureScreenCopy.intro)
                    ForEach(picture.sections) { section in sectionCard(section) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            .kitContainer("kit.picture")
        }
        .gxPageBackground()
        .navigationTitle(FertilityPictureCopy.title)
        .navigationBarTitleDisplayMode(.inline)
        .fertilityKitRoute($route)
    }

    private func sectionCard(_ section: FertilityPictureSection) -> some View {
        KitCard(identifier: "kit.picture.section.\(section.kind.rawValue)") {
            ForEach(Array(FertilityPicturePresentation.items(for: section).enumerated()), id: \.offset) { _, item in
                switch item {
                case .title(let text):
                    KitSectionTitle(text)
                case .note(let text):
                    KitNote(text).accessibilityIdentifier("kit.picture.note.\(section.kind.rawValue)")
                case .row(let row):
                    rowView(row)
                }
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: FertilityPictureRow) -> some View {
        let lines = FertilityPictureScreenCopy.rowLines(for: row)
        let target = FertilityKitRoutes.route(for: row.destination, in: kit)
        let content = HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { position, line in
                    Text(line).font(position == 0 ? .gxCardHeadingSmall : position == 1 ? .gxBody : .gxBodySmall)
                        .foregroundStyle(position <= 1 ? GenesyxColor.foreground : GenesyxColor.mutedForeground)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if target != .unavailable {
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(GenesyxColor.mutedForeground)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        if target == .unavailable {
            content.kitRow("kit.picture.row.\(row.id)", label: FertilityKitCopy.sentences(lines))
        } else {
            Button { route = target } label: { content }
                .buttonStyle(.plain)
                .kitRow("kit.picture.row.\(row.id)", label: FertilityKitCopy.sentences(lines))
                .accessibilityAddTraits(.isButton)
        }
    }
}

/// What the screen draws, as pure functions over what core returned.
enum FertilityPicturePresentation {

    enum Screen: Equatable {
        case withheld, empty, sections
    }

    /// One thing a section draws, in order.
    enum Item: Equatable {
        case title(String)
        case note(String)
        case row(FertilityPictureRow)
    }

    static func screen(for picture: FertilityPicture) -> Screen {
        screen(isWithheld: picture.isWithheldForConsent, sectionCount: picture.sections.count)
    }

    static func screen(isWithheld: Bool, sectionCount: Int) -> Screen {
        if isWithheld { return .withheld }
        return sectionCount == 0 ? .empty : .sections
    }

    /// The title, then the rows. A section's note sits under its title, with one exception: the
    /// Testing section's note is the ovulation test's own sentence, so it is drawn directly under
    /// the row of that result and never under the title, where it would read as a remark about
    /// the pH rows and the pregnancy test row as well. Without that row it has nowhere to go.
    static func items(for section: FertilityPictureSection) -> [Item] {
        var items: [Item] = [.title(section.title)]
        if section.kind != .testing, let note = section.note { items.append(.note(note)) }
        for row in section.rows {
            items.append(.row(row))
            if section.kind == .testing, row.kind == .latestLhResult, let note = section.note {
                items.append(.note(note))
            }
        }
        return items
    }
}

#if DEBUG
#Preview {
    FertilityPictureView().withKitPreview(day: 23)
}
#endif
