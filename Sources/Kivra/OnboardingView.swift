import SwiftUI

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var model: OnboardingModel
    let dismiss: () -> Void
    @State private var isExitHovered = false
    @State private var isTapThresholdExpanded = false

    private let applicationName = ApplicationIdentity.current.displayName
    private let appVersion =
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String

    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.058, blue: 0.07)
            RadialGradient(
                colors: [OnboardingTheme.accent.opacity(0.09), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 360
            )

            VStack(spacing: 0) {
                brand
                if !model.isSettingsMode {
                    progress
                }

                ZStack {
                    Group {
                        switch model.step {
                        case .welcome:
                            OnboardingWelcomeView(model: model)
                        case .permission:
                            OnboardingPermissionView(model: model, dismiss: dismiss)
                        case .layouts:
                            OnboardingLayoutsView(
                                model: model,
                                dismiss: dismiss,
                                isTapThresholdExpanded: $isTapThresholdExpanded
                            )
                        }
                    }
                    .id(model.step)
                    .transition(pageTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.24), value: model.step)
            }
            .padding(.top, 27)

            VStack {
                HStack {
                    Spacer()
                    exitButton
                }
                Spacer()
            }
            .padding(.top, 14)
            .padding(.trailing, 14)
        }
        .frame(minWidth: 620, minHeight: 480)
        .foregroundStyle(.white)
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else {
            return .opacity
        }
        let distance = 28.0
        let insertionOffset = model.navigationDirection == .forward ? distance : -distance
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: insertionOffset)),
            removal: .opacity.combined(with: .offset(x: -insertionOffset))
        )
    }

    private var exitButton: some View {
        Button(action: dismiss) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isExitHovered ? 0.08 : 0.025))
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(isExitHovered ? 0.62 : 0.24))
            }
            .frame(width: 26, height: 26)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .help(model.isSettingsMode ? "Close settings" : "Close setup")
        .accessibilityLabel(model.isSettingsMode ? "Close settings" : "Close setup")
        .onHover { isExitHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isExitHovered)
    }

    private var brand: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(OnboardingTheme.accent)
                Image(systemName: "command")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .frame(width: 25, height: 25)

            Text(applicationName)
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            if let appVersion {
                Text("v\(appVersion)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.28))
                    .accessibilityLabel("Version \(appVersion)")
            }
        }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingModel.Step.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(
                        step == model.step
                            ? OnboardingTheme.accent
                            : Color.white.opacity(0.13)
                    )
                    .frame(width: step == model.step ? 18 : 6, height: 6)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.step)
        .padding(.top, 17)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(model.step.rawValue + 1) of \(OnboardingModel.Step.allCases.count)")
    }
}
