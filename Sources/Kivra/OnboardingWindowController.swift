import AppKit
import SwiftUI

private final class OnboardingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let model: OnboardingModel
    private let onDismiss: () -> Void
    private var isCompleting = false

    init(
        model: OnboardingModel,
        onDismiss: @escaping () -> Void
    ) {
        self.model = model
        self.onDismiss = onDismiss

        let window = OnboardingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 480),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let contentView = OnboardingView(
            model: model,
            dismiss: { [weak window] in window?.close() }
        )
        .preferredColorScheme(.dark)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 18
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true

        let applicationName = ApplicationIdentity.current.displayName
        window.title =
            model.mode == .firstLaunch
            ? "Welcome to \(applicationName)"
            : "\(applicationName) Settings"
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.contentView = hostingView
        window.center()

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
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func updateSources(_ sources: [InputSource]) {
        model.updateSources(sources)
    }

    func completeAndClose() {
        isCompleting = true
        close()
    }

    func windowWillClose(_ notification: Notification) {
        model.stopPermissionObservation()
        if !isCompleting {
            onDismiss()
        }
    }
}
