enum ShiftSide: String, Sendable {
    case left
    case right

    init?(keyCode: UInt16) {
        switch keyCode {
        case Self.left.keyCode: self = .left
        case Self.right.keyCode: self = .right
        default: return nil
        }
    }

    var keyCode: UInt16 {
        switch self {
        case .left: 0x38
        case .right: 0x3C
        }
    }

    // Quartz preserves the device-dependent modifier bits from IOLLEvent.h
    // even though CGEventFlags only names the device-independent masks.
    var deviceFlagMask: UInt64 {
        switch self {
        case .left: 0x02
        case .right: 0x04
        }
    }

    func isPressed(eventFlags: UInt64, previouslyPressed: Bool) -> Bool {
        let shiftDeviceFlags: UInt64 = 0x02 | 0x04
        let shiftFlag: UInt64 = 0x0002_0000
        if eventFlags & deviceFlagMask != 0 {
            return true
        }
        if eventFlags & shiftDeviceFlags != 0 || eventFlags & shiftFlag == 0 {
            return false
        }

        // Synthesized events may omit device-dependent left/right bits.
        return !previouslyPressed
    }
}

enum ShiftTapAction: Equatable, Sendable {
    case none
    case select(ShiftSide)
}

struct ShiftTapClassifier: Sendable {
    private struct State: Sendable {
        var pressedAt: UInt64 = 0
        var isPressed = false
        var isInvalid = false
    }

    private var left = State()
    private var right = State()

    let maximumDurationNanoseconds: UInt64

    init(maximumDurationMilliseconds: Int) {
        maximumDurationNanoseconds = UInt64(maximumDurationMilliseconds) * 1_000_000
    }

    mutating func shiftChanged(side: ShiftSide, isDown: Bool, timestamp: UInt64) -> ShiftTapAction {
        if isDown {
            switch side {
            case .left:
                guard !left.isPressed else {
                    return .none
                }
                let overlapsRight = right.isPressed
                right.isInvalid = right.isInvalid || overlapsRight
                left = State(pressedAt: timestamp, isPressed: true, isInvalid: overlapsRight)
            case .right:
                guard !right.isPressed else {
                    return .none
                }
                let overlapsLeft = left.isPressed
                left.isInvalid = left.isInvalid || overlapsLeft
                right = State(pressedAt: timestamp, isPressed: true, isInvalid: overlapsLeft)
            }
            return .none
        }

        let isValid: Bool
        switch side {
        case .left:
            isValid = Self.release(&left, timestamp: timestamp, maximumDuration: maximumDurationNanoseconds)
        case .right:
            isValid = Self.release(&right, timestamp: timestamp, maximumDuration: maximumDurationNanoseconds)
        }
        return isValid ? .select(side) : .none
    }

    mutating func otherKeyChanged() {
        left.isInvalid = left.isInvalid || left.isPressed
        right.isInvalid = right.isInvalid || right.isPressed
    }

    mutating func reset() {
        left = State()
        right = State()
    }

    func isPressed(_ side: ShiftSide) -> Bool {
        switch side {
        case .left: left.isPressed
        case .right: right.isPressed
        }
    }

    private static func release(
        _ state: inout State,
        timestamp: UInt64,
        maximumDuration: UInt64
    ) -> Bool {
        guard state.isPressed else {
            return false
        }

        let startedAt = state.pressedAt
        let isValid = !state.isInvalid && timestamp >= startedAt
            && timestamp - startedAt <= maximumDuration
        state = State()
        return isValid
    }
}
