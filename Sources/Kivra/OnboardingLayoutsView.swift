import SwiftUI

struct OnboardingLayoutsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var model: OnboardingModel
    let dismiss: () -> Void
    @Binding var isTapThresholdExpanded: Bool

    private let applicationName = ApplicationIdentity.current.displayName

    var body: some View {
        VStack(spacing: 0) {
            Text("Choose your layouts")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(-0.5)
                .padding(.top, 12)

            Text("Assign one to each Shift key.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.50))
                .padding(.top, 6)

            VStack(spacing: 8) {
                layoutPicker(title: "Left Shift", selection: $model.selectedLeftID)
                layoutPicker(
                    title: "Right Shift",
                    selection: $model.selectedRightID,
                    excluding: model.selectedLeftID
                )
            }
            .frame(maxWidth: 420)
            .padding(.top, 12)

            tapThresholdConfiguration
                .frame(maxWidth: 420)
                .padding(.top, 8)

            launchAtLoginConfiguration
                .frame(maxWidth: 420)
                .padding(.top, 8)

            Group {
                if model.sources.count < 2 {
                    Text("\(applicationName) needs two enabled keyboard layouts.")
                }
            }
            .font(.system(size: 12, design: .rounded))
            .foregroundStyle(OnboardingTheme.accent)
            .padding(.top, 10)

            Spacer()

            HStack(spacing: 10) {
                OnboardingSecondaryButton(
                    title: model.isSettingsMode ? "Cancel" : "Back",
                    action: model.isSettingsMode ? dismiss : model.goBack
                )
                OnboardingPrimaryButton(
                    title: model.isSettingsMode ? "Save Changes" : "Start \(applicationName)",
                    symbol: "checkmark",
                    action: model.finish
                )
                .disabled(!model.canConfigureLayouts)
                .opacity(model.canConfigureLayouts ? 1 : 0.42)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 42)
    }

    private var tapThresholdConfiguration: some View {
        VStack(spacing: 0) {
            Button {
                isTapThresholdExpanded.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.accent)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(OnboardingTheme.accent.opacity(0.10))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tap threshold")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("\(model.thresholdMilliseconds) ms")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.42))
                            .contentTransition(.numericText())
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.42))
                        .rotationEffect(.degrees(isTapThresholdExpanded ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tap threshold")
            .accessibilityValue(
                "\(model.thresholdMilliseconds) milliseconds, "
                    + (isTapThresholdExpanded ? "expanded" : "collapsed")
            )
            .accessibilityHint(
                isTapThresholdExpanded
                    ? "Hides optional tap timing settings"
                    : "Shows optional tap timing settings"
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Maximum time Shift can be held")
                    Spacer()
                    Text("\(model.thresholdMilliseconds) ms")
                        .foregroundStyle(OnboardingTheme.accent)
                        .contentTransition(.numericText())
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))

                Slider(
                    value: Binding(
                        get: { Double(model.thresholdMilliseconds) },
                        set: { model.thresholdMilliseconds = Int($0.rounded()) }
                    ),
                    in: 100...500,
                    step: 50
                )
                .tint(OnboardingTheme.accent)
                .accessibilityLabel("Tap threshold in milliseconds")

                HStack {
                    Text("Quick")
                    Spacer()
                    Text("Relaxed")
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.32))
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 10)
            .frame(height: isTapThresholdExpanded ? 72 : 0, alignment: .top)
            .clipped()
            .opacity(isTapThresholdExpanded ? 1 : 0)
            .allowsHitTesting(isTapThresholdExpanded)
            .accessibilityHidden(!isTapThresholdExpanded)
        }
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(OnboardingTheme.panel)
        )
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(OnboardingTheme.border, lineWidth: 1)
        )
        .animation(
            reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.88),
            value: isTapThresholdExpanded
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.16),
            value: model.thresholdMilliseconds
        )
    }

    private var launchAtLoginConfiguration: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $model.isLaunchAtLoginEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.accent)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(OnboardingTheme.accent.opacity(0.10))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open Kivra at login")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }

                    Spacer()

                    Text(model.isLaunchAtLoginEnabled ? "ON" : "OFF")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(
                            model.isLaunchAtLoginEnabled
                                ? OnboardingTheme.accent
                                : .white.opacity(0.38)
                        )
                }
            }
            .toggleStyle(.switch)
            .tint(OnboardingTheme.accent)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .disabled(!model.isLaunchAtLoginAvailable)
            .accessibilityLabel("Open Kivra at login")
            .accessibilityHint(
                model.isLaunchAtLoginAvailable
                    ? "Applies when you save changes"
                    : "Available in the installed app"
            )

            if model.launchAtLoginRequiresApproval {
                launchAtLoginStatus(
                    symbol: "exclamationmark.circle.fill",
                    "Allow it in Login Items.",
                    color: Color(red: 1.0, green: 0.68, blue: 0.30),
                    action: model.openLoginItemsSettings
                )
            } else if let error = model.launchAtLoginError {
                launchAtLoginStatus(
                    symbol: "exclamationmark.triangle.fill",
                    error,
                    color: OnboardingTheme.accent
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(OnboardingTheme.panel)
        )
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(OnboardingTheme.border, lineWidth: 1)
        )
    }

    private func launchAtLoginStatus(
        symbol: String,
        _ message: String,
        color: Color,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)

            Text(message)
                .lineLimit(1)

            Spacer()

            if let action {
                Button("Open Settings", action: action)
                    .buttonStyle(.plain)
                    .foregroundStyle(color)
            }
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.50))
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Color.white.opacity(0.025))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
        }
    }

    private func layoutPicker(
        title: String,
        selection: Binding<String>,
        excluding excludedID: String? = nil
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: "shift.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(OnboardingTheme.accent.opacity(0.10))
                )

            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Spacer()

            Picker(title, selection: selection) {
                if model.sources.isEmpty {
                    Text("No layouts found").tag("")
                }
                ForEach(model.sources.filter { $0.id != excludedID }) { source in
                    Text(source.name).tag(source.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 178)
        }
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
