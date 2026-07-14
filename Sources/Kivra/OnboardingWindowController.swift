import AppKit
import SwiftUI

private final class OnboardingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let inputSources: InputSourceStore
    private let model: OnboardingModel
    private let onDismiss: () -> Void
    private var isCompleting = false

    init(
        inputSources: InputSourceStore,
        thresholdMilliseconds: Int,
        mode: OnboardingModel.Mode,
        launchAtLogin: any LaunchAtLoginControlling,
        onAccessibilityChange: @escaping () -> Void,
        onFinish: @escaping (String, String, Int) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.inputSources = inputSources
        self.onDismiss = onDismiss
        model = OnboardingModel(
            sources: inputSources.availableSources(),
            configuredLeftID: inputSources.configuredSource(for: .left),
            configuredRightID: inputSources.configuredSource(for: .right),
            thresholdMilliseconds: thresholdMilliseconds,
            mode: mode,
            launchAtLogin: launchAtLogin,
            onAccessibilityChange: onAccessibilityChange,
            onFinish: onFinish
        )

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
            mode == .firstLaunch
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

    func refreshInputSources() {
        model.updateSources(inputSources.availableSources())
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
    private let launchAtLogin: any LaunchAtLoginControlling
    private var permissionTask: Task<Void, Never>?

    init(
        sources: [InputSource],
        configuredLeftID: String?,
        configuredRightID: String?,
        thresholdMilliseconds: Int,
        mode: Mode = .firstLaunch,
        launchAtLogin: any LaunchAtLoginControlling = LaunchAtLoginController(),
        onAccessibilityChange: @escaping () -> Void,
        accessibilityGranted: Bool = AccessibilityPermission.isGranted,
        onFinish: @escaping (String, String, Int) -> Void
    ) {
        self.mode = mode
        self.sources = sources
        self.accessibilityGranted = accessibilityGranted
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
            step = accessibilityGranted ? .layouts : .permission
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
        let isTrusted = AccessibilityPermission.isGranted
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
        AccessibilityPermission.request()
        refreshPermission()
    }

    func startPermissionObservation() {
        guard permissionTask == nil else { return }
        refreshPermission()
        permissionTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
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
        let currentValue = AccessibilityPermission.isGranted
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

private struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var model: OnboardingModel
    let dismiss: () -> Void
    @State private var isExitHovered = false
    @State private var isTapThresholdExpanded = false

    private let accent = Color(red: 1.0, green: 0.39, blue: 0.28)
    private let panel = Color.white.opacity(0.055)
    private let border = Color.white.opacity(0.10)
    private let applicationName = ApplicationIdentity.current.displayName
    private let appVersion =
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String

    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.058, blue: 0.07)
            RadialGradient(
                colors: [accent.opacity(0.09), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 360
            )

            VStack(spacing: 0) {
                brand
                if !model.isSettingsMode {
                    progress
                }

                ZStack {
                    Group {
                        switch model.step {
                        case .welcome: welcome
                        case .permission: permission
                        case .layouts: layouts
                        }
                    }
                    .id(model.step)
                    .transition(pageTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.24), value: model.step)
            }
            .padding(.top, 27)

            VStack {
                HStack {
                    Spacer()
                    exitButton
                }
                Spacer()
            }
            .padding(.top, 14)
            .padding(.trailing, 14)
        }
        .frame(minWidth: 620, minHeight: 480)
        .foregroundStyle(.white)
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else {
            return .opacity
        }
        let distance = 28.0
        let insertionOffset = model.navigationDirection == .forward ? distance : -distance
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: insertionOffset)),
            removal: .opacity.combined(with: .offset(x: -insertionOffset))
        )
    }

    private var exitButton: some View {
        Button(action: dismiss) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isExitHovered ? 0.08 : 0.025))
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(isExitHovered ? 0.62 : 0.24))
            }
            .frame(width: 26, height: 26)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .help(model.isSettingsMode ? "Close settings" : "Close setup")
        .accessibilityLabel(model.isSettingsMode ? "Close settings" : "Close setup")
        .onHover { isExitHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isExitHovered)
    }

    private var brand: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(accent)
                Image(systemName: "command")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .frame(width: 25, height: 25)

            Text(applicationName)
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            if let appVersion {
                Text("v\(appVersion)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.28))
                    .accessibilityLabel("Version \(appVersion)")
            }
        }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingModel.Step.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step == model.step ? accent : Color.white.opacity(0.13))
                    .frame(width: step == model.step ? 18 : 6, height: 6)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.step)
        .padding(.top, 17)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(model.step.rawValue + 1) of \(OnboardingModel.Step.allCases.count)")
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Made for people who type in two languages.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))

            Text("Stop cycling through layouts.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(-0.7)
                .padding(.top, 9)

            Text(
                "The macOS shortcut takes several keys and only moves\nto the next layout. \(applicationName) lets you choose one directly."
            )
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(.white.opacity(0.50))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.top, 11)

            HStack(spacing: 11) {
                languageKey(side: "LEFT SHIFT", language: model.selectedLeftName)
                languageKey(side: "RIGHT SHIFT", language: model.selectedRightName)
            }
            .padding(.top, 21)

            Text("Whatever is active, you always know which key to press.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.46))
                .padding(.top, 13)

            Spacer()
            primaryButton("Continue", symbol: "arrow.right", action: model.continueFromWelcome)
                .keyboardShortcut(.defaultAction)
                .padding(.bottom, 30)
        }
    }

    private var permission: some View {
        VStack(spacing: 0) {
            Spacer()

            featureIcon(
                model.accessibilityGranted ? "checkmark" : "hand.raised.fill",
                color: model.accessibilityGranted ? .green : accent
            )

            Text(model.accessibilityGranted ? "Access granted" : "Allow Accessibility access")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(-0.5)
                .padding(.top, 22)

            Text(
                model.accessibilityGranted
                    ? "\(applicationName) can now recognize a quick Shift tap."
                    : "\(applicationName) uses it only to recognize Shift taps.\nIt never reads or stores what you type."
            )
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(.white.opacity(0.50))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.top, 11)

            Spacer()

            HStack(spacing: 10) {
                if model.isSettingsMode {
                    cancelButton
                } else {
                    backButton
                }
                primaryButton("Grant Access", symbol: "hand.raised.fill", action: model.requestAccessibility)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 30)
        }
    }

    private var layouts: some View {
        VStack(spacing: 0) {
            Text("Choose your layouts")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(-0.5)
                .padding(.top, 12)

            Text("Assign one to each Shift key.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.50))
                .padding(.top, 6)

            VStack(spacing: 8) {
                layoutPicker(title: "Left Shift", selection: $model.selectedLeftID)
                layoutPicker(
                    title: "Right Shift",
                    selection: $model.selectedRightID,
                    excluding: model.selectedLeftID
                )
            }
            .frame(maxWidth: 420)
            .padding(.top, 12)

            tapThresholdConfiguration
                .frame(maxWidth: 420)
                .padding(.top, 8)

            launchAtLoginConfiguration
                .frame(maxWidth: 420)
                .padding(.top, 8)

            Group {
                if model.sources.count < 2 {
                    Text("\(applicationName) needs two enabled keyboard layouts.")
                }
            }
            .font(.system(size: 12, design: .rounded))
            .foregroundStyle(accent)
            .padding(.top, 10)

            Spacer()

            HStack(spacing: 10) {
                if model.isSettingsMode {
                    cancelButton
                } else {
                    backButton
                }
                primaryButton(
                    model.isSettingsMode ? "Save Changes" : "Start \(applicationName)",
                    symbol: "checkmark",
                    action: model.finish
                )
                .disabled(!model.canConfigureLayouts)
                .opacity(model.canConfigureLayouts ? 1 : 0.42)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 42)
    }

    private var tapThresholdConfiguration: some View {
        VStack(spacing: 0) {
            Button {
                isTapThresholdExpanded.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(accent.opacity(0.10))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tap threshold")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("\(model.thresholdMilliseconds) ms")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.42))
                            .contentTransition(.numericText())
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.42))
                        .rotationEffect(.degrees(isTapThresholdExpanded ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tap threshold")
            .accessibilityValue(
                "\(model.thresholdMilliseconds) milliseconds, "
                    + (isTapThresholdExpanded ? "expanded" : "collapsed")
            )
            .accessibilityHint(
                isTapThresholdExpanded
                    ? "Hides optional tap timing settings"
                    : "Shows optional tap timing settings"
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Maximum time Shift can be held")
                    Spacer()
                    Text("\(model.thresholdMilliseconds) ms")
                        .foregroundStyle(accent)
                        .contentTransition(.numericText())
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))

                Slider(
                    value: Binding(
                        get: { Double(model.thresholdMilliseconds) },
                        set: { model.thresholdMilliseconds = Int($0.rounded()) }
                    ),
                    in: 100...500,
                    step: 50
                )
                .tint(accent)
                .accessibilityLabel("Tap threshold in milliseconds")

                HStack {
                    Text("Quick")
                    Spacer()
                    Text("Relaxed")
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.32))
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 10)
            .frame(height: isTapThresholdExpanded ? 72 : 0, alignment: .top)
            .clipped()
            .opacity(isTapThresholdExpanded ? 1 : 0)
            .allowsHitTesting(isTapThresholdExpanded)
            .accessibilityHidden(!isTapThresholdExpanded)
        }
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(panel))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
        .animation(
            reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.88),
            value: isTapThresholdExpanded
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.16),
            value: model.thresholdMilliseconds
        )
    }

    private var launchAtLoginConfiguration: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $model.isLaunchAtLoginEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(accent.opacity(0.10))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open Kivra at login")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }

                    Spacer()

                    Text(model.isLaunchAtLoginEnabled ? "ON" : "OFF")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(
                            model.isLaunchAtLoginEnabled
                                ? accent
                                : .white.opacity(0.38)
                        )
                }
            }
            .toggleStyle(.switch)
            .tint(accent)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .disabled(!model.isLaunchAtLoginAvailable)
            .accessibilityLabel("Open Kivra at login")
            .accessibilityHint(
                model.isLaunchAtLoginAvailable
                    ? "Applies when you save changes"
                    : "Available in the installed app"
            )

            if model.launchAtLoginRequiresApproval {
                launchAtLoginStatus(
                    symbol: "exclamationmark.circle.fill",
                    "Allow it in Login Items.",
                    color: Color(red: 1.0, green: 0.68, blue: 0.30),
                    action: model.openLoginItemsSettings
                )
            } else if let error = model.launchAtLoginError {
                launchAtLoginStatus(
                    symbol: "exclamationmark.triangle.fill",
                    error,
                    color: accent
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(panel)
        )
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
    }

    private func launchAtLoginStatus(
        symbol: String,
        _ message: String,
        color: Color,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)

            Text(message)
                .lineLimit(1)

            Spacer()

            if let action {
                Button("Open Settings", action: action)
                    .buttonStyle(.plain)
                    .foregroundStyle(color)
            }
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.50))
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Color.white.opacity(0.025))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
        }
    }

    private func languageKey(side: String, language: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "shift.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(side)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.34))
                Text(language)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .frame(width: 195, height: 66)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(panel))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(border, lineWidth: 1))
    }

    private func featureIcon(_ symbol: String, color: Color) -> some View {
        ZStack {
            Circle().fill(color.opacity(0.11))
            Circle().stroke(color.opacity(0.22), lineWidth: 1)
            Image(systemName: symbol)
                .font(.system(size: 29, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 80, height: 80)
    }

    private func layoutPicker(
        title: String,
        selection: Binding<String>,
        excluding excludedID: String? = nil
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: "shift.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(accent.opacity(0.10)))

            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Spacer()

            Picker(title, selection: selection) {
                if model.sources.isEmpty {
                    Text("No layouts found").tag("")
                }
                ForEach(model.sources.filter { $0.id != excludedID }) { source in
                    Text(source.name).tag(source.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 178)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(panel))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(border, lineWidth: 1))
    }

    private func primaryButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .padding(.horizontal, 18)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(accent))
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(panel))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(border, lineWidth: 1))
    }

    private var backButton: some View {
        secondaryButton("Back", action: model.goBack)
    }

    private var cancelButton: some View {
        secondaryButton("Cancel", action: dismiss)
    }
}
