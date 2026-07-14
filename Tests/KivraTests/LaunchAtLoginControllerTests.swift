import ServiceManagement
import XCTest

@testable import Kivra

final class LaunchAtLoginControllerTests: XCTestCase {
    func testMapsServiceStatuses() {
        XCTAssertEqual(
            LaunchAtLoginState(serviceStatus: .enabled),
            .enabled
        )
        XCTAssertEqual(
            LaunchAtLoginState(serviceStatus: .notRegistered),
            .disabled
        )
        XCTAssertEqual(
            LaunchAtLoginState(serviceStatus: .requiresApproval),
            .requiresApproval
        )
        XCTAssertEqual(
            LaunchAtLoginState(serviceStatus: .notFound),
            .disabled
        )
    }

    @MainActor
    func testEnablingRegistersMainApp() throws {
        let service = FakeLaunchAtLoginService(status: .disabled)
        let controller = LaunchAtLoginController(service: service, isAppBundle: { true })

        try controller.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertEqual(controller.state, .enabled)
    }

    @MainActor
    func testDisablingUnregistersMainApp() throws {
        let service = FakeLaunchAtLoginService(status: .enabled)
        let controller = LaunchAtLoginController(service: service, isAppBundle: { true })

        try controller.setEnabled(false)

        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(controller.state, .disabled)
    }

    @MainActor
    func testMatchingSelectionDoesNotChangeLoginItems() throws {
        let service = FakeLaunchAtLoginService(status: .disabled)
        let controller = LaunchAtLoginController(service: service, isAppBundle: { true })

        try controller.setEnabled(false)

        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(service.unregisterCallCount, 0)
    }

    @MainActor
    func testUsesCurrentStatusWhenApplyingSelection() throws {
        let service = FakeLaunchAtLoginService(status: .disabled)
        let controller = LaunchAtLoginController(service: service, isAppBundle: { true })
        service.status = .enabled

        try controller.setEnabled(false)

        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(controller.state, .disabled)
    }

    @MainActor
    func testUnavailableOutsideAppBundleDoesNotChangeLoginItems() throws {
        let service = FakeLaunchAtLoginService(status: .disabled)
        let controller = LaunchAtLoginController(service: service, isAppBundle: { false })

        try controller.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertEqual(controller.state, .unavailable)
    }

    @MainActor
    func testRegistrationFailureRefreshesStatus() {
        let service = FakeLaunchAtLoginService(status: .disabled)
        service.registerError = TestError.failed
        let controller = LaunchAtLoginController(service: service, isAppBundle: { true })

        XCTAssertThrowsError(try controller.setEnabled(true))
        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(controller.state, .disabled)
    }

    @MainActor
    func testOpensLoginItemsSettings() {
        let service = FakeLaunchAtLoginService(status: .requiresApproval)
        let controller = LaunchAtLoginController(service: service, isAppBundle: { true })

        controller.openLoginItemsSettings()

        XCTAssertEqual(service.openSettingsCallCount, 1)
    }
}

@MainActor
private final class FakeLaunchAtLoginService: LaunchAtLoginServicing {
    var status: LaunchAtLoginState
    var registerCallCount = 0
    var unregisterCallCount = 0
    var openSettingsCallCount = 0
    var registerError: Error?
    var unregisterError: Error?

    init(status: LaunchAtLoginState) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1
        if let registerError {
            throw registerError
        }
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError {
            throw unregisterError
        }
        status = .disabled
    }

    func openLoginItemsSettings() {
        openSettingsCallCount += 1
    }
}

private enum TestError: Error {
    case failed
}
