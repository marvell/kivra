import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.openURL) private var openURL

    private let applicationName = ApplicationIdentity.current.displayName

    var body: some View {
        Form {
            if !model.accessibilityGranted {
                permissionSection
            }
            layoutsSection
            tapThresholdSection
            generalSection
            advancedSection
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .frame(minHeight: 300, idealHeight: 560)
    }

    private var permissionSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Accessibility access required")
                    Text(
                        "\(applicationName) uses it only to recognize Shift taps. "
                            + "It never reads or stores what you type."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
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
            layoutPicker("Left Shift", selection: $model.selectedLeftID)
            layoutPicker(
                "Right Shift",
                selection: $model.selectedRightID,
                excluding: model.selectedLeftID
            )

            if model.sources.count < 2 {
                HStack {
                    Label(
                        "\(applicationName) needs two enabled keyboard layouts.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                    Spacer()
                    Button("Open Keyboard Settings") {
                        openURL(Self.keyboardSettingsURL)
                    }
                }
            }
        } header: {
            HStack {
                Text("Layouts")
                Spacer()
                Button(action: model.swapLayouts) {
                    Label("Swap", systemImage: "arrow.up.arrow.down")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(!model.canConfigureLayouts)
                .help("Swap layouts")
            }
        }
    }

    private var tapThresholdSection: some View {
        Section {
            LabeledContent("Maximum hold time") {
                Text("\(model.thresholdMilliseconds) ms")
                    .monospacedDigit()
            }
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
            .accessibilityLabel("Tap threshold in milliseconds")
        } header: {
            Text("Tap Threshold")
        } footer: {
            Text("A Shift press shorter than this switches layouts. Increase it if quick taps are missed.")
                .foregroundStyle(.secondary)
        }
    }

    private var generalSection: some View {
        Section("General") {
            Toggle(
                "Open \(applicationName) at login",
                isOn: Binding(
                    get: { model.isLaunchAtLoginEnabled },
                    set: { model.setLaunchAtLoginEnabled($0) }
                )
            )
            .disabled(!model.isLaunchAtLoginAvailable)
            .help(model.isLaunchAtLoginAvailable ? "" : "Available in the installed app")

            if model.launchAtLoginRequiresApproval {
                HStack {
                    Label("Allow it in Login Items.", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Open Login Items", action: model.openLoginItemsSettings)
                }
            }
            if let error = model.launchAtLoginError {
                errorLabel(error)
            }
        }
    }

    private var advancedSection: some View {
        Section {
            Toggle(
                isOn: Binding(
                    get: { model.hideInputSourceIndicator },
                    set: { model.setInputSourceIndicatorHidden($0) }
                )
            ) {
                Text("Hide input source indicator")
                Text(
                    "Hides the language popup near the cursor in all apps. "
                        + "May reduce delays after switching layouts."
                )
            }
            if let error = model.inputSourceIndicatorError {
                errorLabel(error)
            }
        } header: {
            Text("Advanced")
        } footer: {
            Text("Uses an undocumented macOS setting. Some apps may need to be restarted.")
                .foregroundStyle(.secondary)
        }
    }

    private func layoutPicker(
        _ title: String,
        selection: Binding<String>,
        excluding excludedID: String? = nil
    ) -> some View {
        Picker(selection: selection) {
            if model.sources.isEmpty {
                Text("No layouts found").tag("")
            }
            ForEach(model.sources.filter { $0.id != excludedID }) { source in
                Text(source.name).tag(source.id)
            }
        } label: {
            Label(title, systemImage: "shift")
        }
    }

    private func errorLabel(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
    }

    private static let keyboardSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"
    )!
}
