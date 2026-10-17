import AppKit

enum WindowPlacement {
    /// How far above the screen's center the window appears, as a share of the
    /// screen's height. Slightly raised windows sit closer to eye level.
    static let raise: CGFloat = 0.2

    /// Centers a window horizontally and raises it above the vertical center,
    /// keeping its title bar on screen.
    static func origin(for size: NSSize, in visibleFrame: NSRect) -> NSPoint {
        let freeHeight = max(visibleFrame.height - size.height, 0)
        let gapAbove = max(freeHeight / 2 - visibleFrame.height * raise, 0)
        return NSPoint(
            x: (visibleFrame.midX - size.width / 2).rounded(),
            y: (visibleFrame.maxY - gapAbove - size.height).rounded()
        )
    }
}

extension NSWindowController {
    /// Shows the window centered on the screen with the pointer, where the
    /// person just clicked the menu bar item. An open window stays where the
    /// person moved it.
    @MainActor
    func showCentered() {
        if let window, !window.isVisible {
            window.centerOnActiveScreen()
        }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

extension NSWindow {
    @MainActor
    fileprivate func centerOnActiveScreen() {
        // SwiftUI sizes a hosted window only after it appears, and its content
        // can change while hidden, so size it before centering.
        if let contentView = contentViewController?.view {
            setContentSize(contentView.fittingSize)
            layoutIfNeeded()
        }
        let mouseLocation = NSEvent.mouseLocation
        let screen =
            NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        guard let screen else {
            center()
            return
        }
        setFrameOrigin(WindowPlacement.origin(for: frame.size, in: screen.visibleFrame))
    }
}
