import SwiftUI

struct OnboardingLayoutsView: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject var shiftTaps: ShiftTapFeedback

    private let applicationName = ApplicationIdentity.current.displayName

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            OnboardingHeader(
                title: "Choose Your Layouts",
                message: "Click a layout name to change it."
            )

            ShiftKeysView(
                sources: model.sources,
                leftID: $model.selectedLeftID,
                rightID: $model.selectedRightID,
                pressedSide: shiftTaps.highlightedSide,
                canSwap: model.canConfigureLayouts,
                swap: model.swapLayouts
            )
            .frame(maxWidth: 440)
            .padding(.top, 28)

            if model.sources.count < 2 {
                MissingLayoutsNotice()
                    .padding(.top, 20)
            } else {
                tryItChecklist
                    .padding(.top, 20)
            }

            Spacer()

            VStack(spacing: 14) {
                OnboardingLaunchAtLoginToggle(model: model)
                OnboardingPrimaryButton(title: "Start Using \(applicationName)", action: model.finish)
                    .disabled(!model.canConfigureLayouts)
            }
            .padding(.bottom, 20)
        }
    }

    /// Invites the person to try both keys and confirms each one works.
    private var tryItChecklist: some View {
        HStack(spacing: 16) {
            Text("Try it:")
                .foregroundStyle(.secondary)
            checklistItem(.left)
            checklistItem(.right)
        }
        .animation(.easeOut(duration: 0.2), value: shiftTaps.triedSides)
        // A key counts as tried only with the layout it shows now.
        .onAppear { shiftTaps.forgetTries() }
        .onChange(of: model.selectedLeftID) { shiftTaps.forgetTries(on: [.left]) }
        .onChange(of: model.selectedRightID) { shiftTaps.forgetTries(on: [.right]) }
    }

    private func checklistItem(_ side: ShiftSide) -> some View {
        let isDone = shiftTaps.triedSides.contains(side)
        return Label {
            Text("Tap \(side.title)")
        } icon: {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isDone ? Color.green : Color.secondary)
        }
        .accessibilityValue(isDone ? "Done" : "Not yet")
    }
}
