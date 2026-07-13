import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Sparkle

@MainActor
final class StatusBarController: NSObject, NSApplicationDelegate, SPUUpdaterDelegate {
    private let inputSources = InputSourceStore()
    private lazy var updaterController: SPUStandardUpdaterController? = {
        guard Bundle.main.bundleURL.pathExtension == "app",
              Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
        else {
            return nil
        }
        return SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }()
    private lazy var monitor = ShiftEventMonitor(
        inputSources: inputSources,
        thresholdMilliseconds: thresholdMilliseconds
    )
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var thresholdMilliseconds: Int {
        let value = UserDefaults.standard.integer(forKey: "tapThresholdMilliseconds")
        return value == 0 ? 250 : value
    }

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version?.contains("-") == true ? ["beta"] : []
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = NSImage(
            systemSymbolName: "keyboard",
            accessibilityDescription: "Kivra"
        )
        requestAccessibilityIfNeeded()
        if AXIsProcessTrusted() {
            monitor.start()
        }
        rebuildMenu()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourcesChanged),
            name: NSNotification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        DistributedNotificationCenter.default().removeObserver(self)
        monitor.stop()
    }

    @objc private func inputSourcesChanged() {
        inputSources.refresh()
        rebuildMenu()
    }

    @objc private func selectSource(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let side = ShiftSide(rawValue: sender.identifier?.rawValue ?? "")
        else {
            return
        }
        inputSources.setConfiguredSource(id, for: side)
        rebuildMenu()
    }

    @objc private func setThreshold(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: "tapThresholdMilliseconds")
        monitor.updateThreshold(milliseconds: sender.tag)
        rebuildMenu()
    }

    @objc private func toggleMonitoring(_ sender: NSMenuItem) {
        if monitor.isRunning {
            monitor.stop()
        } else {
            requestAccessibilityIfNeeded()
            if AXIsProcessTrusted() {
                monitor.start()
            }
        }
        rebuildMenu()
    }

    @objc private func openPrivacySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let isTrusted = AXIsProcessTrusted()
        let state = isTrusted
            ? (monitor.isRunning ? "Monitoring active" : "Monitoring paused")
            : "Accessibility permission required"
        let stateItem = menu.addItem(withTitle: state, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(.separator())

        addSourceMenu(title: "Left Shift", side: .left, to: menu)
        addSourceMenu(title: "Right Shift", side: .right, to: menu)

        let thresholdMenu = NSMenu()
        for value in [100, 150, 200, 250, 300, 400, 500] {
            let item = NSMenuItem(
                title: "\(value) ms",
                action: #selector(setThreshold(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = value
            item.state = value == thresholdMilliseconds ? .on : .off
            thresholdMenu.addItem(item)
        }
        let thresholdItem = NSMenuItem(title: "Tap threshold", action: nil, keyEquivalent: "")
        thresholdItem.submenu = thresholdMenu
        menu.addItem(thresholdItem)
        menu.addItem(.separator())

        let monitoringItem = menu.addItem(
            withTitle: monitor.isRunning ? "Pause" : "Enable",
            action: #selector(toggleMonitoring(_:)),
            keyEquivalent: ""
        )
        monitoringItem.target = self

        if !isTrusted {
            let privacyItem = menu.addItem(
                withTitle: "Open Privacy Settings",
                action: #selector(openPrivacySettings),
                keyEquivalent: ""
            )
            privacyItem.target = self
        }

        if let updaterController {
            menu.addItem(.separator())
            let updateItem = menu.addItem(
                withTitle: "Check for Updates…",
                action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
                keyEquivalent: ""
            )
            updateItem.target = updaterController
        }

        menu.addItem(.separator())
        let quitItem = menu.addItem(withTitle: "Quit Kivra", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        statusItem.menu = menu
    }

    private func addSourceMenu(title: String, side: ShiftSide, to menu: NSMenu) {
        let sourceMenu = NSMenu()
        let selectedID = inputSources.configuredSource(for: side)

        for source in inputSources.availableSources() {
            let item = NSMenuItem(title: source.name, action: #selector(selectSource(_:)), keyEquivalent: "")
            item.target = self
            item.identifier = NSUserInterfaceItemIdentifier(side.rawValue)
            item.representedObject = source.id
            item.state = source.id == selectedID ? .on : .off
            sourceMenu.addItem(item)
        }

        let sourceItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        sourceItem.submenu = sourceMenu
        menu.addItem(sourceItem)
    }

    private func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else {
            return
        }
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
}
