import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences: AppPreferences
    private let accessibility: AccessibilityClient
    private let inputSources: InputSourceStore
    private let launchAtLogin: LaunchAtLoginController
    private let presentation: ApplicationPresentationController
    private let updater: AppUpdateController
    private let applicationIdentity: ApplicationIdentity
    private lazy var monitor = ShiftEventMonitor(
        inputSources: inputSources,
        thresholdMilliseconds: inputSources.configuration.tapThresholdMilliseconds,
        onRunningStateChanged: { [weak self] in
            self?.updateStatusMenu()
        }
    )
    private var statusMenu: StatusMenuController?
    private var onboardingController: OnboardingWindowController?

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
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        onboardingController?.updateSources(inputSources.availableSources())
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

    private func showOnboarding() {
        showWizard(mode: .firstLaunch)
    }

    private func showSettings() {
        showWizard(mode: .settings)
    }

    private func showWizard(mode: OnboardingModel.Mode) {
        accessibilityChanged()
        let presentationReason: ApplicationPresentationController.Reason =
            mode == .firstLaunch ? .onboarding : .settings
        if onboardingController == nil {
            let model = OnboardingModel(
                sources: inputSources.availableSources(),
                configuredLeftID: inputSources.configuration.leftSourceID,
                configuredRightID: inputSources.configuration.rightSourceID,
                thresholdMilliseconds: inputSources.configuration.tapThresholdMilliseconds,
                mode: mode,
                launchAtLogin: launchAtLogin,
                accessibility: accessibility,
                onAccessibilityChange: { [weak self] in
                    self?.accessibilityChanged()
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
                onClose: { [weak self] in
                    self?.presentation.end(presentationReason)
                },
                onDismiss: { [weak self] in
                    self?.onboardingDismissed()
                }
            )
        }
        presentation.begin(presentationReason, activate: true)
        onboardingController?.present()
    }

    private func requestAccessibilityIfNeeded() {
        guard !accessibility.isGranted() else {
            return
        }
        accessibility.request()
    }

    private func accessibilityChanged() {
        guard statusMenu != nil else {
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
        var configuration = inputSources.configuration
        configuration.leftSourceID = leftID
        configuration.rightSourceID = rightID
        configuration.tapThresholdMilliseconds = thresholdMilliseconds
        preferences.configuration = configuration
        inputSources.updateConfiguration(configuration)
        monitor.updateThreshold(milliseconds: thresholdMilliseconds)
        preferences.onboardingCompleted = true
        onboardingController?.completeAndClose()
        onboardingController = nil
        startApplicationIfNeeded()
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
                canCheckForUpdates: updater.isAvailable
            )
        )
    }
}
