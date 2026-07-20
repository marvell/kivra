import ApplicationServices
import Foundation
import os

final class ShiftEventMonitor: @unchecked Sendable {
    private static let selectionConfirmationTimeout: DispatchTimeInterval = .milliseconds(50)
    private final class StartToken: @unchecked Sendable {}

    private final class TapSession {
        let tap: CFMachPort
        let runLoop: CFRunLoop

        init(tap: CFMachPort, runLoop: CFRunLoop) {
            self.tap = tap
            self.runLoop = runLoop
        }
    }

    private enum Lifecycle {
        case stopped
        case starting(StartToken)
        case running(TapSession)
    }

    private struct State {
        var interpreter: ShiftEventInterpreter
        var lifecycle: Lifecycle = .stopped
        var pendingSelectionGate: SelectionGate?
    }

    private let inputSources: InputSourceStore
    private let onRunningStateChanged: @MainActor @Sendable () -> Void
    private let logger = Logger(subsystem: "com.kivra.app", category: "event-tap")
    private let stateLock = NSLock()
    private var state: State

    var isRunning: Bool {
        stateLock.withLock {
            if case .stopped = state.lifecycle {
                return false
            }
            return true
        }
    }

    @MainActor
    init(
        inputSources: InputSourceStore,
        thresholdMilliseconds: Int,
        onRunningStateChanged: @escaping @MainActor @Sendable () -> Void
    ) {
        self.inputSources = inputSources
        self.onRunningStateChanged = onRunningStateChanged
        state = State(interpreter: ShiftEventInterpreter(thresholdMilliseconds: thresholdMilliseconds))
    }

    @MainActor
    func start() {
        let token = stateLock.withLock { () -> StartToken? in
            guard case .stopped = state.lifecycle else {
                return nil
            }
            let token = StartToken()
            state.lifecycle = .starting(token)
            return token
        }
        guard let token else {
            return
        }

        let thread = Thread { [weak self] in
            self?.installTap(token: token)
        }
        thread.name = "com.kivra.event-tap"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    @MainActor
    func stop() {
        let (session, gate) = stateLock.withLock { () -> (TapSession?, SelectionGate?) in
            let session: TapSession?
            if case .running(let currentSession) = state.lifecycle {
                session = currentSession
            } else {
                session = nil
            }
            state.lifecycle = .stopped
            state.interpreter.reset()
            let gate = state.pendingSelectionGate
            state.pendingSelectionGate = nil
            return (session, gate)
        }

        gate?.finish()
        if let session {
            CGEvent.tapEnable(tap: session.tap, enable: false)
        }
        if let session {
            CFRunLoopPerformBlock(session.runLoop, CFRunLoopMode.commonModes.rawValue) {
                CFRunLoopStop(session.runLoop)
            }
            CFRunLoopWakeUp(session.runLoop)
        }
    }

    @MainActor
    func updateThreshold(milliseconds: Int) {
        stateLock.withLock {
            state.interpreter.updateThreshold(milliseconds: milliseconds)
        }
    }

    private func installTap(token: StartToken) {
        let eventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(eventMask),
                callback: Self.callback,
                userInfo: pointer
            )
        else {
            let didStop = stopStarting(token)
            logger.error("Unable to create event tap")
            if didStop {
                notifyRunningStateChanged()
            }
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        guard let currentRunLoop = CFRunLoopGetCurrent() else {
            CFMachPortInvalidate(tap)
            if stopStarting(token) {
                notifyRunningStateChanged()
            }
            return
        }
        let session = TapSession(tap: tap, runLoop: currentRunLoop)
        let shouldInstall = stateLock.withLock {
            guard case .starting(let pendingToken) = state.lifecycle, pendingToken === token else {
                return false
            }
            state.lifecycle = .running(session)
            return true
        }
        guard shouldInstall else {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            return
        }

        CFRunLoopAddSource(currentRunLoop, source, .commonModes)
        CFRunLoopRun()
        CFRunLoopRemoveSource(currentRunLoop, source, .commonModes)
        CFMachPortInvalidate(tap)

        let didStop = stateLock.withLock {
            if case .running(let activeSession) = state.lifecycle, activeSession === session {
                state.lifecycle = .stopped
                return true
            }
            return false
        }
        if didStop {
            notifyRunningStateChanged()
        }
    }

    private func stopStarting(_ token: StartToken) -> Bool {
        stateLock.withLock {
            guard case .starting(let pendingToken) = state.lifecycle, pendingToken === token else {
                return false
            }
            state.lifecycle = .stopped
            return true
        }
    }

    private func notifyRunningStateChanged() {
        Task { @MainActor [onRunningStateChanged] in
            onRunningStateChanged()
        }
    }

    private static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }
        let monitor = Unmanaged<ShiftEventMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        return monitor.handle(type: type, event: event)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            let currentTap = stateLock.withLock { () -> CFMachPort? in
                state.interpreter.reset()
                guard case .running(let session) = state.lifecycle else {
                    return nil
                }
                CGEvent.tapEnable(tap: session.tap, enable: true)
                return session.tap
            }
            if currentTap != nil {
                logger.warning("Event tap was disabled and re-enabled")
            }
            return Unmanaged.passUnretained(event)
        }

        let sideToSelect = stateLock.withLock {
            state.interpreter.process(
                type: type,
                keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
                flags: event.flags.rawValue,
                timestamp: event.timestamp
            )
        }

        if let sideToSelect {
            waitForSelection(of: sideToSelect)
        }

        return Unmanaged.passUnretained(event)
    }

    private func waitForSelection(of side: ShiftSide) {
        let gate = SelectionGate()
        let didRegister = stateLock.withLock {
            guard case .running = state.lifecycle else {
                return false
            }
            state.pendingSelectionGate = gate
            return true
        }
        guard didRegister else {
            return
        }

        Task { @MainActor [inputSources] in
            inputSources.select(for: side, gate: gate)
        }

        let result = gate.wait(timeout: Self.selectionConfirmationTimeout)

        stateLock.withLock {
            if state.pendingSelectionGate === gate {
                state.pendingSelectionGate = nil
            }
        }

        switch result {
        case .timedOutBeforeStart:
            logger.warning("Input source selection did not start before the event deadline")
        case .timedOutAfterStart:
            logger.warning("Input source selection was not confirmed before the event deadline")
        case .completed:
            break
        }
    }
}
