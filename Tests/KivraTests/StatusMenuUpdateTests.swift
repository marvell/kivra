import AppKit
import XCTest

@testable import Kivra

final class StatusMenuUpdateTests: XCTestCase {
    func testDefaultMenuOffersUpdateCheck() {
        let state = StatusMenuState(monitoring: .active, canCheckForUpdates: true)
        XCTAssertNil(state.updateAvailability)
        XCTAssertEqual(state.updateTitle, "Check for Updates…")
    }

    func testUpdateTitlesIncludeVersionAndReadiness() {
        var state = StatusMenuState(
            monitoring: .active,
            canCheckForUpdates: true,
            updateAvailability: .available(version: "0.6.0")
        )
        XCTAssertEqual(state.updateTitle, "Update 0.6.0 Available…")
        state.updateAvailability = .ready(version: "0.6.0")
        XCTAssertEqual(state.updateTitle, "Update 0.6.0 Ready…")
    }

    func testUpdateDoesNotReplaceMonitoringOrPermissionState() {
        let state = StatusMenuState(
            monitoring: .permissionRequired,
            canCheckForUpdates: true,
            updateAvailability: .ready(version: "0.6.0")
        )
        XCTAssertTrue(state.showsPrivacySettings)
        XCTAssertEqual(state.monitoring.actionTitle, "Enable")
        XCTAssertEqual(state.updateTitle, "Update 0.6.0 Ready…")
    }

    @MainActor
    func testStatusImagesRenderAsTemplates() throws {
        let normal = try XCTUnwrap(StatusMenuController.statusImage(hasUpdate: false))
        let badged = try XCTUnwrap(StatusMenuController.statusImage(hasUpdate: true))
        XCTAssertTrue(normal.isTemplate)
        XCTAssertTrue(badged.isTemplate)
        XCTAssertEqual(badged.size, NSSize(width: 28, height: 18))
        XCTAssertNotNil(normal.tiffRepresentation)
        XCTAssertNotNil(badged.tiffRepresentation)
        XCTAssertNotEqual(normal.tiffRepresentation, badged.tiffRepresentation)
    }
}
