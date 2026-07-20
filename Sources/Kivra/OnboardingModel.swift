import SwiftUI

@MainActor
final class OnboardingModel: ObservableObject {
    enum Mode: Equatable {
        case firstLaunch
        case settings
    }

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
                let alternativeID = sources.first(where: { $0.id != selectedLeftID })?.id
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

    @Published private(set) var sources: [InputSource]
    let mode: Mode
    private let onAccessibilityChange: () -> Void
    private let onFinish: (String, String, Int) -> Void
    private let accessibility: AccessibilityClient
    private let launchAtLogin: any LaunchAtLoginControlling
    private var permissionTask: Task<Void, Never>?

    init(
        sources: [InputSource],
        configuredLeftID: String?,
        configuredRightID: String?,
        thresholdMilliseconds: Int,
        mode: Mode = .firstLaunch,
        launchAtLogin: any LaunchAtLoginControlling = LaunchAtLoginController(),
        accessibility: AccessibilityClient = .live,
        onAccessibilityChange: @escaping () -> Void,
        onFinish: @escaping (String, String, Int) -> Void
    ) {
        let isAccessibilityGranted = accessibility.isGranted()
        self.mode = mode
        self.sources = sources
        self.accessibility = accessibility
        accessibilityGranted = isAccessibilityGranted
        let selections = Self.resolveSelections(
            sources: sources,
            leftID: configuredLeftID,
            rightID: configuredRightID
        )
        let initialLaunchAtLoginState = launchAtLogin.state
        selectedLeftID = selections.left
        selectedRightID = selections.right
        self.thresholdMilliseconds = Self.normalizedThreshold(thresholdMilliseconds)
        self.launchAtLogin = launchAtLogin
        launchAtLoginState = initialLaunchAtLoginState
        isLaunchAtLoginEnabled =
            mode == .firstLaunch
            ? true
            : initialLaunchAtLoginState.isEnabled
        if mode == .settings {
            step = isAccessibilityGranted ? .layouts : .permission
        } else {
            step = .welcome
        }
        self.onAccessibilityChange = onAccessibilityChange
        self.onFinish = onFinish
    }

    var isSettingsMode: Bool {
        mode == .settings
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
        onFinish(selectedLeftID, selectedRightID, thresholdMilliseconds)
    }

    func refreshLaunchAtLogin() {
        launchAtLogin.refresh()
        launchAtLoginState = launchAtLogin.state
        if mode == .settings {
            isLaunchAtLoginEnabled = launchAtLoginState.isEnabled
        }
    }

    func openLoginItemsSettings() {
        launchAtLogin.openLoginItemsSettings()
    }

    func updateSources(_ updatedSources: [InputSource]) {
        let selections = Self.resolveSelections(
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
        if isSettingsMode, !currentValue {
            navigate(to: .permission, direction: .backward)
        } else if currentValue, step == .permission {
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

    private static func resolveSelections(
        sources: [InputSource],
        leftID: String?,
        rightID: String?
    ) -> (left: String, right: String) {
        let left =
            leftID.flatMap { id in
                sources.contains { $0.id == id } ? id : nil
            } ?? sources.first?.id ?? ""
        let fallbackRight = sources.first { $0.id != left }?.id ?? left
        let right =
            rightID.flatMap { id in
                sources.contains { $0.id == id && id != left } ? id : nil
            } ?? fallbackRight
        return (left, right)
    }

    private static func normalizedThreshold(_ milliseconds: Int) -> Int {
        let clampedValue = min(max(milliseconds, 100), 500)
        return Int((Double(clampedValue) / 50).rounded() * 50)
    }
}
