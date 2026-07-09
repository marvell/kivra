import XCTest
@testable import Kivra

final class ShiftTapClassifierTests: XCTestCase {
    private let millisecond: UInt64 = 1_000_000

    func testShortLeftTapSelectsLeftSource() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        XCTAssertEqual(classifier.shiftChanged(side: .left, isDown: true, timestamp: 0), .none)
        XCTAssertEqual(
            classifier.shiftChanged(side: .left, isDown: false, timestamp: 249 * millisecond),
            .select(.left)
        )
    }

    func testAlternatingShiftEventsSelectSource() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        let firstIsDown = !classifier.isPressed(.left)
        XCTAssertEqual(classifier.shiftChanged(side: .left, isDown: firstIsDown, timestamp: 0), .none)

        let secondIsDown = !classifier.isPressed(.left)
        XCTAssertEqual(
            classifier.shiftChanged(side: .left, isDown: secondIsDown, timestamp: 100 * millisecond),
            .select(.left)
        )
    }

    func testLongTapDoesNotSelectSource() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        _ = classifier.shiftChanged(side: .right, isDown: true, timestamp: 0)
        XCTAssertEqual(
            classifier.shiftChanged(side: .right, isDown: false, timestamp: 251 * millisecond),
            .none
        )
    }

    func testKeyPressedDuringShiftDoesNotSelectSource() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        _ = classifier.shiftChanged(side: .left, isDown: true, timestamp: 0)
        classifier.otherKeyChanged()
        XCTAssertEqual(
            classifier.shiftChanged(side: .left, isDown: false, timestamp: 100 * millisecond),
            .none
        )
    }

    func testOverlappingShiftsDoNotSelectEitherSource() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        _ = classifier.shiftChanged(side: .left, isDown: true, timestamp: 0)
        _ = classifier.shiftChanged(side: .right, isDown: true, timestamp: 10 * millisecond)
        XCTAssertEqual(
            classifier.shiftChanged(side: .right, isDown: false, timestamp: 20 * millisecond),
            .none
        )
        XCTAssertEqual(
            classifier.shiftChanged(side: .left, isDown: false, timestamp: 30 * millisecond),
            .none
        )
    }

    func testResetDiscardsPendingTap() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        _ = classifier.shiftChanged(side: .right, isDown: true, timestamp: 0)
        classifier.reset()
        XCTAssertEqual(
            classifier.shiftChanged(side: .right, isDown: false, timestamp: 50 * millisecond),
            .none
        )
    }
}
