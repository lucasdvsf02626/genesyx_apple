import SwiftUI

/// Generic error / not-found surface, mirroring the web router's error + 404 components.
/// Use as a fallback when a screen fails to load or a route is unknown.
struct ErrorStateView: View {
    var title: String = "Something went wrong"
    var message: String = "Please try again."
    var systemImage: String = "exclamationmark.triangle"
    var retryTitle: String = "Try again"
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage).font(.system(size: 40)).foregroundStyle(GenesyxColor.primary)
            Text(title).font(.gxCardHeading).foregroundStyle(GenesyxColor.foreground)
            Text(message).font(.gxBodySmall).foregroundStyle(GenesyxColor.mutedForeground)
                .multilineTextAlignment(.center)
            if let onRetry {
                Button(action: onRetry) {
                    Text(retryTitle).font(.gxLabel).foregroundStyle(GenesyxColor.primary)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .overlay(Capsule().strokeBorder(GenesyxColor.primary, lineWidth: 1))
                }
                .buttonStyle(.plain).padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GenesyxColor.background)
    }
}
