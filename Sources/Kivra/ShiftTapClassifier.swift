import ApplicationServices
import Carbon.HIToolbox

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
        case .left: UInt16(kVK_Shift)
        case .right: UInt16(kVK_RightShift)
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
        let shiftFlag = CGEventFlags.maskShift.rawValue
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

struct ShiftTapClassifier: Sendable {
    enum Input: Sendable {
        case shiftPressed(ShiftSide, timestamp: UInt64, isChorded: Bool)
        case shiftReleased(ShiftSide, timestamp: UInt64, isChorded: Bool)
        case otherKey
    }

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

    mutating func process(_ input: Input) -> ShiftSide? {
        switch input {
        case .otherKey:
            invalidateActiveTaps()
            return nil
        case .shiftPressed(let side, let timestamp, let isChorded):
            press(side, timestamp: timestamp, isChorded: isChorded)
            return nil
        case .shiftReleased(let side, let timestamp, let isChorded):
            return release(side, timestamp: timestamp, isChorded: isChorded) ? side : nil
        }
    }

    mutating func reset() {
        left = State()
        right = State()
    }

    func isPressed(_ side: ShiftSide) -> Bool {
        state(for: side).isPressed
    }

    private mutating func press(_ side: ShiftSide, timestamp: UInt64, isChorded: Bool) {
        guard !state(for: side).isPressed else {
            return
        }
        let oppositeSide = side == .left ? ShiftSide.right : .left
        let overlapsOtherShift = state(for: oppositeSide).isPressed
        if overlapsOtherShift {
            withState(for: oppositeSide) { $0.isInvalid = true }
        }
        withState(for: side) {
            $0 = State(
                pressedAt: timestamp,
                isPressed: true,
                isInvalid: overlapsOtherShift || isChorded
            )
        }
    }

    private mutating func release(_ side: ShiftSide, timestamp: UInt64, isChorded: Bool) -> Bool {
        withState(for: side) {
            $0.isInvalid = $0.isInvalid || isChorded
        }
        let maximumDuration = maximumDurationNanoseconds
        return withState(for: side) {
            Self.release(&$0, timestamp: timestamp, maximumDuration: maximumDuration)
        }
    }

    private mutating func invalidateActiveTaps() {
        left.isInvalid = left.isInvalid || left.isPressed
        right.isInvalid = right.isInvalid || right.isPressed
    }

    private func state(for side: ShiftSide) -> State {
        switch side {
        case .left: left
        case .right: right
        }
    }

    private mutating func withState<T>(for side: ShiftSide, _ body: (inout State) -> T) -> T {
        switch side {
        case .left:
            return body(&left)
        case .right:
            return body(&right)
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
        let isValid =
            !state.isInvalid && timestamp >= startedAt
            && timestamp - startedAt <= maximumDuration
        state = State()
        return isValid
    }
}
