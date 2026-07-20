import Foundation

final class InputSourceSelectionRequest: @unchecked Sendable {
    enum Outcome: Equatable, Sendable {
        case selected
        case alreadySelected
        case failed
        case cancelled
        case timedOutBeforeSelection
        case timedOutAfterSelection
    }

    private let lock = NSLock()
    private let completion = DispatchSemaphore(value: 0)
    private var targetID: String?
    private var outcome: Outcome?

    var isPending: Bool {
        lock.withLock {
            outcome == nil
        }
    }

    func arm(targetID: String) -> Bool {
        lock.withLock {
            guard outcome == nil else {
                return false
            }
            self.targetID = targetID
            return true
        }
    }

    @discardableResult
    func confirm(sourceID: String) -> Bool {
        let didConfirm = lock.withLock {
            guard outcome == nil, targetID == sourceID else {
                return false
            }
            outcome = .selected
            return true
        }
        if didConfirm {
            completion.signal()
        }
        return didConfirm
    }

    func complete(with newOutcome: Outcome) {
        let didComplete = lock.withLock {
            guard outcome == nil else {
                return false
            }
            outcome = newOutcome
            return true
        }
        if didComplete {
            completion.signal()
        }
    }

    func wait(timeout: DispatchTimeInterval) -> Outcome {
        if completion.wait(timeout: .now() + timeout) == .timedOut {
            completeWithTimeout()
        }

        return lock.withLock {
            outcome ?? .cancelled
        }
    }

    private func completeWithTimeout() {
        let didComplete = lock.withLock {
            guard outcome == nil else {
                return false
            }
            outcome = targetID == nil ? .timedOutBeforeSelection : .timedOutAfterSelection
            return true
        }
        if didComplete {
            completion.signal()
        }
    }
}
