import AppKit
import ApplicationServices

@MainActor
struct AccessibilityClient {
    var isGranted: () -> Bool
    var request: () -> Void
    var openSettings: () -> Void

    static let live = Self(
        isGranted: {
            AXIsProcessTrusted()
        },
        request: {
            _ = AXIsProcessTrustedWithOptions(
                ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            )
        },
        openSettings: {
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )!
            _ = NSWorkspace.shared.open(url)
        }
    )
}
