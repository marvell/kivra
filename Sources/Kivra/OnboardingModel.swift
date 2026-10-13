import SwiftUI

@MainActor
final class OnboardingModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome
        case permission
        case layouts
    }

    enum NavigationDirection {
        case forward
        case backward
    }

    @Published var step: Step
    @Published private(set) var navigationDirection: NavigationDirection = .forward
    @Published var accessibilityGranted: Bool
    @Published var selectedLeftID: String {
        didSet {
            guard selectedLeftID != oldValue,
                selectedRightID == selectedLeftID,
                let alternativeID = LayoutSelection.alternative(to: selectedLeftID, in: sources)
            else {
                return
            }
            selectedRightID = alternativeID
        }
    }
    @Published var selectedRightID: String
    @Published var thresholdMilliseconds: Int
    @Published var isLaunchAtLoginEnabled: Bool
    @Published private(set) var launchAtLoginState: LaunchAtLoginState
    @Published private(set) var launchAtLoginError: String?
    @Published var hideInputSourceIndicator: Bool {
        didSet {
            if hideInputSourceIndicator != oldValue {
                hasInputSourceIndicatorChanges = true
            }
        }
    }
    @Published private(set) var inputSourceIndicatorError: String?

    @Published private(set) var sources: [InputSource]
    private let onAccessibilityChange: () -> Void
    private let onFinish: (String, String, Int) -> Void
    private let accessibility: AccessibilityClient
    private let launchAtLogin: any LaunchAtLoginControlling
    private let inputSourceIndicator: any InputSourceIndicatorControlling
    private var hasInputSourceIndicatorChanges = false
    private var permissionTask: Task<Void, Never>?

    init(
        sources: [InputSource],
        configuredLeftID: String?,
        configuredRightID: String?,
        thresholdMilliseconds: Int,
        launchAtLogin: any LaunchAtLoginControlling = LaunchAtLoginController(),
        inputSourceIndicator: any InputSourceIndicatorControlling,
        accessibility: AccessibilityClient = .live,
        onAccessibilityChange: @escaping () -> Void,
        onFinish: @escaping (String, String, Int) -> Void
    ) {
        let isAccessibilityGranted = accessibility.isGranted()
        self.sources = sources
        self.accessibility = accessibility
        accessibilityGranted = isAccessibilityGranted
        let selections = LayoutSelection.resolve(
            sources: sources,
            leftID: configuredLeftID,
            rightID: configuredRightID
        )
        let initialLaunchAtLoginState = launchAtLogin.state
        selectedLeftID = selections.left
        selectedRightID = selections.right
        self.thresholdMilliseconds = LayoutSelection.normalizedThreshold(thresholdMilliseconds)
        self.launchAtLogin = launchAtLogin
        self.inputSourceIndicator = inputSourceIndicator
        hideInputSourceIndicator = inputSourceIndicator.isHidden
        launchAtLoginState = initialLaunchAtLoginState
        isLaunchAtLoginEnabled = true
        step = .welcome
        self.onAccessibilityChange = onAccessibilityChange
        self.onFinish = onFinish
    }

    var canConfigureLayouts: Bool {
        !selectedLeftID.isEmpty && !selectedRightID.isEmpty && selectedLeftID != selectedRightID
    }

    var isLaunchAtLoginAvailable: Bool {
        launchAtLoginState.isAvailable
    }

    var launchAtLoginRequiresApproval: Bool {
        launchAtLoginState == .requiresApproval
    }

    var selectedLeftName: String {
        sources.first { $0.id == selectedLeftID }?.name ?? "First layout"
    }

    var selectedRightName: String {
        if selectedRightID == selectedLeftID {
            return "Add another layout"
        }
        return sources.first { $0.id == selectedRightID }?.name ?? "Second layout"
    }

    func continueFromWelcome() {
        let isTrusted = accessibility.isGranted()
        updateAccessibility(isTrusted)
        navigate(to: isTrusted ? .layouts : .permission, direction: .forward)
    }

    func goBack() {
        switch step {
        case .welcome:
            break
        case .permission:
            navigate(to: .welcome, direction: .backward)
        case .layouts:
            navigate(
                to: accessibilityGranted ? .welcome : .permission,
                direction: .backward
            )
        }
    }

    func requestAccessibility() {
        accessibility.request()
        refreshPermission()
    }

    func openAccessibilitySettings() {
        accessibility.openSettings()
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

    func startPermissionObservation() {
        guard permissionTask == nil else { return }
        refreshPermission()
        permissionTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(500))
                } catch {
                    return
                }
                self?.refreshPermission()
            }
        }
    }

    func stopPermissionObservation() {
        permissionTask?.cancel()
        permissionTask = nil
    }

    func finish() {
        guard canConfigureLayouts else { return }
        do {
            try launchAtLogin.setEnabled(isLaunchAtLoginEnabled)
            launchAtLoginState = launchAtLogin.state
            launchAtLoginError = nil
        } catch {
            launchAtLoginState = launchAtLogin.state
            launchAtLoginError = "Could not update Open at Login. Try again."
            return
        }
        if hasInputSourceIndicatorChanges {
            do {
                try inputSourceIndicator.setHidden(hideInputSourceIndicator)
                hasInputSourceIndicatorChanges = false
                inputSourceIndicatorError = nil
            } catch {
                inputSourceIndicatorError = "Could not update the input source indicator. Try again."
                return
            }
        }
        onFinish(selectedLeftID, selectedRightID, thresholdMilliseconds)
    }

    func refreshLaunchAtLogin() {
        launchAtLogin.refresh()
        launchAtLoginState = launchAtLogin.state
    }

    func openLoginItemsSettings() {
        launchAtLogin.openLoginItemsSettings()
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
        if selectedLeftID != selections.left {
            selectedLeftID = selections.left
        }
        if selectedRightID != selections.right {
            selectedRightID = selections.right
        }
    }

    private func refreshPermission() {
        let currentValue = accessibility.isGranted()
        updateAccessibility(currentValue)
        if currentValue, step == .permission {
            navigate(to: .layouts, direction: .forward)
        } else if !currentValue, step == .layouts {
            navigate(to: .permission, direction: .backward)
        }
    }

    private func navigate(to destination: Step, direction: NavigationDirection) {
        guard destination != step else { return }
        navigationDirection = direction
        step = destination
    }

    private func updateAccessibility(_ currentValue: Bool) {
        guard currentValue != accessibilityGranted else { return }
        accessibilityGranted = currentValue
        onAccessibilityChange()
    }
}
