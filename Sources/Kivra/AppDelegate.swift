import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private let preferences: AppPreferences
    private let accessibility: AccessibilityClient
    private let inputSources: InputSourceStore
    private let launchAtLogin: LaunchAtLoginController
    private let inputSourceIndicator: InputSourceIndicatorController
    private let presentation: ApplicationPresentationController
    private let updater: AppUpdateController
    private let applicationIdentity: ApplicationIdentity
    private lazy var monitor = ShiftEventMonitor(
        inputSources: inputSources,
        thresholdMilliseconds: inputSources.configuration.tapThresholdMilliseconds,
        onRunningStateChanged: { [weak self] in
            self?.updateStatusMenu()
        },
        onShiftTap: { [weak self] side in
            self?.shiftTapped(side)
        }
    )
    private let shiftTaps = ShiftTapFeedback()
    private var statusMenu: StatusMenuController?
    private var onboardingController: OnboardingWindowController?
    private var settingsController: SettingsWindowController?

    override init() {
        let preferences = AppPreferences()
        let configuration = preferences.configuration
        self.preferences = preferences
        accessibility = .live
        inputSources = InputSourceStore(
            configuration: configuration,
            system: CarbonInputSourceSystem()
        )
        launchAtLogin = LaunchAtLoginController()
        inputSourceIndicator = InputSourceIndicatorController()
        let presentation = ApplicationPresentationController()
        self.presentation = presentation
        updater = AppUpdateController(
            onPresentationRequested: { [weak presentation] userInitiated in
                presentation?.begin(
                    .update,
                    activate: userInitiated,
                    showBadge: !userInitiated
                )
            },
            onAttentionReceived: { [weak presentation] in
                presentation?.clearBadge()
            },
            onSessionFinished: { [weak presentation] in
                presentation?.end(.update)
            }
        )
        applicationIdentity = .current
        super.init()
        updater.onAvailabilityChanged = { [weak self] in
            self?.updateStatusMenu()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make(applicationName: applicationIdentity.displayName)
        registerInputSourceNotifications()
        preferences.migrateOnboardingCompletionIfNeeded()

        if preferences.onboardingCompleted == true {
            startApplicationIfNeeded()
        } else {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        DistributedNotificationCenter.default().removeObserver(self)
        monitor.stop()
    }

    private func registerInputSourceNotifications() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourcesChanged),
            name: NSNotification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(selectedInputSourceChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
    }

    @objc private func inputSourcesChanged() {
        inputSources.refresh()
        let sources = inputSources.availableSources()
        onboardingController?.updateSources(sources)
        settingsController?.updateSources(sources)
        updateStatusMenu()
    }

    @objc private func selectedInputSourceChanged() {
        inputSources.selectedSourceDidChange()
    }

    private func toggleMonitoring() {
        if monitor.isRunning {
            monitor.stop()
        } else {
            requestAccessibilityIfNeeded()
            if accessibility.isGranted() {
                monitor.start()
            }
        }
        updateStatusMenu()
    }

    @objc func showSettingsFromMenu() {
        showSettings()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(showSettingsFromMenu) {
            // Settings become available once setup is finished.
            return statusMenu != nil
        }
        return true
    }

    private func showSettings() {
        if settingsController == nil {
            let model = SettingsModel(
                sources: inputSources.availableSources(),
                configuration: inputSources.configuration,
                launchAtLogin: launchAtLogin,
                inputSourceIndicator: inputSourceIndicator,
                accessibility: accessibility,
                onAccessibilityChange: { [weak self] in
                    self?.accessibilityChanged()
                },
                onCheckForUpdates: updater.isAvailable
                    ? { [weak self] in self?.updater.checkForUpdates() } : nil,
                onConfigurationChange: { [weak self] leftID, rightID, thresholdMilliseconds in
                    self?.applyConfiguration(
                        leftID: leftID,
                        rightID: rightID,
                        thresholdMilliseconds: thresholdMilliseconds
                    )
                }
            )
            settingsController = SettingsWindowController(
                model: model,
                shiftTaps: shiftTaps,
                onClose: { [weak self] in
                    self?.presentation.end(.settings)
                }
            )
        }
        accessibilityChanged()
        presentation.begin(.settings, activate: true)
        settingsController?.present()
    }

    private func showOnboarding() {
        if onboardingController == nil {
            let model = OnboardingModel(
                sources: inputSources.availableSources(),
                configuredLeftID: inputSources.configuration.leftSourceID,
                configuredRightID: inputSources.configuration.rightSourceID,
                thresholdMilliseconds: inputSources.configuration.tapThresholdMilliseconds,
                launchAtLogin: launchAtLogin,
                accessibility: accessibility,
                onAccessibilityChange: { [weak self] in
                    self?.accessibilityChanged()
                },
                onPreview: { [weak self] leftID, rightID, thresholdMilliseconds in
                    self?.previewConfiguration(
                        leftID: leftID,
                        rightID: rightID,
                        thresholdMilliseconds: thresholdMilliseconds
                    )
                },
                onFinish: { [weak self] leftID, rightID, thresholdMilliseconds in
                    self?.finishOnboarding(
                        leftID: leftID,
                        rightID: rightID,
                        thresholdMilliseconds: thresholdMilliseconds
                    )
                }
            )
            onboardingController = OnboardingWindowController(
                model: model,
                shiftTaps: shiftTaps,
                onClose: { [weak self] in
                    self?.presentation.end(.onboarding)
                },
                onDismiss: { [weak self] in
                    self?.onboardingDismissed()
                }
            )
        }
        // Monitoring starts during setup so people can try their layouts.
        accessibilityChanged()
        presentation.begin(.onboarding, activate: true)
        onboardingController?.present()
    }

    /// Lights up the tapped key only while the person is looking at the keys,
    /// not while they type in another app.
    private func shiftTapped(_ side: ShiftSide) {
        guard
            onboardingController?.isShowingShiftKeys == true
                || settingsController?.isShowingShiftKeys == true
        else {
            return
        }
        shiftTaps.record(side)
    }

    private func requestAccessibilityIfNeeded() {
        guard !accessibility.isGranted() else {
            return
        }
        accessibility.request()
    }

    private func accessibilityChanged() {
        guard statusMenu != nil || onboardingController != nil else {
            return
        }
        if accessibility.isGranted() {
            if !monitor.isRunning {
                monitor.start()
            }
        } else if monitor.isRunning {
            monitor.stop()
        }
        updateStatusMenu()
    }

    private func finishOnboarding(
        leftID: String,
        rightID: String,
        thresholdMilliseconds: Int
    ) {
        applyConfiguration(
            leftID: leftID,
            rightID: rightID,
            thresholdMilliseconds: thresholdMilliseconds
        )
        preferences.onboardingCompleted = true
        onboardingController?.completeAndClose()
        onboardingController = nil
        startApplicationIfNeeded()
    }

    private func applyConfiguration(
        leftID: String,
        rightID: String,
        thresholdMilliseconds: Int
    ) {
        previewConfiguration(
            leftID: leftID,
            rightID: rightID,
            thresholdMilliseconds: thresholdMilliseconds
        )
        preferences.configuration = inputSources.configuration
        updateStatusMenu()
    }

    /// Uses a configuration for Shift taps without saving it.
    private func previewConfiguration(
        leftID: String,
        rightID: String,
        thresholdMilliseconds: Int
    ) {
        var configuration = inputSources.configuration
        configuration.leftSourceID = leftID
        configuration.rightSourceID = rightID
        configuration.tapThresholdMilliseconds = thresholdMilliseconds
        inputSources.updateConfiguration(configuration)
        monitor.updateThreshold(milliseconds: thresholdMilliseconds)
    }

    private func onboardingDismissed() {
        onboardingController = nil
        if preferences.onboardingCompleted != true {
            NSApp.terminate(nil)
        }
    }

    private func startApplicationIfNeeded() {
        if statusMenu == nil {
            statusMenu = StatusMenuController(
                identity: applicationIdentity,
                onToggleMonitoring: { [weak self] in
                    self?.toggleMonitoring()
                },
                onShowSettings: { [weak self] in
                    self?.showSettings()
                },
                onOpenPrivacySettings: { [weak self] in
                    // Only open System Settings: the system prompt would
                    // appear on top of it and compete for attention.
                    self?.accessibility.openSettings()
                },
                onCheckForUpdates: { [weak self] in
                    self?.updater.checkForUpdates()
                },
                onQuit: {
                    NSApp.terminate(nil)
                }
            )
        }

        if accessibility.isGranted(), !monitor.isRunning {
            monitor.start()
        }
        updateStatusMenu()
    }

    private func updateStatusMenu() {
        let monitoring: StatusMenuState.Monitoring
        if !accessibility.isGranted() {
            monitoring = .permissionRequired
        } else if monitor.isRunning {
            monitoring = .active
        } else {
            monitoring = .paused
        }
        statusMenu?.update(
            state: StatusMenuState(
                monitoring: monitoring,
                updateAvailability: updater.availability
            )
        )
    }
}
