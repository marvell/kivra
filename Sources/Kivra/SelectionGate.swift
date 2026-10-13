import Foundation

final class SelectionGate: @unchecked Sendable {
    enum WaitResult: Equatable, Sendable {
        case completed
        case timedOutBeforeStart
        case timedOutAfterStart
    }

    private enum State {
        case waitingToStart
        case started
        case finished(WaitResult)
    }

    private let lock = NSLock()
    private let completion = DispatchSemaphore(value: 0)
    private var state = State.waitingToStart

    var isPending: Bool {
        lock.withLock {
            if case .finished = state {
                return false
            }
            return true
        }
    }

    func start() -> Bool {
        lock.withLock {
            guard case .waitingToStart = state else {
                return false
            }
            state = .started
            return true
        }
    }

    @discardableResult
    func finish() -> Bool {
        complete(with: .completed)
    }

    func wait(timeout: DispatchTimeInterval) -> WaitResult {
        if let result = finishedResult {
            return result
        }

        if completion.wait(timeout: .now() + timeout) == .timedOut {
            completeWithTimeout()
        }

        return finishedResult ?? .completed
    }

    private var finishedResult: WaitResult? {
        lock.withLock {
            guard case .finished(let result) = state else {
                return nil
            }
            return result
        }
    }

    private func complete(with result: WaitResult) -> Bool {
        let didComplete = lock.withLock {
            switch state {
            case .waitingToStart, .started:
                state = .finished(result)
                return true
            case .finished:
                return false
            }
        }
        if didComplete {
            completion.signal()
        }
        return didComplete
    }

    private func completeWithTimeout() {
        lock.withLock {
            switch state {
            case .waitingToStart:
                state = .finished(.timedOutBeforeStart)
            case .started:
                state = .finished(.timedOutAfterStart)
            case .finished:
                return
            }
        }
    }
}
