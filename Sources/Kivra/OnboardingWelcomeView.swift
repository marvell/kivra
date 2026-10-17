import SwiftUI

struct OnboardingWelcomeView: View {
    @ObservedObject var model: OnboardingModel

    private let applicationName = ApplicationIdentity.current.displayName

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .accessibilityHidden(true)

            OnboardingHeader(
                title: "Welcome to \(applicationName)",
                message: "Give each keyboard layout its own Shift key.\n"
                    + "One tap, and you always know where you’ll land."
            )
            .padding(.top, 12)

            SwitchingDemo(content: SwitchingDemo.Content(model: model))
                .frame(maxWidth: 400)
                .padding(.top, 24)

            Spacer()

            OnboardingPrimaryButton(title: "Get Started", action: model.continueFromWelcome)
                .padding(.bottom, 20)
        }
    }
}

/// Taps each Shift key in turn and types a word in its layout, showing how
/// Kivra switches layouts.
private struct SwitchingDemo: View {
    /// The layouts and words shown, worked out once per selection rather than
    /// on every typed character.
    struct Content: Equatable {
        var leftName: String
        var rightName: String
        var leftGreeting: String
        var rightGreeting: String
        var hasRightLayout: Bool

        @MainActor
        init(model: OnboardingModel) {
            leftName = model.selectedLeftName
            rightName = model.selectedRightName
            leftGreeting = model.selectedLeftGreeting
            rightGreeting = model.selectedRightGreeting
            hasRightLayout = model.canConfigureLayouts
        }

        var accessibilityLabel: String {
            let left = "Example: tap Left Shift and type \(leftGreeting) in \(leftName)"
            guard hasRightLayout else {
                return left + ". Add another layout to use Right Shift."
            }
            return left + ", then tap Right Shift and type \(rightGreeting) in \(rightName)."
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let content: Content
    @State private var pressedSide: ShiftSide?
    @State private var activeSide: ShiftSide = .left
    @State private var leftText = ""
    @State private var rightText = ""

    var body: some View {
        VStack(spacing: 14) {
            textField(layoutName: activeSide == .left ? content.leftName : content.rightName)
            HStack(spacing: 12) {
                ShiftKeycap(
                    side: .left,
                    layoutName: content.leftName,
                    isPressed: pressedSide == .left
                )
                ShiftKeycap(
                    side: .right,
                    layoutName: content.rightName,
                    isPressed: pressedSide == .right
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
        // Restarts when the layouts change so the words always match the keys.
        .task(id: content) {
            await play()
        }
    }

    private func textField(layoutName: String) -> some View {
        HStack(spacing: 2) {
            Text(typedText)
                .lineLimit(1)
            Cursor(isBlinking: !reduceMotion)
            Spacer(minLength: 12)
            layoutBadge(layoutName)
        }
        .font(.title2)
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
    }

    /// Mirrors the input source indicator macOS shows near the cursor.
    private func layoutBadge(_ layoutName: String) -> some View {
        Text(layoutName)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.accentColor.gradient))
            .id(activeSide)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    private var typedText: String {
        rightText.isEmpty ? leftText : leftText + " " + rightText
    }

    private func play() async {
        guard !reduceMotion else {
            activeSide = .right
            leftText = content.leftGreeting
            rightText = content.rightGreeting
            return
        }
        do {
            while !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.2)) {
                    leftText = ""
                    rightText = ""
                }
                try await Task.sleep(for: .milliseconds(700))
                try await tap(.left)
                try await type(content.leftGreeting) { leftText.append($0) }
                try await Task.sleep(for: .milliseconds(600))
                try await tap(.right)
                try await type(content.rightGreeting) { rightText.append($0) }
                try await Task.sleep(for: .milliseconds(2000))
            }
        } catch {
            return
        }
    }

    private func tap(_ side: ShiftSide) async throws {
        pressedSide = side
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            activeSide = side
        }
        try await Task.sleep(for: .milliseconds(350))
        pressedSide = nil
        try await Task.sleep(for: .milliseconds(250))
    }

    private func type(_ word: String, append: (Character) -> Void) async throws {
        for character in word {
            append(character)
            try await Task.sleep(for: .milliseconds(110))
        }
    }
}

private struct Cursor: View {
    let isBlinking: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let isVisible =
                !isBlinking || Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.accentColor)
                .frame(width: 2, height: 24)
                .opacity(isVisible ? 1 : 0)
        }
    }
}
