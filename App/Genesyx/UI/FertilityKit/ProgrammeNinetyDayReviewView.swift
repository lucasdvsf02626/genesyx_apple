import GenesyxCore
import SwiftUI

/// The review of the whole programme, from day 91. It prints what core hands it, and its pattern
/// sentences are the ones of day 90, not of the day it is opened. Counts nothing itself.
struct ProgrammeNinetyDayReviewView: View {
    @Environment(\.fertilityKit) private var kit
    @EnvironmentObject private var programme: ProgrammeRepository
    @State private var route: FertilityKitRoute?

    init() {}

    var body: some View {
        let review = ProgrammeReviewLogic.ninetyDay(kit.reviewInput(patterns: kit.ninetyDayPatterns()))
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let review {
                    header(review)
                    tracked(review)
                    consistency(review)
                    if let hydration = review.hydration {
                        textCard(ProgrammeReviewCopy.hydrationTitle, hydration.text, "kit.review.ninety.hydration")
                    }
                    if let sleep = review.sleep {
                        textCard(ProgrammeReviewCopy.sleepTitle, sleep.text, "kit.review.ninety.sleep")
                    }
                    strongest(review)
                    patterns(review)
                    whatToContinue(review)
                    KitRow(icon: "chart.xyaxis.line", title: ProgrammeReviewScreenCopy.openPicture, detail: nil,
                           identifier: "kit.review.ninety.picture") { kit.open(.kitPicture) }
                } else {
                    KitLine(ProgrammeReviewPresentation.ninetyDayUnavailable(in: kit), muted: true)
                        .accessibilityIdentifier("kit.review.ninety.notAvailable")
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            .kitContainer("kit.review.ninety")
        }
        .frame(maxWidth: .infinity)
        .gxPageBackground()
        .navigationTitle(ProgrammeReviewCopy.ninetyDayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .fertilityKitRoute($route)
        .onAppear { ProgrammeReviewPresentation.markViewed(review, in: programme) }
    }

    private func header(_ review: ProgrammeNinetyDayReview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(review.headline).font(.gxTitle).foregroundStyle(GenesyxColor.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("kit.review.ninety.headline")
            KitLines([ProgrammeReviewCopy.programmePeriodTitle,
                      FertilityKitDates.range(review.firstDate, review.lastDate)],
                     identifier: "kit.review.ninety.period")
        }
    }

    @ViewBuilder
    private func tracked(_ review: ProgrammeNinetyDayReview) -> some View {
        let body = review.tracked.filter { ProgrammeReviewPresentation.bodyKinds.contains($0.kind) }
        let rest = review.tracked.filter { !ProgrammeReviewPresentation.bodyKinds.contains($0.kind) }
        if !rest.isEmpty {
            KitCard {
                KitSectionTitle(ProgrammeReviewCopy.trackedTitle)
                ProgrammeReviewTrackedList(counts: rest, identifier: "kit.review.ninety.tracked", route: $route)
            }
        }
        if !body.isEmpty {
            KitCard {
                KitSectionTitle(ProgrammeReviewCopy.bodyCheckInsTitle)
                ProgrammeReviewTrackedList(counts: body, identifier: "kit.review.ninety.tracked", route: $route)
            }
        }
    }

    @ViewBuilder
    private func consistency(_ review: ProgrammeNinetyDayReview) -> some View {
        if !review.consistencyLines.isEmpty || review.supportLine != nil {
            KitCard {
                KitSectionTitle(ProgrammeReviewCopy.consistencyTitle)
                if !review.consistencyLines.isEmpty {
                    KitLines(review.consistencyLines, identifier: "kit.review.ninety.consistency")
                }
                if let support = review.supportLine {
                    KitLine(support).accessibilityIdentifier("kit.review.ninety.support")
                }
            }
        }
    }

    private func textCard(_ title: String, _ text: String, _ identifier: String) -> some View {
        KitCard {
            KitSectionTitle(title)
            KitLine(text).accessibilityIdentifier(identifier)
        }
    }

    @ViewBuilder
    private func strongest(_ review: ProgrammeNinetyDayReview) -> some View {
        if !review.strongestRoutines.isEmpty {
            KitCard {
                KitSectionTitle(ProgrammeReviewCopy.strongestRoutinesTitle)
                ForEach(Array(review.strongestRoutines.enumerated()), id: \.offset) { index, routine in
                    KitLines([routine.name, routine.text], identifier: "kit.review.ninety.strongest.\(index)")
                }
            }
        }
    }

    /// The statements, and beside them the still-learning sentence when nothing can be said across
    /// cycles yet. Neither stands in for the other. No statement and not learning: no section.
    @ViewBuilder
    private func patterns(_ review: ProgrammeNinetyDayReview) -> some View {
        if ProgrammeReviewPresentation.showsPatterns(review) {
            KitCard {
                KitSectionTitle(ProgrammeReviewCopy.patternsTitle)
                ForEach(Array(review.patterns.enumerated()), id: \.offset) { index, statement in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ProgrammeEvidenceCopy.title(for: statement.level)).font(.gxLabel)
                            .foregroundStyle(GenesyxColor.mutedForeground)
                        KitLine(statement.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .kitRow("kit.review.ninety.patterns.\(index)",
                            label: FertilityKitCopy.sentences(
                                [ProgrammeEvidenceCopy.title(for: statement.level), statement.text]))
                }
                if review.isStillLearning {
                    KitLine(ProgrammeEvidenceCopy.stillLearning)
                        .accessibilityIdentifier("kit.review.ninety.stillLearning")
                }
            }
        }
    }

    @ViewBuilder
    private func whatToContinue(_ review: ProgrammeNinetyDayReview) -> some View {
        if !review.whatToContinue.isEmpty {
            KitCard {
                KitSectionTitle(ProgrammeReviewCopy.whatToContinueTitle)
                ForEach(Array(review.whatToContinue.enumerated()), id: \.offset) { index, line in
                    KitLine(line).accessibilityIdentifier("kit.review.ninety.continue.\(index)")
                }
            }
        }
    }
}

#if DEBUG
#Preview("Day 95") {
    ProgrammeNinetyDayReviewView().withKitPreview(day: 95)
}
#endif
