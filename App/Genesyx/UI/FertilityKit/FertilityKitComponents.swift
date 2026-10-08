import GenesyxCore
import SwiftUI

// The house patterns for a kit screen, once, so every screen draws the same card, row and note.
// Only `gx` fonts and `GenesyxColor` tokens.

/// The card every kit screen is built from. With an identifier it is a container: its identified
/// children stay their own elements.
struct KitCard<Content: View>: View {
    private let tinted: Bool
    private let identifier: String?
    private let content: Content

    init(tinted: Bool = false, identifier: String? = nil, @ViewBuilder content: () -> Content) {
        self.tinted = tinted
        self.identifier = identifier
        self.content = content()
    }

    var body: some View {
        let card = VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            // The tint sits over the card colour: on its own it is nearly black in dark mode.
            .background(tinted ? GenesyxColor.primary.opacity(0.10) : Color.clear)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        if let identifier { card.kitContainer(identifier) } else { card }
    }
}

extension View {
    /// A container: it holds identified children, which keep their own identifiers. A bare
    /// identifier here would rename them, because the outermost one wins.
    func kitContainer(_ identifier: String) -> some View {
        accessibilityElement(children: .contain).accessibilityIdentifier(identifier)
    }

    /// A row: one element read as one, with the label it is given and no identified child inside.
    func kitRow(_ identifier: String, label: String) -> some View {
        accessibilityElement(children: .ignore).accessibilityLabel(label).accessibilityIdentifier(identifier)
    }
}

struct KitSectionTitle: View {
    private let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

struct KitLine: View {
    private let text: String
    private let muted: Bool

    init(_ text: String, muted: Bool = false) {
        self.text = text
        self.muted = muted
    }

    var body: some View {
        Text(text).font(muted ? .gxBodySmall : .gxBody)
            .foregroundStyle(muted ? GenesyxColor.mutedForeground : GenesyxColor.foreground)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The disclaimer pattern: small and muted, in a card of its own when `boxed`.
struct KitNote: View {
    private let text: String
    private let boxed: Bool

    init(_ text: String, boxed: Bool = false) {
        self.text = text
        self.boxed = boxed
    }

    var body: some View {
        if boxed {
            KitLine(text, muted: true)
                .padding(16)
                .background(GenesyxColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            KitLine(text, muted: true)
        }
    }
}

/// The More row: an icon tile, a title, a line under it and a chevron. One element, read as the
/// title and the detail together.
struct KitRow: View {
    private let icon: String
    private let title: String
    private let detail: String?
    private let identifier: String
    private let action: () -> Void

    init(icon: String, title: String, detail: String?, identifier: String, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.identifier = identifier
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18)).foregroundStyle(GenesyxColor.primary)
                    .frame(width: 44, height: 44)
                    .background(GenesyxColor.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.foreground)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail {
                        Text(detail).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(GenesyxColor.mutedForeground)
            }
            .padding(20)
            .background(GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
        .buttonStyle(.plain)
        .kitRow(identifier, label: FertilityKitCopy.titleAndDetail(title, detail))
        .accessibilityAddTraits(.isButton)
    }
}

/// The quieter of the two buttons: a capsule in the card colour with primary text. The size and
/// the fill are inside the label, so the whole capsule takes the tap.
struct KitSecondaryButton: View {
    private let title: String
    private let action: () -> Void

    init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title).font(.gxCardHeadingSmall).foregroundStyle(GenesyxColor.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(GenesyxColor.card)
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Several lines read as one element: one line each to the eye, one sentence run to VoiceOver.
struct KitLines: View {
    private let lines: [String]
    private let identifier: String

    init(_ lines: [String], identifier: String) {
        self.lines = lines
        self.identifier = identifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in KitLine(line) }
        }
        .kitRow(identifier, label: FertilityKitCopy.sentences(lines))
    }
}

/// Dates in words: day, then month, always. Built from the year, month and day a calendar date
/// already holds, so the result cannot depend on the device's calendar, zone or language.
enum FertilityKitDates {
    static func dayMonth(_ date: CalendarDate) -> String {
        FertilityKitCopy.dayMonth(day: date.day, month: date.month)
    }

    static func dayMonthYear(_ date: CalendarDate) -> String {
        FertilityKitCopy.dayMonthYear(day: date.day, month: date.month, year: date.year)
    }

    static func range(_ first: CalendarDate, _ last: CalendarDate) -> String {
        FertilityKitCopy.dateRange(dayMonth(first), dayMonth(last))
    }
}
