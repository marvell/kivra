import ApplicationServices
import XCTest

@testable import Kivra

final class ShiftEventInterpreterTests: XCTestCase {
    private let millisecond: UInt64 = 1_000_000

    func testQuickLeftTapSelectsLeftSide() {
        var interpreter = ShiftEventInterpreter(thresholdMilliseconds: 250)

        XCTAssertNil(processShift(&interpreter, side: .left, flags: 0x02, timestamp: 0))
        XCTAssertEqual(
            processShift(&interpreter, side: .left, flags: 0, timestamp: 100 * millisecond),
            .left
        )
    }

    func testQuickRightTapSelectsRightSide() {
        var interpreter = ShiftEventInterpreter(thresholdMilliseconds: 250)

        XCTAssertNil(processShift(&interpreter, side: .right, flags: 0x04, timestamp: 0))
        XCTAssertEqual(
            processShift(&interpreter, side: .right, flags: 0, timestamp: 100 * millisecond),
            .right
        )
    }

    func testOtherKeyCancelsTap() {
        var interpreter = ShiftEventInterpreter(thresholdMilliseconds: 250)

        _ = processShift(&interpreter, side: .left, flags: 0x02, timestamp: 0)
        XCTAssertNil(
            interpreter.process(type: .keyDown, keyCode: 0, flags: 0, timestamp: 10 * millisecond)
        )
        XCTAssertNil(
            processShift(&interpreter, side: .left, flags: 0, timestamp: 100 * millisecond)
        )
    }

    func testChordModifiersCancelTap() {
        let modifiers: [CGEventFlags] = [
            .maskControl,
            .maskAlternate,
            .maskCommand,
            .maskSecondaryFn,
        ]

        for modifier in modifiers {
            var interpreter = ShiftEventInterpreter(thresholdMilliseconds: 250)
            let flags = modifier.rawValue | ShiftSide.left.deviceFlagMask

            XCTAssertNil(processShift(&interpreter, side: .left, flags: flags, timestamp: 0))
            XCTAssertNil(
                processShift(&interpreter, side: .left, flags: 0, timestamp: 100 * millisecond)
            )
        }
    }

    func testResetDiscardsPendingTap() {
        var interpreter = ShiftEventInterpreter(thresholdMilliseconds: 250)

        _ = processShift(&interpreter, side: .right, flags: 0x04, timestamp: 0)
        interpreter.reset()

        XCTAssertNil(
            processShift(&interpreter, side: .right, flags: 0, timestamp: 100 * millisecond)
        )
    }

    func testThresholdUpdateReplacesClassifier() {
        var interpreter = ShiftEventInterpreter(thresholdMilliseconds: 250)

        _ = processShift(&interpreter, side: .left, flags: 0x02, timestamp: 0)
        interpreter.updateThreshold(milliseconds: 50)
        XCTAssertNil(
            processShift(&interpreter, side: .left, flags: 0, timestamp: 10 * millisecond)
        )

        _ = processShift(&interpreter, side: .left, flags: 0x02, timestamp: 100 * millisecond)
        XCTAssertNil(
            processShift(&interpreter, side: .left, flags: 0, timestamp: 151 * millisecond)
        )
    }

    private func processShift(
        _ interpreter: inout ShiftEventInterpreter,
        side: ShiftSide,
        flags: UInt64,
        timestamp: UInt64
    ) -> ShiftSide? {
        interpreter.process(
            type: .flagsChanged,
            keyCode: side.keyCode,
            flags: flags,
            timestamp: timestamp
        )
    }
}
