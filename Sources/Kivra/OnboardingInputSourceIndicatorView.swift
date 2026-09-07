import SwiftUI

struct OnboardingInputSourceIndicatorView: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $model.hideInputSourceIndicator) {
                HStack(spacing: 12) {
                    Image(systemName: "character.cursor.ibeam")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.accent)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(OnboardingTheme.accent.opacity(0.10))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hide input source indicator")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("Optional workaround for typing delays")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.50))
                    }

                    Spacer()
                }
            }
            .toggleStyle(.switch)
            .tint(OnboardingTheme.accent)
            .accessibilityLabel("Hide the macOS input source indicator")
            .accessibilityHint(
                "Reflects your macOS setting. Changes apply to all apps when you save."
            )

            Text(
                "Hides the language popup near the cursor in all apps. "
                    + "May reduce delays after switching layouts. "
                    + "Turning this off shows the indicator again."
            )
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(.white.opacity(0.60))
            .fixedSize(horizontal: false, vertical: true)

            Text("Uses an undocumented macOS setting. Some apps may need to be restarted.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)

            if let error = model.inputSourceIndicatorError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(OnboardingTheme.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
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
