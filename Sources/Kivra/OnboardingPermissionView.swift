import SwiftUI

struct OnboardingPermissionView: View {
    @ObservedObject var model: OnboardingModel
    let dismiss: () -> Void

    private let applicationName = ApplicationIdentity.current.displayName

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            featureIcon(
                model.accessibilityGranted ? "checkmark" : "hand.raised.fill",
                color: model.accessibilityGranted ? .green : OnboardingTheme.accent
            )

            Text(model.accessibilityGranted ? "Access granted" : "Allow Accessibility access")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(-0.5)
                .padding(.top, 22)

            Text(
                model.accessibilityGranted
                    ? "\(applicationName) can now recognize a quick Shift tap."
                    : "\(applicationName) uses it only to recognize Shift taps.\nIt never reads or stores what you type."
            )
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(.white.opacity(0.50))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.top, 11)

            Spacer()

            HStack(spacing: 10) {
                OnboardingSecondaryButton(
                    title: model.isSettingsMode ? "Cancel" : "Back",
                    action: model.isSettingsMode ? dismiss : model.goBack
                )
                OnboardingPrimaryButton(
                    title: "Grant Access",
                    symbol: "hand.raised.fill",
                    action: model.requestAccessibility
                )
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 30)
        }
    }

    private func featureIcon(_ symbol: String, color: Color) -> some View {
        ZStack {
            Circle().fill(color.opacity(0.11))
            Circle().stroke(color.opacity(0.22), lineWidth: 1)
            Image(systemName: symbol)
                .font(.system(size: 29, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 80, height: 80)
    }
}
