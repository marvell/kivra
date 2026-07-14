import AppKit
import Carbon.HIToolbox
import Sparkle

@MainActor
final class StatusBarController: NSObject, NSApplicationDelegate, SPUUpdaterDelegate {
    private static let onboardingCompletedKey = "onboardingCompleted"
    private static let thresholdMillisecondsKey = "tapThresholdMilliseconds"

    private let inputSources = InputSourceStore()
    private let applicationIdentity = ApplicationIdentity.current
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
    private var statusItem: NSStatusItem?
    private var onboardingController: OnboardingWindowController?
    private var thresholdMilliseconds: Int {
        let value = UserDefaults.standard.integer(forKey: Self.thresholdMillisecondsKey)
        return value == 0 ? 250 : value
    }

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version?.contains("-") == true ? ["beta"] : []
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourcesChanged),
            name: NSNotification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil
        )

        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.onboardingCompletedKey) == nil,
           inputSources.configuredSource(for: .left) != nil,
           inputSources.configuredSource(for: .right) != nil
        {
            defaults.set(true, forKey: Self.onboardingCompletedKey)
        }

        if defaults.bool(forKey: Self.onboardingCompletedKey) {
            startApplicationIfNeeded()
        } else {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        DistributedNotificationCenter.default().removeObserver(self)
        monitor.stop()
    }

    @objc private func inputSourcesChanged() {
        inputSources.refresh()
        onboardingController?.refreshInputSources()
    }

    @objc private func toggleMonitoring(_ sender: NSMenuItem) {
        if monitor.isRunning {
            monitor.stop()
        } else {
            requestAccessibilityIfNeeded()
            if AccessibilityPermission.isGranted {
                monitor.start()
            }
        }
        rebuildMenu()
    }

    @objc private func showOnboarding() {
        showWizard(mode: .firstLaunch)
    }

    @objc private func showSettings() {
        showWizard(mode: .settings)
    }

    private func showWizard(mode: OnboardingModel.Mode) {
        accessibilityChanged()
        if onboardingController == nil {
            onboardingController = OnboardingWindowController(
                inputSources: inputSources,
                thresholdMilliseconds: thresholdMilliseconds,
                mode: mode,
                onAccessibilityChange: { [weak self] in
                    self?.accessibilityChanged()
                },
                onFinish: { [weak self] leftID, rightID, thresholdMilliseconds in
                    self?.finishOnboarding(
                        leftID: leftID,
                        rightID: rightID,
                        thresholdMilliseconds: thresholdMilliseconds
                    )
                },
                onDismiss: { [weak self] in
                    self?.onboardingDismissed()
                }
            )
        }
        onboardingController?.present()
    }

    @objc private func openPrivacySettings() {
        AccessibilityPermission.openSettings()
    }

    private func rebuildMenu() {
        guard let statusItem else {
            return
        }
        let menu = NSMenu()
        let isTrusted = AccessibilityPermission.isGranted
        let state = isTrusted
            ? (monitor.isRunning ? "Monitoring active" : "Monitoring paused")
            : "Accessibility permission required"
        let stateItem = menu.addItem(withTitle: state, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(.separator())

        let monitoringItem = menu.addItem(
            withTitle: monitor.isRunning ? "Pause" : "Enable",
            action: #selector(toggleMonitoring(_:)),
            keyEquivalent: ""
        )
        monitoringItem.target = self

        let setupItem = menu.addItem(
            withTitle: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        setupItem.target = self

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
        let quitItem = menu.addItem(
            withTitle: "Quit \(applicationIdentity.displayName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        statusItem.menu = menu
    }

    private func requestAccessibilityIfNeeded() {
        guard !AccessibilityPermission.isGranted else {
            return
        }
        AccessibilityPermission.request()
    }

    private func accessibilityChanged() {
        guard statusItem != nil else {
            return
        }
        if AccessibilityPermission.isGranted {
            if !monitor.isRunning {
                monitor.start()
            }
        } else if monitor.isRunning {
            monitor.stop()
        }
        rebuildMenu()
    }

    private func finishOnboarding(
        leftID: String,
        rightID: String,
        thresholdMilliseconds: Int
    ) {
        inputSources.setConfiguredSource(leftID, for: .left)
        inputSources.setConfiguredSource(rightID, for: .right)
        UserDefaults.standard.set(thresholdMilliseconds, forKey: Self.thresholdMillisecondsKey)
        monitor.updateThreshold(milliseconds: thresholdMilliseconds)
        UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
        onboardingController?.completeAndClose()
        onboardingController = nil
        startApplicationIfNeeded()
    }

    private func onboardingDismissed() {
        onboardingController = nil
        if !UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey) {
            NSApp.terminate(nil)
        }
    }

    private func startApplicationIfNeeded() {
        guard statusItem == nil else {
            rebuildMenu()
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "keyboard",
            accessibilityDescription: applicationIdentity.displayName
        )
        item.button?.title = applicationIdentity.isDevelopment ? " DEV" : ""
        statusItem = item

        if AccessibilityPermission.isGranted {
            monitor.start()
        }
        rebuildMenu()
    }
}
