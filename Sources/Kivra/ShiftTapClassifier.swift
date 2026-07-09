import Foundation

enum ShiftSide: String, CaseIterable, Sendable {
    case left
    case right

    var keyCode: UInt16 {
        switch self {
        case .left: 0x38
        case .right: 0x3C
        }
    }
}

enum ShiftTapAction: Equatable, Sendable {
    case none
    case select(ShiftSide)
}

struct ShiftTapClassifier: Sendable {
    private var pressedAt: [ShiftSide: UInt64] = [:]
    private var invalidSides: Set<ShiftSide> = []
    private var pressedSides: Set<ShiftSide> = []

    let maximumDurationNanoseconds: UInt64

    init(maximumDurationMilliseconds: Int) {
        maximumDurationNanoseconds = UInt64(maximumDurationMilliseconds) * 1_000_000
    }

    mutating func shiftChanged(side: ShiftSide, isDown: Bool, timestamp: UInt64) -> ShiftTapAction {
        if isDown {
            guard !pressedSides.contains(side) else {
                return .none
            }

            let overlapsAnotherShift = !pressedSides.isEmpty
            invalidateCandidates(except: side)
            pressedSides.insert(side)
            pressedAt[side] = timestamp
            invalidSides.remove(side)
            if overlapsAnotherShift {
                invalidSides.insert(side)
            }
            return .none
        }

        guard pressedSides.remove(side) != nil, let startedAt = pressedAt.removeValue(forKey: side) else {
            return .none
        }

        let isValid = !invalidSides.contains(side) && timestamp >= startedAt
            && timestamp - startedAt <= maximumDurationNanoseconds
        invalidSides.remove(side)
        return isValid ? .select(side) : .none
    }

    mutating func otherKeyChanged() {
        invalidateCandidates(except: nil)
    }

    mutating func reset() {
        pressedAt.removeAll()
        invalidSides.removeAll()
        pressedSides.removeAll()
    }

    func isPressed(_ side: ShiftSide) -> Bool {
        pressedSides.contains(side)
    }

    private mutating func invalidateCandidates(except allowedSide: ShiftSide?) {
        for side in pressedSides where side != allowedSide {
            invalidSides.insert(side)
        }
    }
}
