import SwiftUI

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var model: OnboardingModel
    let shiftTaps: ShiftTapFeedback

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Group {
                    switch model.step {
                    case .welcome:
                        OnboardingWelcomeView(model: model)
                    case .permission:
                        OnboardingPermissionView(model: model)
                    case .layouts:
                        OnboardingLayoutsView(model: model, shiftTaps: shiftTaps)
                    }
                }
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(model.step)
                .transition(pageTransition)
            }
            .clipped()
            .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.24), value: model.step)

            footer
        }
        .frame(width: 560, height: 540)
        .background(alignment: .top) { glow }
    }

    /// Tints the top of the window with the system accent color.
    private var glow: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.14), .clear],
                startPoint: .top,
                endPoint: .center
            )
            EllipticalGradient(
                colors: [Color.accentColor.opacity(0.22), .clear],
                center: .top,
                endRadiusFraction: 0.5
            )
            .frame(height: 360)
            .offset(y: -60)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var footer: some View {
        ZStack {
            HStack {
                if model.step != .welcome {
                    Button(action: model.goBack) {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
            stepIndicator
        }
        .frame(height: 20)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingModel.Step.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step == model.step ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: step == model.step ? 16 : 6, height: 6)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Step \(model.step.rawValue + 1) of \(OnboardingModel.Step.allCases.count)"
        )
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else {
            return .opacity
        }
        let distance = 24.0
        let insertionOffset = model.navigationDirection == .forward ? distance : -distance
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: insertionOffset)),
            removal: .opacity.combined(with: .offset(x: -insertionOffset))
        )
    }
}

/// The main action of a setup step, placed where the eye lands after reading.
struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(minWidth: 200)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.extraLarge)
        .keyboardShortcut(.defaultAction)
    }
}

/// The title and explanation shared by every setup step.
struct OnboardingHeader: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.largeTitle.weight(.bold))
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
    }
}

struct OnboardingLaunchAtLoginToggle: View {
    @ObservedObject var model: OnboardingModel

    private let applicationName = ApplicationIdentity.current.displayName

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            LaunchAtLoginToggle(
                isOn: $model.isLaunchAtLoginEnabled,
                isAvailable: model.isLaunchAtLoginAvailable,
                requiresApproval: model.launchAtLoginRequiresApproval,
                error: model.launchAtLoginError,
                openLoginItemsSettings: model.openLoginItemsSettings
            ) {
                Text("Open \(applicationName) at login")
            }
            .toggleStyle(.checkbox)
        }
    }
}
