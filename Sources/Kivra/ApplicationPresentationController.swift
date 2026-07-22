import AppKit

@MainActor
final class ApplicationPresentationController {
    enum Reason: Hashable {
        case onboarding
        case settings
        case update
    }

    private var foregroundReasons: Set<Reason> = []
    private let setActivationPolicy: (NSApplication.ActivationPolicy) -> Void
    private let activateApplication: () -> Void
    private let setDockBadge: (String?) -> Void

    init(
        setActivationPolicy: @escaping (NSApplication.ActivationPolicy) -> Void = { policy in
            NSApp.setActivationPolicy(policy)
        },
        activateApplication: @escaping () -> Void = {
            NSApp.activate(ignoringOtherApps: true)
        },
        setDockBadge: @escaping (String?) -> Void = { badge in
            NSApp.dockTile.badgeLabel = badge
        }
    ) {
        self.setActivationPolicy = setActivationPolicy
        self.activateApplication = activateApplication
        self.setDockBadge = setDockBadge
    }

    func begin(_ reason: Reason, activate: Bool, showBadge: Bool = false) {
        let wasInBackground = foregroundReasons.isEmpty
        foregroundReasons.insert(reason)

        if wasInBackground {
            setActivationPolicy(.regular)
        }
        if showBadge {
            setDockBadge("1")
        }
        if activate {
            activateApplication()
        }
    }

    func clearBadge() {
        setDockBadge(nil)
    }

    func end(_ reason: Reason) {
        guard foregroundReasons.remove(reason) != nil else {
            return
        }
        if reason == .update {
            clearBadge()
        }
        if foregroundReasons.isEmpty {
            setActivationPolicy(.accessory)
        }
    }
}
