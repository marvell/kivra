import SwiftUI

/// Both Shift keys side by side, as on the keyboard. Each key's label is a
/// menu for choosing its layout, and the key lights up when it is tapped.
struct ShiftKeysView: View {
    let sources: [InputSource]
    @Binding var leftID: String
    @Binding var rightID: String
    let pressedSide: ShiftSide?
    let canSwap: Bool
    let swap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            column(side: .left, selection: $leftID)
            Button(action: swap) {
                Image(systemName: "arrow.left.arrow.right")
            }
            .buttonStyle(.borderless)
            .disabled(!canSwap)
            .help("Swap layouts")
            .accessibilityLabel("Swap layouts")
            column(side: .right, selection: $rightID, excluding: leftID)
        }
    }

    private func column(
        side: ShiftSide,
        selection: Binding<String>,
        excluding excludedID: String? = nil
    ) -> some View {
        let layoutName = name(for: selection.wrappedValue, excluding: excludedID)
        let choices = sources.filter { $0.id != excludedID }
        return ShiftKeycap(side: side, isPressed: pressedSide == side) {
            Menu {
                Picker(side.title, selection: selection) {
                    // Every selection needs a matching tag, including one
                    // that is missing or taken by the other key.
                    if !choices.contains(where: { $0.id == selection.wrappedValue }) {
                        Text(layoutName).tag(selection.wrappedValue)
                    }
                    ForEach(choices) { source in
                        Text(source.name).tag(source.id)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                Text(layoutName)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(sources.isEmpty)
            .accessibilityLabel("\(side.title) layout")
            .accessibilityValue(layoutName)
        }
        .accessibilityLabel(side.title)
        .frame(maxWidth: .infinity)
    }

    private func name(for id: String, excluding excludedID: String?) -> String {
        guard id != excludedID, let source = sources.first(where: { $0.id == id }) else {
            return sources.isEmpty ? "No layouts found" : "—"
        }
        return source.name
    }
}

/// Explains that Kivra needs two layouts and links to where people add one.
struct MissingLayoutsNotice: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 6) {
            Label(
                "\(ApplicationIdentity.current.displayName) needs two enabled keyboard layouts.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
            Button("Open Keyboard Settings") {
                openURL(Self.keyboardSettingsURL)
            }
            .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity)
    }

    private static let keyboardSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"
    )!
}

/// A Shift key drawn like a Mac keycap and labeled with its layout.
struct ShiftKeycap<Label: View>: View {
    let side: ShiftSide
    var isPressed = false
    @ViewBuilder let label: Label

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var alignment: HorizontalAlignment {
        side == .left ? .leading : .trailing
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            label
                .font(.title3.weight(.semibold))
                .foregroundStyle(isPressed ? Color.accentColor : .primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            legend
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(height: 76)
        .background(keycap)
        .offset(y: isPressed && !reduceMotion ? 1.5 : 0)
        .animation(.easeOut(duration: 0.12), value: isPressed)
        .accessibilityElement(children: .contain)
        .accessibilityValue(isPressed ? "Tapped" : "")
    }

    /// Mirrors the "⇧ shift" legend printed on Mac keyboards.
    private var legend: some View {
        HStack(spacing: 3) {
            if side == .left {
                shiftSymbol
                Text("shift")
            } else {
                Text("shift")
                shiftSymbol
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(isPressed ? Color.accentColor : .secondary)
    }

    private var shiftSymbol: some View {
        Image(systemName: isPressed ? "shift.fill" : "shift")
            .foregroundStyle(Color.accentColor)
    }

    private var keycap: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return
            shape
            .fill(keyColor.gradient)
            .overlay {
                shape.fill(Color.accentColor.opacity(isPressed ? 0.22 : 0))
            }
            .overlay {
                shape.strokeBorder(
                    isPressed ? Color.accentColor : Color.primary.opacity(0.12),
                    lineWidth: isPressed ? 2 : 0.5
                )
            }
            // A soft glow makes the tapped key easy to spot at a glance.
            .shadow(
                color: Color.accentColor.opacity(isPressed ? 0.55 : 0),
                radius: 12
            )
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.5 : 0.14),
                radius: 0,
                y: isPressed ? 0.5 : 2
            )
            .shadow(
                color: .black.opacity(isPressed ? 0 : 0.08),
                radius: 6,
                y: 3
            )
    }

    private var keyColor: Color {
        colorScheme == .dark ? Color(white: 0.24) : .white
    }
}

extension ShiftKeycap where Label == Text {
    init(side: ShiftSide, layoutName: String, isPressed: Bool = false) {
        self.init(side: side, isPressed: isPressed) { Text(layoutName) }
    }
}

extension ShiftSide {
    var title: String {
        switch self {
        case .left: "Left Shift"
        case .right: "Right Shift"
        }
    }
}
