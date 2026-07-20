import ApplicationServices
import Foundation
import os

final class ShiftEventMonitor: @unchecked Sendable {
    private static let selectionConfirmationTimeout: DispatchTimeInterval = .milliseconds(50)

    private struct StopState {
        let tap: CFMachPort?
        let runLoop: CFRunLoop?
        let request: InputSourceSelectionRequest?
    }

    private let inputSources: InputSourceStore
    private let onRunningStateChanged: @MainActor @Sendable () -> Void
    private let logger = Logger(subsystem: "com.kivra.app", category: "event-tap")
    private let stateLock = NSLock()
    private var classifier: ShiftTapClassifier
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var nextStartGeneration: UInt64 = 0
    private var pendingStartGeneration: UInt64?
    private var pendingSelectionRequest: InputSourceSelectionRequest?

    var isRunning: Bool {
        stateLock.withLock {
            pendingStartGeneration != nil || tap != nil
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
        classifier = ShiftTapClassifier(maximumDurationMilliseconds: thresholdMilliseconds)
    }

    @MainActor
    func start() {
        let generation = stateLock.withLock { () -> UInt64? in
            guard pendingStartGeneration == nil, tap == nil else {
                return nil
            }
            nextStartGeneration &+= 1
            pendingStartGeneration = nextStartGeneration
            return nextStartGeneration
        }
        guard let generation else {
            return
        }

        let thread = Thread { [weak self] in
            self?.installTap(generation: generation)
        }
        thread.name = "com.kivra.event-tap"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    @MainActor
    func stop() {
        let state = stateLock.withLock {
            let state = StopState(
                tap: tap,
                runLoop: runLoop,
                request: pendingSelectionRequest
            )
            pendingStartGeneration = nil
            self.tap = nil
            self.runLoop = nil
            pendingSelectionRequest = nil
            classifier.reset()
            return state
        }

        state.request?.complete(with: .cancelled)
        if let tap = state.tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoop = state.runLoop {
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
                CFRunLoopStop(runLoop)
            }
            CFRunLoopWakeUp(runLoop)
        }
    }

    @MainActor
    func updateThreshold(milliseconds: Int) {
        stateLock.withLock {
            classifier = ShiftTapClassifier(maximumDurationMilliseconds: milliseconds)
        }
    }

    private func installTap(generation: UInt64) {
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
            let didStop = stateLock.withLock {
                if pendingStartGeneration == generation {
                    pendingStartGeneration = nil
                    return true
                }
                return false
            }
            logger.error("Unable to create event tap")
            if didStop {
                notifyRunningStateChanged()
            }
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        let currentRunLoop = CFRunLoopGetCurrent()
        let shouldInstall = stateLock.withLock {
            guard pendingStartGeneration == generation else {
                return false
            }
            pendingStartGeneration = nil
            self.tap = tap
            runLoop = currentRunLoop
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
            if runLoop === currentRunLoop {
                self.tap = nil
                runLoop = nil
                return true
            }
            return false
        }
        if didStop {
            notifyRunningStateChanged()
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
            let currentTap: CFMachPort? = stateLock.withLock {
                classifier.reset()
                return self.tap
            }
            if let currentTap {
                CGEvent.tapEnable(tap: currentTap, enable: true)
            }
            logger.warning("Event tap was disabled and re-enabled")
            return Unmanaged.passUnretained(event)
        }

        let timestamp = event.timestamp
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let eventFlags = event.flags.rawValue

        let sideToSelect = stateLock.withLock { () -> ShiftSide? in
            switch type {
            case .keyDown:
                classifier.otherKeyChanged()
            case .flagsChanged:
                if let side = ShiftSide(keyCode: keyCode) {
                    let isDown = side.isPressed(
                        eventFlags: eventFlags,
                        previouslyPressed: classifier.isPressed(side)
                    )
                    if case .select(let selectedSide) = classifier.shiftChanged(
                        side: side,
                        isDown: isDown,
                        timestamp: timestamp
                    ) {
                        return selectedSide
                    }
                } else {
                    classifier.otherKeyChanged()
                }
            default:
                break
            }
            return nil
        }

        if let sideToSelect {
            waitForSelection(of: sideToSelect)
        }

        return Unmanaged.passUnretained(event)
    }

    private func waitForSelection(of side: ShiftSide) {
        let request = InputSourceSelectionRequest()
        stateLock.withLock {
            pendingSelectionRequest = request
        }

        Task { @MainActor [inputSources] in
            inputSources.select(for: side, request: request)
        }

        let outcome = request.wait(timeout: Self.selectionConfirmationTimeout)

        stateLock.withLock {
            if pendingSelectionRequest === request {
                pendingSelectionRequest = nil
            }
        }

        switch outcome {
        case .timedOutBeforeSelection:
            logger.warning("Input source selection did not start before the event deadline")
        case .timedOutAfterSelection:
            logger.warning("Input source selection was not confirmed before the event deadline")
        default:
            break
        }
    }
}
