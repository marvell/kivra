import AppKit

struct StatusMenuState: Equatable {
    enum Monitoring: Equatable {
        case active
        case paused
        case permissionRequired

        var title: String {
            switch self {
            case .active:
                "Monitoring active"
            case .paused:
                "Monitoring paused"
            case .permissionRequired:
                "Accessibility permission required"
            }
        }

        var actionTitle: String {
            self == .active ? "Pause" : "Enable"
        }
    }

    let monitoring: Monitoring
    let canCheckForUpdates: Bool
    var updateAvailability: UpdateAvailability?

    var updateTitle: String {
        updateAvailability?.title ?? "Check for Updates…"
    }

    var showsPrivacySettings: Bool {
        monitoring == .permissionRequired
    }
}

@MainActor
final class StatusMenuController: NSObject {
    private let identity: ApplicationIdentity
    private let onToggleMonitoring: () -> Void
    private let onShowSettings: () -> Void
    private let onOpenPrivacySettings: () -> Void
    private let onCheckForUpdates: () -> Void
    private let onQuit: () -> Void
    private let statusItem: NSStatusItem
    private var lastState: StatusMenuState?

    init(
        identity: ApplicationIdentity,
        onToggleMonitoring: @escaping () -> Void,
        onShowSettings: @escaping () -> Void,
        onOpenPrivacySettings: @escaping () -> Void,
        onCheckForUpdates: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.identity = identity
        self.onToggleMonitoring = onToggleMonitoring
        self.onShowSettings = onShowSettings
        self.onOpenPrivacySettings = onOpenPrivacySettings
        self.onCheckForUpdates = onCheckForUpdates
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.image = Self.statusImage(hasUpdate: false)
        statusItem.button?.setAccessibilityLabel(identity.displayName)
        statusItem.button?.title = identity.isDevelopment ? " DEV" : ""
    }

    func update(state: StatusMenuState) {
        guard state != lastState else {
            return
        }
        lastState = state

        let description =
            state.updateAvailability.map {
                "\(identity.displayName): \($0.title)"
            } ?? identity.displayName
        statusItem.button?.image = Self.statusImage(
            hasUpdate: state.updateAvailability != nil
        )
        statusItem.button?.toolTip = description
        statusItem.button?.setAccessibilityLabel(description)

        let menu = NSMenu()
        let stateItem = menu.addItem(
            withTitle: state.monitoring.title,
            action: nil,
            keyEquivalent: ""
        )
        stateItem.isEnabled = false
        menu.addItem(.separator())

        addItem(
            to: menu,
            title: state.monitoring.actionTitle,
            action: #selector(toggleMonitoring)
        )
        addItem(
            to: menu,
            title: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )

        if state.showsPrivacySettings {
            addItem(
                to: menu,
                title: "Open Privacy Settings",
                action: #selector(openPrivacySettings)
            )
        }

        if state.canCheckForUpdates {
            menu.addItem(.separator())
            addItem(
                to: menu,
                title: state.updateTitle,
                action: #selector(checkForUpdates)
            )
        }

        menu.addItem(.separator())
        addItem(
            to: menu,
            title: "Quit \(identity.displayName)",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        statusItem.menu = menu
    }

    static func statusImage(hasUpdate: Bool) -> NSImage? {
        guard
            let keyboard = NSImage(
                systemSymbolName: "keyboard",
                accessibilityDescription: nil
            )
        else {
            return nil
        }
        guard hasUpdate,
            let badge = NSImage(
                systemSymbolName: "arrow.up.circle.fill",
                accessibilityDescription: nil
            )
        else {
            keyboard.isTemplate = true
            return keyboard
        }
        let image = NSImage(size: NSSize(width: 28, height: 18), flipped: false) { _ in
            keyboard.draw(in: NSRect(x: 0, y: 3, width: 18, height: 12))
            badge.draw(in: NSRect(x: 18, y: 0, width: 10, height: 10))
            return true
        }
        image.isTemplate = true
        return image
    }

    private func addItem(
        to menu: NSMenu,
        title: String,
        action: Selector,
        keyEquivalent: String = ""
    ) {
        let item = menu.addItem(
            withTitle: title,
            action: action,
            keyEquivalent: keyEquivalent
        )
        item.target = self
    }

    @objc private func toggleMonitoring() {
        onToggleMonitoring()
    }

    @objc private func showSettings() {
        onShowSettings()
    }

    @objc private func openPrivacySettings() {
        onOpenPrivacySettings()
    }

    @objc private func checkForUpdates() {
        onCheckForUpdates()
    }

    @objc private func quit() {
        onQuit()
    }
}
