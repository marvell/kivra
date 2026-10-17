import SwiftUI

struct OnboardingPermissionView: View {
    @ObservedObject var model: OnboardingModel

    private let applicationName = ApplicationIdentity.current.displayName

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            SymbolTile(
                systemName: model.accessibilityGranted ? "checkmark" : "hand.raised.fill",
                color: model.accessibilityGranted ? .green : .blue,
                size: 72
            )
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .animation(.easeOut(duration: 0.2), value: model.accessibilityGranted)

            OnboardingHeader(
                title: model.accessibilityGranted ? "Access Granted" : "Allow Accessibility Access",
                message: model.accessibilityGranted
                    ? "\(applicationName) can now recognize Shift taps."
                    : "\(applicationName) uses it only to recognize Shift taps.\n"
                        + "It never reads or stores what you type."
            )
            .padding(.top, 16)

            if !model.accessibilityGranted {
                instructions
                    .padding(.top, 24)
            }

            Spacer()

            if !model.accessibilityGranted {
                callToAction
                    .padding(.bottom, 20)
            }
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 10) {
            instruction(1, "Click **Allow Access**, then **Open System Settings**.")
            instruction(2, "Turn on **\(applicationName)** in the Accessibility list.")
            instruction(3, "Come back here. Setup continues on its own.")
        }
        .padding(16)
        .frame(maxWidth: 400, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func instruction(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var callToAction: some View {
        if model.hasRequestedAccessibility {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Waiting for access…")
                        .foregroundStyle(.secondary)
                }
                // macOS shows its permission prompt only once, so offer a
                // direct path for people who dismissed it.
                OnboardingPrimaryButton(
                    title: "Open System Settings",
                    action: model.openAccessibilitySettings
                )
            }
        } else {
            OnboardingPrimaryButton(title: "Allow Access", action: model.requestAccessibility)
        }
    }
}
