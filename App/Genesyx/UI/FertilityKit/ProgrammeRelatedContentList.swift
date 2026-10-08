import GenesyxCore
import SwiftUI

/// The rows of a related-content list. Pure, so a caller asks it before it draws a heading, and
/// the heading goes with the list when no row survives.
enum ProgrammeRelatedPresentation {
    struct Row: Equatable, Identifiable {
        let reference: ProgrammeContentReference
        let identifier: String
        let title: String
        let route: FertilityKitRoute
        let icon: String

        var id: String { identifier }
    }

    /// One row per reference whose route is not `.unavailable`. `article` is Learn's own rule for
    /// opening an article, so a row is never offered that Learn would then refuse.
    static func rows(_ references: [ProgrammeContentReference], in kit: FertilityKitContext,
                     article: (String) -> LearnArticle? = LearnLibrary.articleBySlug) -> [Row] {
        references.compactMap { reference in
            let route = FertilityKitRoutes.route(for: reference, in: kit, isPublished: { article($0) != nil })
            guard route != .unavailable else { return nil }
            switch reference {
            case .learnArticle(let slug):
                guard let title = article(slug)?.title else { return nil }
                return Row(reference: reference, identifier: "kit.related.\(slug)", title: title, route: route,
                           icon: "book")
            case .recipe(let id):
                guard let title = RecipeContent.all.first(where: { $0.id == id })?.name else { return nil }
                return Row(reference: reference, identifier: "kit.related.\(id)", title: title, route: route,
                           icon: "fork.knife")
            }
        }
    }
}

/// Reading a day or a guide section points at. Draws nothing when no reference can be opened.
struct ProgrammeRelatedContentList: View {
    private let references: [ProgrammeContentReference]

    @Environment(\.fertilityKit) private var kit
    @State private var route: FertilityKitRoute?

    init(references: [ProgrammeContentReference]) {
        self.references = references
    }

    var body: some View {
        let rows = ProgrammeRelatedPresentation.rows(references, in: kit)
        if !rows.isEmpty {
            VStack(spacing: 12) {
                ForEach(rows) { row in
                    KitRow(icon: row.icon, title: row.title, detail: nil, identifier: row.identifier) {
                        route = row.route
                    }
                }
            }
            .kitContainer("kit.related")
            .fertilityKitRoute($route)
        }
    }
}

#if DEBUG
#Preview {
    ProgrammeRelatedContentList(references: [.learnArticle(slug: "understanding-your-cycle")])
        .padding(20)
        .withKitPreview(day: 23)
}
#endif
