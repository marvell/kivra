import AppKit

struct StatusMenuState: Equatable {
    enum Monitoring: Equatable {
        case active
        case paused
        case permissionRequired

        var title: String {
            switch self {
            case .active:
                "Shift switching is on"
            case .paused:
                "Shift switching is paused"
            case .permissionRequired:
                "Accessibility permission required"
            }
        }

        var actionTitle: String {
            switch self {
            case .active:
                "Pause"
            case .paused:
                "Resume"
            case .permissionRequired:
                "Grant Access…"
            }
        }
    }

    let monitoring: Monitoring
    let canCheckForUpdates: Bool
    var updateAvailability: UpdateAvailability?
    var leftLayoutName: String?
    var rightLayoutName: String?

    var layoutTitles: [String] {
        [
            "Left Shift: \(leftLayoutName ?? "Not available")",
            "Right Shift: \(rightLayoutName ?? "Not available")",
        ]
    }

    var statusIcon: StatusIcon {
        if monitoring == .permissionRequired {
            return StatusIcon(isDimmed: true, badge: .warning)
        }
        return StatusIcon(
            isDimmed: monitoring == .paused,
            badge: updateAvailability == nil ? nil : .update
        )
    }

    var updateTitle: String {
        updateAvailability?.title ?? "Check for Updates…"
    }

    var showsPrivacySettings: Bool {
        monitoring == .permissionRequired
    }
}

struct StatusIcon: Equatable {
    enum Badge: Equatable {
        case update
        case warning

        var symbolName: String {
            switch self {
            case .update:
                "arrow.up.circle.fill"
            case .warning:
                "exclamationmark.circle.fill"
            }
        }
    }

    var isDimmed = false
    var badge: Badge?
}

@MainActor
final class StatusMenuController: NSObject {
    private let identity: ApplicationIdentity
    private let onToggleMonitoring: () -> Void
    private let onShowSettings: () -> Void
    private let onOpenPrivacySettings: () -> Void
    private let onCheckForUpdates: () -> Void
    private let onShowAbout: () -> Void
    private let onQuit: () -> Void
    private let statusItem: NSStatusItem
    private var lastState: StatusMenuState?

    init(
        identity: ApplicationIdentity,
        onToggleMonitoring: @escaping () -> Void,
        onShowSettings: @escaping () -> Void,
        onOpenPrivacySettings: @escaping () -> Void,
        onCheckForUpdates: @escaping () -> Void,
        onShowAbout: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.identity = identity
        self.onToggleMonitoring = onToggleMonitoring
        self.onShowSettings = onShowSettings
        self.onOpenPrivacySettings = onOpenPrivacySettings
        self.onCheckForUpdates = onCheckForUpdates
        self.onShowAbout = onShowAbout
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.image = Self.statusImage(StatusIcon())
        statusItem.button?.setAccessibilityLabel(identity.displayName)
        statusItem.button?.title = identity.isDevelopment ? " DEV" : ""
    }

    func update(state: StatusMenuState) {
        guard state != lastState else {
            return
        }
        lastState = state

        let description =
            ([identity.displayName + ": " + state.monitoring.title]
            + (state.updateAvailability.map { [$0.title] } ?? []))
            .joined(separator: ". ")
        statusItem.button?.image = Self.statusImage(state.statusIcon)
        statusItem.button?.toolTip = description
        statusItem.button?.setAccessibilityLabel(description)

        let menu = NSMenu()
        let stateItem = menu.addItem(
            withTitle: state.monitoring.title,
            action: nil,
            keyEquivalent: ""
        )
        stateItem.isEnabled = false
        for title in state.layoutTitles {
            let layoutItem = menu.addItem(
                withTitle: title,
                action: #selector(showSettings),
                keyEquivalent: ""
            )
            layoutItem.target = self
            layoutItem.indentationLevel = 1
            layoutItem.toolTip = "Change layouts in Settings"
        }
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

        menu.addItem(.separator())
        addItem(
            to: menu,
            title: "About \(identity.displayName)",
            action: #selector(showAbout)
        )
        if state.canCheckForUpdates {
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

    static func statusImage(_ icon: StatusIcon) -> NSImage? {
        guard
            let keyboard = NSImage(
                systemSymbolName: "keyboard",
                accessibilityDescription: nil
            )
        else {
            return nil
        }
        let badge = icon.badge.flatMap {
            NSImage(systemSymbolName: $0.symbolName, accessibilityDescription: nil)
        }
        guard icon.isDimmed || badge != nil else {
            keyboard.isTemplate = true
            return keyboard
        }
        let width: CGFloat = badge == nil ? 18 : 28
        let image = NSImage(size: NSSize(width: width, height: 18), flipped: false) { _ in
            // Template images keep their alpha, so a faded keyboard stays
            // legible in both light and dark menu bars.
            keyboard.draw(
                in: NSRect(x: 0, y: 3, width: 18, height: 12),
                from: .zero,
                operation: .sourceOver,
                fraction: icon.isDimmed ? 0.4 : 1
            )
            badge?.draw(in: NSRect(x: 18, y: 0, width: 10, height: 10))
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

    @objc private func showAbout() {
        onShowAbout()
    }

    @objc private func quit() {
        onQuit()
    }
}
