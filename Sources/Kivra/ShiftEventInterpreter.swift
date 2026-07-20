import ApplicationServices

struct ShiftEventInterpreter: Sendable {
    private static let chordModifierFlags: UInt64 =
        CGEventFlags.maskControl.rawValue
        | CGEventFlags.maskAlternate.rawValue
        | CGEventFlags.maskCommand.rawValue
        | CGEventFlags.maskSecondaryFn.rawValue

    private var classifier: ShiftTapClassifier

    init(thresholdMilliseconds: Int) {
        classifier = ShiftTapClassifier(maximumDurationMilliseconds: thresholdMilliseconds)
    }

    static func hasChordModifier(_ flags: UInt64) -> Bool {
        flags & chordModifierFlags != 0
    }

    mutating func process(
        type: CGEventType,
        keyCode: UInt16,
        flags: UInt64,
        timestamp: UInt64
    ) -> ShiftSide? {
        switch type {
        case .keyDown:
            return classifier.process(.otherKey)
        case .flagsChanged:
            guard let side = ShiftSide(keyCode: keyCode) else {
                return classifier.process(.otherKey)
            }
            let isChorded = Self.hasChordModifier(flags)
            if side.isPressed(
                eventFlags: flags,
                previouslyPressed: classifier.isPressed(side)
            ) {
                return classifier.process(
                    .shiftPressed(side, timestamp: timestamp, isChorded: isChorded)
                )
            }
            return classifier.process(
                .shiftReleased(side, timestamp: timestamp, isChorded: isChorded)
            )
        default:
            return nil
        }
    }

    mutating func reset() {
        classifier.reset()
    }

    mutating func updateThreshold(milliseconds: Int) {
        classifier = ShiftTapClassifier(maximumDurationMilliseconds: milliseconds)
    }
}
