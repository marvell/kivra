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
        XCTAssertEqual(state.monitoring.actionTitle, "Grant Access…")
        XCTAssertEqual(state.updateTitle, "Update 0.6.0 Ready…")
    }

    func testMenuListsAssignedLayouts() {
        let state = StatusMenuState(
            monitoring: .active,
            canCheckForUpdates: false,
            leftLayoutName: "ABC",
            rightLayoutName: nil
        )
        XCTAssertEqual(
            state.layoutTitles,
            ["Left Shift: ABC", "Right Shift: Not available"]
        )
    }

    func testStatusIconReflectsMonitoringAndUpdates() {
        XCTAssertEqual(
            StatusMenuState(monitoring: .active, canCheckForUpdates: true).statusIcon,
            StatusIcon()
        )
        XCTAssertEqual(
            StatusMenuState(monitoring: .paused, canCheckForUpdates: true).statusIcon,
            StatusIcon(isDimmed: true)
        )
        XCTAssertEqual(
            StatusMenuState(
                monitoring: .active,
                canCheckForUpdates: true,
                updateAvailability: .available(version: "0.6.0")
            ).statusIcon,
            StatusIcon(badge: .update)
        )
        XCTAssertEqual(
            StatusMenuState(
                monitoring: .permissionRequired,
                canCheckForUpdates: true,
                updateAvailability: .available(version: "0.6.0")
            ).statusIcon,
            StatusIcon(isDimmed: true, badge: .warning)
        )
    }

    @MainActor
    func testStatusImagesRenderAsTemplates() throws {
        let normal = try XCTUnwrap(StatusMenuController.statusImage(StatusIcon()))
        let dimmed = try XCTUnwrap(StatusMenuController.statusImage(StatusIcon(isDimmed: true)))
        let badged = try XCTUnwrap(StatusMenuController.statusImage(StatusIcon(badge: .update)))
        let warning = try XCTUnwrap(
            StatusMenuController.statusImage(StatusIcon(isDimmed: true, badge: .warning))
        )
        for image in [normal, dimmed, badged, warning] {
            XCTAssertTrue(image.isTemplate)
            XCTAssertNotNil(image.tiffRepresentation)
        }
        XCTAssertEqual(dimmed.size, NSSize(width: 18, height: 18))
        XCTAssertEqual(badged.size, NSSize(width: 28, height: 18))
        XCTAssertNotEqual(normal.tiffRepresentation, badged.tiffRepresentation)
        XCTAssertNotEqual(badged.tiffRepresentation, warning.tiffRepresentation)
    }
}
