import SwiftUI

extension Color {
    /// Tints a brand color for overlay on a card (approximates the web `color-mix(... white)`).
    func tintOnWhite(_ fraction: Double) -> Color { opacity(fraction) }
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
