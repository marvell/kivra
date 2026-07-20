import ApplicationServices
import XCTest

@testable import Kivra

final class ShiftTapClassifierTests: XCTestCase {
    private let millisecond: UInt64 = 1_000_000

    func testShortLeftTapSelectsLeftSource() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        XCTAssertNil(classifier.process(.shiftPressed(.left, timestamp: 0, isChorded: false)))
        XCTAssertEqual(
            classifier.process(.shiftReleased(.left, timestamp: 249 * millisecond, isChorded: false)),
            .left
        )
    }

    func testTapAtExactThresholdSelectsSource() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        _ = classifier.process(.shiftPressed(.right, timestamp: 10 * millisecond, isChorded: false))
        XCTAssertEqual(
            classifier.process(.shiftReleased(.right, timestamp: 260 * millisecond, isChorded: false)),
            .right
        )
    }

    func testAlternatingShiftEventsSelectSource() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        XCTAssertNil(classifier.process(.shiftPressed(.left, timestamp: 0, isChorded: false)))
        XCTAssertEqual(
            classifier.process(.shiftReleased(.left, timestamp: 100 * millisecond, isChorded: false)),
            .left
        )
    }

    func testLongTapDoesNotSelectSource() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        _ = classifier.process(.shiftPressed(.right, timestamp: 0, isChorded: false))
        XCTAssertEqual(
            classifier.process(.shiftReleased(.right, timestamp: 251 * millisecond, isChorded: false)),
            nil
        )
    }

    func testKeyPressedDuringShiftDoesNotSelectSource() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        _ = classifier.process(.shiftPressed(.left, timestamp: 0, isChorded: false))
        _ = classifier.process(.otherKey)
        XCTAssertEqual(
            classifier.process(.shiftReleased(.left, timestamp: 100 * millisecond, isChorded: false)),
            nil
        )
    }

    func testModifierHeldBeforeShiftDoesNotSelectSource() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        XCTAssertEqual(
            classifier.process(.shiftPressed(.left, timestamp: 0, isChorded: true)),
            nil
        )
        XCTAssertEqual(
            classifier.process(.shiftReleased(.left, timestamp: 100 * millisecond, isChorded: false)),
            nil
        )
    }

    func testInvalidTapDoesNotPoisonNextTap() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        _ = classifier.process(.shiftPressed(.left, timestamp: 0, isChorded: false))
        _ = classifier.process(.otherKey)
        XCTAssertEqual(
            classifier.process(.shiftReleased(.left, timestamp: 50 * millisecond, isChorded: false)),
            nil
        )

        _ = classifier.process(.shiftPressed(.left, timestamp: 100 * millisecond, isChorded: false))
        XCTAssertEqual(
            classifier.process(.shiftReleased(.left, timestamp: 150 * millisecond, isChorded: false)),
            .left
        )
    }

    func testOverlappingShiftsDoNotSelectEitherSource() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        _ = classifier.process(.shiftPressed(.left, timestamp: 0, isChorded: false))
        _ = classifier.process(.shiftPressed(.right, timestamp: 10 * millisecond, isChorded: false))
        XCTAssertEqual(
            classifier.process(.shiftReleased(.right, timestamp: 20 * millisecond, isChorded: false)),
            nil
        )
        XCTAssertEqual(
            classifier.process(.shiftReleased(.left, timestamp: 30 * millisecond, isChorded: false)),
            nil
        )
    }

    func testResetDiscardsPendingTap() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        _ = classifier.process(.shiftPressed(.right, timestamp: 0, isChorded: false))
        classifier.reset()
        XCTAssertEqual(
            classifier.process(.shiftReleased(.right, timestamp: 50 * millisecond, isChorded: false)),
            nil
        )
    }

    func testDuplicateDownKeepsOriginalTimestamp() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        _ = classifier.process(.shiftPressed(.right, timestamp: 0, isChorded: false))
        _ = classifier.process(.shiftPressed(.right, timestamp: 200 * millisecond, isChorded: false))
        XCTAssertEqual(
            classifier.process(.shiftReleased(.right, timestamp: 300 * millisecond, isChorded: false)),
            nil
        )
    }

    func testUnmatchedReleaseIsIgnored() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        XCTAssertEqual(
            classifier.process(.shiftReleased(.left, timestamp: 10 * millisecond, isChorded: false)),
            nil
        )
        XCTAssertFalse(classifier.isPressed(.left))
    }

    func testTimestampMovingBackwardsClearsTap() {
        var classifier = ShiftTapClassifier(maximumDurationMilliseconds: 250)

        _ = classifier.process(.shiftPressed(.left, timestamp: 100 * millisecond, isChorded: false))
        XCTAssertEqual(
            classifier.process(.shiftReleased(.left, timestamp: 99 * millisecond, isChorded: false)),
            nil
        )
        XCTAssertFalse(classifier.isPressed(.left))
    }

    func testShiftKeyCodesMapWithoutScanningAllCases() {
        XCTAssertEqual(ShiftSide(keyCode: 0x38), .left)
        XCTAssertEqual(ShiftSide(keyCode: 0x3C), .right)
        XCTAssertNil(ShiftSide(keyCode: 0x00))
    }

    func testDeviceFlagsTrackEachShiftIndependently() {
        let shiftFlag = CGEventFlags.maskShift.rawValue

        XCTAssertTrue(ShiftSide.left.isPressed(eventFlags: shiftFlag | 0x02, previouslyPressed: false))
        XCTAssertTrue(ShiftSide.right.isPressed(eventFlags: shiftFlag | 0x04, previouslyPressed: false))
        XCTAssertFalse(ShiftSide.left.isPressed(eventFlags: shiftFlag | 0x04, previouslyPressed: true))
        XCTAssertFalse(ShiftSide.right.isPressed(eventFlags: shiftFlag | 0x02, previouslyPressed: true))
        XCTAssertFalse(ShiftSide.left.isPressed(eventFlags: 0, previouslyPressed: true))
    }

    func testSynthesizedShiftEventFallsBackToSequenceState() {
        let shiftFlag = CGEventFlags.maskShift.rawValue

        XCTAssertTrue(ShiftSide.left.isPressed(eventFlags: shiftFlag, previouslyPressed: false))
        XCTAssertFalse(ShiftSide.left.isPressed(eventFlags: shiftFlag, previouslyPressed: true))
    }

    func testChordModifierDetectionExcludesCapsLock() {
        XCTAssertTrue(ShiftEventInterpreter.hasChordModifier(CGEventFlags.maskControl.rawValue))
        XCTAssertTrue(ShiftEventInterpreter.hasChordModifier(CGEventFlags.maskAlternate.rawValue))
        XCTAssertTrue(ShiftEventInterpreter.hasChordModifier(CGEventFlags.maskCommand.rawValue))
        XCTAssertTrue(ShiftEventInterpreter.hasChordModifier(CGEventFlags.maskSecondaryFn.rawValue))
        XCTAssertFalse(ShiftEventInterpreter.hasChordModifier(CGEventFlags.maskAlphaShift.rawValue))
    }
}
