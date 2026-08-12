import SwiftUI
import UIKit

extension Color {
    /// Tints a brand color for overlay on a card (approximates the web `color-mix(... white)`).
    func tintOnWhite(_ fraction: Double) -> Color { opacity(fraction) }
}

/// A "Done" button above the keyboard, for the fields whose keyboard has no way out: `.numberPad`
/// carries no return key, and a wrapping (`axis: .vertical`) field's return key types a newline.
/// Without this the only escape is to find somewhere blank to tap, and until she does the keyboard
/// covers what she is editing. Resigns first responder rather than clearing a `@FocusState` because
/// a keyboard toolbar is scoped to the hierarchy and not to one field: on Profile the partner-email
/// field shares this one, and a button bound to the glass size alone would render there and do
/// nothing. That scoping cuts both ways — apply this once per hierarchy, or you get two Dones.
extension View {
    func gxKeyboardDoneToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .accessibilityIdentifier("keyboardDone")
            }
        }
    }
}

/// The page backdrop: the flat background colour with the brand artwork over it. Replaces a plain
/// `.background(GenesyxColor.background)` on the seven tab screens; sheets keep the flat fill, because
/// a card raised over a backdrop should not repeat it.
extension View {
    func gxPageBackground() -> some View { background(GxPageBackground()) }
}

private struct GxPageBackground: View {
    /// The artwork is painted on a near-white field. At full strength its blobs reach in far enough
    /// to sit under body text at the margins, so it is held back to where `mutedForeground` still
    /// reads over the deepest of them. One number, deliberately: this is the dial to turn if the
    /// client wants the art fainter or stronger.
    private static let artOpacity: Double = 0.55

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            GenesyxColor.background
            // Light only. The art's field matches the light background exactly, which is what makes
            // it read as a backdrop rather than a picture; over the dark palette the same image is a
            // lit panel with a hard edge.
            if colorScheme == .light {
                Image("page_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)   // phone-shaped art; fitting it letterboxes
                    .opacity(Self.artOpacity)
            }
        }
        .ignoresSafeArea()
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// An hour of the day in her locale's own format — "9 AM" or "09:00" depending on the phone. Shared
/// so the reminder-time pickers in Profile and in the supplement plan can't drift apart.
func gxHourLabel(_ hour: Int) -> String {
    var components = DateComponents(); components.hour = hour; components.minute = 0
    let date = Calendar.current.date(from: components) ?? Date()
    let formatter = DateFormatter(); formatter.timeStyle = .short
    return formatter.string(from: date)
}

/// ALL-CAPS section eyebrow (matches Android `Eyebrow`).
struct Eyebrow: View {
    let text: String
    var color: Color = GenesyxColor.mutedForeground

    init(_ text: String, color: Color = GenesyxColor.mutedForeground) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.gxEyebrow)
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

/// Tall pill primary CTA (height 56, radius 28, electric-lavender).
struct GxPrimaryButton: View {
    let title: String
    var enabled: Bool = true
    var leadingSystemImage: String? = nil
    var trailingSystemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let leadingSystemImage { Image(systemName: leadingSystemImage) }
                Text(title).font(.gxCardHeadingSmall)
                if let trailingSystemImage { Image(systemName: trailingSystemImage) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(enabled ? GenesyxColor.primary : GenesyxColor.primary.opacity(0.45))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// Low-emphasis text button.
struct GxGhostButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.gxBody.weight(.medium))
                .foregroundStyle(GenesyxColor.foreground.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

/// Back chevron button (44pt hit area).
struct GxBackButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(GenesyxColor.foreground)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}

/// Quiz / selectable option row with a trailing radio that fills + checks when selected.
struct GxOptionPill: View {
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.gxBody.weight(.medium))
                    .foregroundStyle(selected ? GenesyxColor.primary : GenesyxColor.foreground)
                Spacer()
                ZStack {
                    Circle()
                        .fill(selected ? GenesyxColor.primary : .clear)
                        .frame(width: 28, height: 28)
                        .overlay(Circle().strokeBorder(selected ? .clear : GenesyxColor.border, lineWidth: 1.5))
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 60)
            .background(selected ? GenesyxColor.primary.tintOnWhite(0.10) : GenesyxColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(selected ? GenesyxColor.primary : GenesyxColor.border, lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Decorative "BrandOrb" — soft pearl/gradient blob (approximates the web `.gx-orb`).
struct BrandOrb: View {
    var size: CGFloat = 96
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        .white,
                        GenesyxColor.primaryLight.opacity(0.45),
                        GenesyxColor.babyLavender.opacity(0.35),
                        GenesyxColor.powderPink.opacity(0.30),
                    ],
                    center: .center, startRadius: 0, endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
    }
}

/// The brand egg motif — the crescent form the onboarding screens were always meant to float,
/// which `BrandOrb` stood in for while the artwork was outstanding.
///
/// The two tints are named for their colour, not for the asset files behind them. The files are
/// `egg_female`/`egg_male`, but nothing decorative should carry that meaning: these are background
/// texture, and a reader who inferred the app was sorting her by sex would be reading something
/// into the wallpaper that the app does not say anywhere.
struct BrandEgg: View {
    enum Tint {
        case warm, cool
        fileprivate var asset: String {
            switch self {
            case .warm: return "egg_female"
            case .cool: return "egg_male"
            }
        }
    }

    /// Dark mode is not reachable on the splash today — the theme defaults to `.light` and can only
    /// be changed in Profile, which is behind onboarding. But the fade has to know about the scheme
    /// anyway, because the artwork is pale: a partly-transparent pale crescent over `#F2F2F2` is a
    /// soft tint, and the same value over `#000000` composites toward black and reads as a grey
    /// smudge on the glass. Flipping the default would otherwise make that smudge the first thing
    /// a new user sees, with nothing in the diff to suggest the splash was involved.
    @Environment(\.colorScheme) private var scheme

    let tint: Tint
    var size: CGFloat = 96
    var fade: Double = 0.5

    init(_ tint: Tint, size: CGFloat = 96, fade: Double = 0.5) {
        self.tint = tint
        self.size = size
        self.fade = fade
    }

    var body: some View {
        Image(tint.asset)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .opacity(scheme == .dark ? min(1, fade * 1.7) : fade)
            // Decoration only — VoiceOver should reach the headline, not four unnamed shapes.
            .accessibilityHidden(true)
    }
}
