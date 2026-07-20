import SwiftUI

enum OnboardingTheme {
    static let accent = Color(red: 1.0, green: 0.39, blue: 0.28)
    static let panel = Color.white.opacity(0.055)
    static let border = Color.white.opacity(0.10)
}

struct OnboardingPrimaryButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .padding(.horizontal, 18)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(OnboardingTheme.accent)
            )
        }
        .buttonStyle(.plain)
    }
}

struct OnboardingSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(OnboardingTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(OnboardingTheme.border, lineWidth: 1)
            )
    }
}
