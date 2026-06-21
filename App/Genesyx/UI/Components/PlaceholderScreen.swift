import SwiftUI

/// Temporary screen for tabs not yet translated. Mirrors the Android `PlaceholderScreen`.
struct PlaceholderScreen: View {
    let title: String
    var systemImage: String = "sparkles"

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(GenesyxColor.primary)
                Text("\(title) coming soon")
                    .font(.gxCardHeading)
                    .foregroundStyle(GenesyxColor.foreground)
                Text("This screen is being translated from the Android build.")
                    .font(.gxBodySmall)
                    .foregroundStyle(GenesyxColor.mutedForeground)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(GenesyxColor.background)
            .navigationTitle(title)
        }
    }
}
