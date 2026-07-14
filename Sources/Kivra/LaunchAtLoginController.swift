import Foundation
import ServiceManagement

enum LaunchAtLoginState: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable

    var isEnabled: Bool {
        switch self {
        case .enabled, .requiresApproval:
            true
        case .disabled, .unavailable:
            false
        }
    }

    var isAvailable: Bool {
        self != .unavailable
    }

    init(serviceStatus: SMAppService.Status) {
        switch serviceStatus {
        case .enabled:
            self = .enabled
        case .notRegistered, .notFound:
            self = .disabled
        case .requiresApproval:
            self = .requiresApproval
        @unknown default:
            self = .unavailable
        }
    }
}

@MainActor
protocol LaunchAtLoginControlling: AnyObject {
    var state: LaunchAtLoginState { get }

    func refresh()
    func setEnabled(_ enabled: Bool) throws
    func openLoginItemsSettings()
}

@MainActor
protocol LaunchAtLoginServicing: AnyObject {
    var status: LaunchAtLoginState { get }

    func register() throws
    func unregister() throws
    func openLoginItemsSettings()
}

@MainActor
final class LaunchAtLoginController: LaunchAtLoginControlling {
    private let service: any LaunchAtLoginServicing
    private let isAppBundle: () -> Bool
    private(set) var state: LaunchAtLoginState = .unavailable

    init(
        service: any LaunchAtLoginServicing = SystemLaunchAtLoginService(),
        isAppBundle: @escaping () -> Bool = {
            Bundle.main.bundleURL.pathExtension == "app"
        }
    ) {
        self.service = service
        self.isAppBundle = isAppBundle
        refresh()
    }

    func refresh() {
        state = isAppBundle() ? service.status : .unavailable
    }

    func setEnabled(_ enabled: Bool) throws {
        guard isAppBundle() else {
            refresh()
            return
        }

        refresh()
        guard state.isEnabled != enabled else { return }

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            refresh()
            throw error
        }

        refresh()
    }

    func openLoginItemsSettings() {
        service.openLoginItemsSettings()
    }
}

@MainActor
private final class SystemLaunchAtLoginService: LaunchAtLoginServicing {
    var status: LaunchAtLoginState {
        LaunchAtLoginState(serviceStatus: SMAppService.mainApp.status)
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
