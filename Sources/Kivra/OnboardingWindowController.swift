import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let model: OnboardingModel
    private let onClose: () -> Void
    private let onDismiss: () -> Void
    private var isCompleting = false
    private var isConfirmingQuit = false

    init(
        model: OnboardingModel,
        shiftTaps: ShiftTapFeedback,
        onClose: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.model = model
        self.onClose = onClose
        self.onDismiss = onDismiss

        let hostingController = NSHostingController(
            rootView: OnboardingView(model: model, shiftTaps: shiftTaps)
        )
        hostingController.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to \(ApplicationIdentity.current.displayName)"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        model.refreshLaunchAtLogin()
        model.startPermissionObservation()
        showCentered()
    }

    /// Whether setup is in front on the step where people try their layouts.
    var isShowingShiftKeys: Bool {
        window?.isKeyWindow == true && model.step == .layouts
    }

    func updateSources(_ sources: [InputSource]) {
        model.updateSources(sources)
    }

    func completeAndClose() {
        isCompleting = true
        close()
    }

    /// Escape closes setup, like the Close button.
    override func cancelOperation(_ sender: Any?) {
        window?.performClose(sender)
    }

    /// Kivra quits when setup closes unfinished, so it asks first.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !isCompleting else { return true }
        guard !isConfirmingQuit else { return false }
        isConfirmingQuit = true

        let applicationName = ApplicationIdentity.current.displayName
        let alert = NSAlert()
        alert.messageText = "Quit \(applicationName)?"
        alert.informativeText =
            "\(applicationName) can switch layouts once setup is finished. "
            + "Next time you open it, setup starts again."
        alert.addButton(withTitle: "Quit")
        // Escape picks Cancel and keeps setup open.
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: sender) { [weak self] response in
            self?.isConfirmingQuit = false
            if response == .alertFirstButtonReturn {
                sender.close()
            }
        }
        return false
    }

    func windowWillClose(_ notification: Notification) {
        model.stopPermissionObservation()
        onClose()
        if !isCompleting {
            onDismiss()
        }
    }
}
