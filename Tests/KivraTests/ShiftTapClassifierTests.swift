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

    func testTapAtExactThresholdSelectsSource() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        _ = classifier.shiftChanged(side: .right, isDown: true, timestamp: 10 * millisecond)
        XCTAssertEqual(
            classifier.shiftChanged(side: .right, isDown: false, timestamp: 260 * millisecond),
            .select(.right)
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

    func testInvalidTapDoesNotPoisonNextTap() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        _ = classifier.shiftChanged(side: .left, isDown: true, timestamp: 0)
        classifier.otherKeyChanged()
        XCTAssertEqual(
            classifier.shiftChanged(side: .left, isDown: false, timestamp: 50 * millisecond),
            .none
        )

        _ = classifier.shiftChanged(side: .left, isDown: true, timestamp: 100 * millisecond)
        XCTAssertEqual(
            classifier.shiftChanged(side: .left, isDown: false, timestamp: 150 * millisecond),
            .select(.left)
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

    func testDuplicateDownKeepsOriginalTimestamp() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        _ = classifier.shiftChanged(side: .right, isDown: true, timestamp: 0)
        _ = classifier.shiftChanged(side: .right, isDown: true, timestamp: 200 * millisecond)
        XCTAssertEqual(
            classifier.shiftChanged(side: .right, isDown: false, timestamp: 300 * millisecond),
            .none
        )
    }

    func testUnmatchedReleaseIsIgnored() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        XCTAssertEqual(
            classifier.shiftChanged(side: .left, isDown: false, timestamp: 10 * millisecond),
            .none
        )
        XCTAssertFalse(classifier.isPressed(.left))
    }

    func testTimestampMovingBackwardsClearsTap() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        _ = classifier.shiftChanged(side: .left, isDown: true, timestamp: 100 * millisecond)
        XCTAssertEqual(
            classifier.shiftChanged(side: .left, isDown: false, timestamp: 99 * millisecond),
            .none
        )
        XCTAssertFalse(classifier.isPressed(.left))
    }

    func testShiftKeyCodesMapWithoutScanningAllCases() {
        XCTAssertEqual(ShiftSide(keyCode: 0x38), .left)
        XCTAssertEqual(ShiftSide(keyCode: 0x3C), .right)
        XCTAssertNil(ShiftSide(keyCode: 0x00))
    }

    func testDeviceFlagsTrackEachShiftIndependently() {
        let shiftFlag: UInt64 = 0x0002_0000

        XCTAssertTrue(ShiftSide.left.isPressed(eventFlags: shiftFlag | 0x02, previouslyPressed: false))
        XCTAssertTrue(ShiftSide.right.isPressed(eventFlags: shiftFlag | 0x04, previouslyPressed: false))
        XCTAssertFalse(ShiftSide.left.isPressed(eventFlags: shiftFlag | 0x04, previouslyPressed: true))
        XCTAssertFalse(ShiftSide.right.isPressed(eventFlags: shiftFlag | 0x02, previouslyPressed: true))
        XCTAssertFalse(ShiftSide.left.isPressed(eventFlags: 0, previouslyPressed: true))
    }

    func testSynthesizedShiftEventFallsBackToSequenceState() {
        let shiftFlag: UInt64 = 0x0002_0000

        XCTAssertTrue(ShiftSide.left.isPressed(eventFlags: shiftFlag, previouslyPressed: false))
        XCTAssertFalse(ShiftSide.left.isPressed(eventFlags: shiftFlag, previouslyPressed: true))
    }
}
