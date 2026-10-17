import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var shiftTaps: ShiftTapFeedback

    private let applicationName = ApplicationIdentity.current.displayName

    var body: some View {
        // The window fits the whole form when the screen is tall enough and
        // scrolls on shorter screens.
        ViewThatFits(in: .vertical) {
            form
                .scrollDisabled(true)
                .fixedSize(horizontal: false, vertical: true)
            form
        }
        .frame(width: 500)
        .frame(maxHeight: Self.maximumHeight)
    }

    private var form: some View {
        Form {
            if !model.accessibilityGranted {
                permissionSection
            }
            layoutsSection
            tapSection
            generalSection
            aboutSection
        }
        .formStyle(.grouped)
    }

    /// The tallest content that keeps the window and its title bar on screen.
    private static var maximumHeight: CGFloat {
        guard let screen = NSScreen.main else { return .infinity }
        let titleBarHeight = NSWindow.frameRect(
            forContentRect: .zero,
            styleMask: [.titled, .closable]
        ).height
        return screen.visibleFrame.height - titleBarHeight
    }

    private var permissionSection: some View {
        Section {
            Label {
                Text("Accessibility access required")
                Text("\(applicationName) uses it only to recognize Shift taps.")
            } icon: {
                SymbolTile(systemName: "hand.raised.fill", color: .blue)
            }

            HStack {
                Button("Open Privacy & Security", action: model.openAccessibilitySettings)
                Spacer()
                Button("Grant Access", action: model.requestAccessibility)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var layoutsSection: some View {
        Section {
            ShiftKeysView(
                sources: model.sources,
                leftID: $model.selectedLeftID,
                rightID: $model.selectedRightID,
                pressedSide: shiftTaps.highlightedSide,
                canSwap: model.canConfigureLayouts,
                swap: model.swapLayouts
            )
            .padding(.vertical, 8)

            if model.sources.count < 2 {
                MissingLayoutsNotice()
            }
        } footer: {
            Text("Tap a Shift key to try it.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    private var tapSection: some View {
        Section {
            LabeledContent {
                Slider(
                    value: Binding(
                        get: { Double(model.thresholdMilliseconds) },
                        set: { model.thresholdMilliseconds = Int($0.rounded()) }
                    ),
                    in: Double(
                        LayoutSelection.thresholdRange.lowerBound)...Double(
                            LayoutSelection.thresholdRange.upperBound
                        ),
                    step: Double(LayoutSelection.thresholdStep)
                ) {
                    Text("Tap threshold")
                } minimumValueLabel: {
                    Text("Quick")
                } maximumValueLabel: {
                    Text("Relaxed")
                }
                .labelsHidden()
                .frame(width: 220)
            } label: {
                Label {
                    Text("Tap length")
                    Text("Up to \(model.thresholdMilliseconds) ms")
                        .monospacedDigit()
                } icon: {
                    SymbolTile(systemName: "timer", color: .orange)
                }
            }
            .accessibilityLabel("Tap threshold in milliseconds")
        } footer: {
            Text("Increase it if quick taps are missed.")
                .foregroundStyle(.secondary)
        }
    }

    private var generalSection: some View {
        Section {
            LaunchAtLoginToggle(
                isOn: Binding(
                    get: { model.isLaunchAtLoginEnabled },
                    set: { model.setLaunchAtLoginEnabled($0) }
                ),
                isAvailable: model.isLaunchAtLoginAvailable,
                requiresApproval: model.launchAtLoginRequiresApproval,
                error: model.launchAtLoginError,
                openLoginItemsSettings: model.openLoginItemsSettings
            ) {
                Label {
                    Text("Open \(applicationName) at login")
                } icon: {
                    SymbolTile(systemName: "power", color: .green)
                }
            }

            Toggle(
                isOn: Binding(
                    get: { model.hideInputSourceIndicator },
                    set: { model.setInputSourceIndicatorHidden($0) }
                )
            ) {
                Label {
                    Text("Hide input source indicator")
                    Text(
                        "Hides the language popup near the cursor. May reduce typing delays "
                            + "after switching. Uses an undocumented macOS setting."
                    )
                } icon: {
                    SymbolTile(systemName: "character.cursor.ibeam", color: .purple)
                }
            }
            if let error = model.inputSourceIndicatorError {
                errorLabel(error)
            }
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent {
                if let checkForUpdates = model.onCheckForUpdates {
                    Button("Check for Updates…", action: checkForUpdates)
                }
            } label: {
                Label {
                    Text(applicationName)
                    if let version = ApplicationIdentity.current.version {
                        Text("Version \(version)")
                    }
                } icon: {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 20, height: 20)
                }
            }
        }
    }

    private func errorLabel(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
    }
}
