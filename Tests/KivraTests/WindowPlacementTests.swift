import AppKit
import XCTest

@testable import Kivra

final class WindowPlacementTests: XCTestCase {
    func testWindowIsCenteredHorizontallyAndRaised() {
        let screen = NSRect(x: 0, y: 0, width: 1000, height: 800)
        let size = NSSize(width: 400, height: 400)

        let origin = WindowPlacement.origin(for: size, in: screen)

        XCTAssertEqual(origin.x, 300)
        // Centered would leave 200 pt above; raising by 20% of 800 pt leaves 40.
        XCTAssertEqual(origin.y, 360)
    }

    func testPlacementRespectsScreenOffset() {
        let screen = NSRect(x: 1440, y: 25, width: 1000, height: 800)
        let origin = WindowPlacement.origin(for: NSSize(width: 400, height: 400), in: screen)

        XCTAssertEqual(origin.x, 1740)
        XCTAssertEqual(origin.y, 385)
    }

    func testRaisedWindowStaysBelowTopOfScreen() {
        let screen = NSRect(x: 0, y: 0, width: 1000, height: 800)
        let origin = WindowPlacement.origin(for: NSSize(width: 400, height: 700), in: screen)

        XCTAssertEqual(origin.y, 100)
    }

    func testTallWindowStartsAtTopOfVisibleFrame() {
        let screen = NSRect(x: 0, y: 0, width: 1000, height: 500)
        let origin = WindowPlacement.origin(for: NSSize(width: 400, height: 600), in: screen)

        XCTAssertEqual(origin.y, -100)
    }
}
