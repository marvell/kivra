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
    }

    let monitoring: Monitoring
    var updateAvailability: UpdateAvailability?

    var statusIcon: StatusIcon {
        if monitoring == .permissionRequired {
            return StatusIcon(isDimmed: true, badge: .warning)
        }
        return StatusIcon(
            isDimmed: monitoring == .paused,
            badge: updateAvailability == nil ? nil : .update
        )
    }

    var needsPermission: Bool {
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
        if state.needsPermission {
            let permissionItem = addItem(
                to: menu,
                title: "Allow Accessibility Access…",
                action: #selector(openPrivacySettings)
            )
            permissionItem.image = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: nil
            )
        } else {
            addItem(
                to: menu,
                title: "\(state.monitoring == .active ? "Pause" : "Resume") \(identity.displayName)",
                action: #selector(toggleMonitoring)
            )
        }
        menu.addItem(.separator())

        if let update = state.updateAvailability {
            // Updates are checked automatically, so the menu only mentions
            // one that is waiting; manual checks live in Settings.
            addItem(to: menu, title: update.title, action: #selector(checkForUpdates))
        }
        addItem(
            to: menu,
            title: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
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

    @discardableResult
    private func addItem(
        to menu: NSMenu,
        title: String,
        action: Selector,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = menu.addItem(
            withTitle: title,
            action: action,
            keyEquivalent: keyEquivalent
        )
        item.target = self
        return item
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
