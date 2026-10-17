import AppKit
import XCTest

@testable import Kivra

final class StatusMenuUpdateTests: XCTestCase {
    func testStatusIconReflectsMonitoringAndUpdates() {
        XCTAssertEqual(
            StatusMenuState(monitoring: .active).statusIcon,
            StatusIcon()
        )
        XCTAssertEqual(
            StatusMenuState(monitoring: .paused).statusIcon,
            StatusIcon(isDimmed: true)
        )
        XCTAssertEqual(
            StatusMenuState(
                monitoring: .active,
                updateAvailability: .available(version: "0.6.0")
            ).statusIcon,
            StatusIcon(badge: .update)
        )
        XCTAssertEqual(
            StatusMenuState(
                monitoring: .permissionRequired,
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
