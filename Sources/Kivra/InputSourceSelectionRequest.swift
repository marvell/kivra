import Foundation

final class SelectionGate: @unchecked Sendable {
    enum WaitResult: Equatable, Sendable {
        case completed
        case timedOutBeforeStart
        case timedOutAfterStart
    }

    private let lock = NSLock()
    private let completion = DispatchSemaphore(value: 0)
    private var isStarted = false
    private var result: WaitResult?

    var isPending: Bool {
        lock.withLock {
            result == nil
        }
    }

    func start() -> Bool {
        lock.withLock {
            guard result == nil, !isStarted else {
                return false
            }
            isStarted = true
            return true
        }
    }

    @discardableResult
    func finish() -> Bool {
        complete(with: .completed, shouldSignal: true)
    }

    func wait(timeout: DispatchTimeInterval) -> WaitResult {
        if let result = lock.withLock({ result }) {
            return result
        }

        if completion.wait(timeout: .now() + timeout) == .timedOut {
            completeWithTimeout()
        }

        return lock.withLock {
            result ?? .completed
        }
    }

    private func complete(with newResult: WaitResult, shouldSignal: Bool) -> Bool {
        let didComplete = lock.withLock {
            guard result == nil else {
                return false
            }
            result = newResult
            return true
        }
        if didComplete && shouldSignal {
            completion.signal()
        }
        return didComplete
    }

    private func completeWithTimeout() {
        lock.withLock {
            guard result == nil else {
                return
            }
            result = isStarted ? .timedOutAfterStart : .timedOutBeforeStart
        }
    }
}
