import Foundation

@MainActor
final class SettingsModel: ObservableObject {
    @Published private(set) var sources: [InputSource]
    @Published var selectedLeftID: String {
        didSet {
            guard selectedLeftID != oldValue else { return }
            if selectedRightID == selectedLeftID,
                let alternativeID = LayoutSelection.alternative(to: selectedLeftID, in: sources)
            {
                selectedRightID = alternativeID
            }
            applyConfiguration()
        }
    }
    @Published var selectedRightID: String {
        didSet {
            guard selectedRightID != oldValue else { return }
            applyConfiguration()
        }
    }
    @Published var thresholdMilliseconds: Int {
        didSet {
            guard thresholdMilliseconds != oldValue else { return }
            applyConfiguration()
        }
    }
    @Published private(set) var accessibilityGranted: Bool
    @Published private(set) var launchAtLoginState: LaunchAtLoginState
    @Published private(set) var launchAtLoginError: String?
    @Published private(set) var hideInputSourceIndicator: Bool
    @Published private(set) var inputSourceIndicatorError: String?

    private let accessibility: AccessibilityClient
    private let launchAtLogin: any LaunchAtLoginControlling
    private let inputSourceIndicator: any InputSourceIndicatorControlling
    private let onAccessibilityChange: () -> Void
    private let onConfigurationChange: (String, String, Int) -> Void

    init(
        sources: [InputSource],
        configuration: AppConfiguration,
        launchAtLogin: any LaunchAtLoginControlling,
        inputSourceIndicator: any InputSourceIndicatorControlling,
        accessibility: AccessibilityClient,
        onAccessibilityChange: @escaping () -> Void,
        onConfigurationChange: @escaping (String, String, Int) -> Void
    ) {
        let selections = LayoutSelection.resolve(
            sources: sources,
            leftID: configuration.leftSourceID,
            rightID: configuration.rightSourceID
        )
        self.sources = sources
        selectedLeftID = selections.left
        selectedRightID = selections.right
        thresholdMilliseconds = LayoutSelection.normalizedThreshold(
            configuration.tapThresholdMilliseconds
        )
        accessibilityGranted = accessibility.isGranted()
        launchAtLoginState = launchAtLogin.state
        hideInputSourceIndicator = inputSourceIndicator.isHidden
        self.accessibility = accessibility
        self.launchAtLogin = launchAtLogin
        self.inputSourceIndicator = inputSourceIndicator
        self.onAccessibilityChange = onAccessibilityChange
        self.onConfigurationChange = onConfigurationChange
    }

    var canConfigureLayouts: Bool {
        !selectedLeftID.isEmpty && !selectedRightID.isEmpty && selectedLeftID != selectedRightID
    }

    var isLaunchAtLoginEnabled: Bool {
        launchAtLoginState.isEnabled
    }

    var isLaunchAtLoginAvailable: Bool {
        launchAtLoginState.isAvailable
    }

    var launchAtLoginRequiresApproval: Bool {
        launchAtLoginState == .requiresApproval
    }

    /// Re-reads settings that can change outside Kivra, such as in System Settings.
    func refresh() {
        let isGranted = accessibility.isGranted()
        if isGranted != accessibilityGranted {
            accessibilityGranted = isGranted
            onAccessibilityChange()
        }
        launchAtLogin.refresh()
        launchAtLoginState = launchAtLogin.state
        hideInputSourceIndicator = inputSourceIndicator.isHidden
    }

    func updateSources(_ updatedSources: [InputSource]) {
        let selections = LayoutSelection.resolve(
            sources: updatedSources,
            leftID: selectedLeftID,
            rightID: selectedRightID
        )
        if sources != updatedSources {
            sources = updatedSources
        }
        // Set the right side first so the left side does not resolve a
        // conflict against a stale selection.
        selectedRightID = selections.right
        selectedLeftID = selections.left
    }

    func swapLayouts() {
        guard canConfigureLayouts else { return }
        let leftID = selectedLeftID
        let rightID = selectedRightID
        // Assign the right side first so the left side's conflict resolution
        // does not replace the layout being swapped in.
        selectedRightID = leftID
        selectedLeftID = rightID
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try launchAtLogin.setEnabled(enabled)
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Could not update Open at Login. Try again."
        }
        launchAtLoginState = launchAtLogin.state
    }

    func setInputSourceIndicatorHidden(_ hidden: Bool) {
        do {
            try inputSourceIndicator.setHidden(hidden)
            inputSourceIndicatorError = nil
        } catch {
            inputSourceIndicatorError = "Could not update the input source indicator. Try again."
        }
        hideInputSourceIndicator = inputSourceIndicator.isHidden
    }

    func requestAccessibility() {
        accessibility.request()
        refresh()
    }

    func openAccessibilitySettings() {
        accessibility.openSettings()
    }

    func openLoginItemsSettings() {
        launchAtLogin.openLoginItemsSettings()
    }

    private func applyConfiguration() {
        guard canConfigureLayouts else { return }
        onConfigurationChange(selectedLeftID, selectedRightID, thresholdMilliseconds)
    }
}
