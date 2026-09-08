import SwiftUI

struct OnboardingSwitchSoundsView: View {
    @Binding var isEnabled: Bool

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.accent)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(OnboardingTheme.accent.opacity(0.10))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Switching sounds")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text("A different sound for each layout")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.50))
                }

                Spacer()
            }
        }
        .toggleStyle(.switch)
        .tint(OnboardingTheme.accent)
        .accessibilityLabel("Switching sounds")
        .accessibilityHint("Plays a sound when the layout changes. Applies when you save changes.")
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(OnboardingTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(OnboardingTheme.border, lineWidth: 1)
        )
    }
}
