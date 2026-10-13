import XCTest

@testable import Kivra

final class ApplicationPresentationTests: XCTestCase {
    func testMonitoringStateTitles() {
        XCTAssertEqual(StatusMenuState.Monitoring.active.title, "Shift switching is on")
        XCTAssertEqual(StatusMenuState.Monitoring.active.actionTitle, "Pause")
        XCTAssertEqual(StatusMenuState.Monitoring.paused.title, "Shift switching is paused")
        XCTAssertEqual(StatusMenuState.Monitoring.paused.actionTitle, "Resume")
        XCTAssertEqual(
            StatusMenuState.Monitoring.permissionRequired.title,
            "Accessibility permission required"
        )
    }

    func testPrivacySettingsOnlyAppearWhenPermissionIsRequired() {
        XCTAssertTrue(
            StatusMenuState(
                monitoring: .permissionRequired,
                canCheckForUpdates: false
            ).showsPrivacySettings
        )
        XCTAssertFalse(
            StatusMenuState(
                monitoring: .paused,
                canCheckForUpdates: false
            ).showsPrivacySettings
        )
    }

    @MainActor
    func testPrereleaseVersionUsesBetaUpdateChannel() {
        XCTAssertEqual(
            AppUpdateController.allowedChannels(forVersion: "1.2.0-beta.1"),
            ["beta"]
        )
        XCTAssertEqual(AppUpdateController.allowedChannels(forVersion: "1.2.0"), [])
        XCTAssertEqual(AppUpdateController.allowedChannels(forVersion: nil), [])
    }
}
