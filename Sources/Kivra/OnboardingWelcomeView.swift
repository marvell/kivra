import SwiftUI

struct OnboardingWelcomeView: View {
    @ObservedObject var model: OnboardingModel

    private let applicationName = ApplicationIdentity.current.displayName

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Made for people who type in two languages.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))

            Text("Stop cycling through layouts.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(-0.7)
                .padding(.top, 9)

            Text(
                "The macOS shortcut takes several keys and only moves\nto the next layout. \(applicationName) lets you choose one directly."
            )
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(.white.opacity(0.50))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.top, 11)

            HStack(spacing: 11) {
                languageKey(side: "LEFT SHIFT", language: model.selectedLeftName)
                languageKey(side: "RIGHT SHIFT", language: model.selectedRightName)
            }
            .padding(.top, 21)

            Text("Whatever is active, you always know which key to press.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.46))
                .padding(.top, 13)

            Spacer()
            OnboardingPrimaryButton(
                title: "Continue",
                symbol: "arrow.right",
                action: model.continueFromWelcome
            )
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 30)
        }
    }

    private func languageKey(side: String, language: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "shift.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(OnboardingTheme.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(side)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.34))
                Text(language)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .frame(width: 195, height: 66)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(OnboardingTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(OnboardingTheme.border, lineWidth: 1)
        )
    }
}
