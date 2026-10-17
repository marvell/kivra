import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let model: SettingsModel
    private let onClose: () -> Void

    init(model: SettingsModel, shiftTaps: ShiftTapFeedback, onClose: @escaping () -> Void) {
        self.model = model
        self.onClose = onClose

        let hostingController = NSHostingController(
            rootView: SettingsView(model: model, shiftTaps: shiftTaps)
        )
        hostingController.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: hostingController)
        window.title = "\(ApplicationIdentity.current.displayName) Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        model.refresh()
        showCentered()
    }

    var isShowingShiftKeys: Bool {
        window?.isKeyWindow == true
    }

    func updateSources(_ sources: [InputSource]) {
        model.updateSources(sources)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        // People often return from System Settings after granting access or
        // approving the login item.
        model.refresh()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
