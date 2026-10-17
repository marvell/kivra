import SwiftUI

/// The Open at Login switch with its approval and error states, shared by
/// setup and Settings.
struct LaunchAtLoginToggle<Label: View>: View {
    @Binding var isOn: Bool
    let isAvailable: Bool
    let requiresApproval: Bool
    let error: String?
    let openLoginItemsSettings: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Toggle(isOn: $isOn) { label }
            .disabled(!isAvailable)
            .help(isAvailable ? "" : "Available in the installed app")

        if requiresApproval {
            Button("Allow it in Login Items…", action: openLoginItemsSettings)
                .buttonStyle(.link)
        } else if let error {
            SwiftUI.Label(error, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}
