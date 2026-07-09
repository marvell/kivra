import ApplicationServices
import Foundation
import os

final class ShiftEventMonitor: @unchecked Sendable {
    private let inputSources: InputSourceStore
    private let logger = Logger(subsystem: "com.kivra.app", category: "event-tap")
    private let stateLock = NSLock()
    private var classifier: ShiftTapClassifier
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private var nextStartGeneration: UInt64 = 0
    private var pendingStartGeneration: UInt64?

    var isRunning: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return pendingStartGeneration != nil || tap != nil
    }

    init(inputSources: InputSourceStore, thresholdMilliseconds: Int) {
        self.inputSources = inputSources
        classifier = ShiftTapClassifier(maximumDurationMilliseconds: thresholdMilliseconds)
    }

    func start() {
        stateLock.lock()
        guard pendingStartGeneration == nil, tap == nil else {
            stateLock.unlock()
            return
        }
        nextStartGeneration &+= 1
        let generation = nextStartGeneration
        pendingStartGeneration = generation
        stateLock.unlock()

        let thread = Thread { [weak self] in
            self?.installTap(generation: generation)
        }
        thread.name = "com.kivra.event-tap"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    func stop() {
        stateLock.lock()
        let tap = tap
        let runLoop = runLoop
        pendingStartGeneration = nil
        self.tap = nil
        runLoopSource = nil
        self.runLoop = nil
        classifier.reset()
        stateLock.unlock()

        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoop {
            CFRunLoopStop(runLoop)
        }
    }

    func updateThreshold(milliseconds: Int) {
        stateLock.lock()
        classifier = ShiftTapClassifier(maximumDurationMilliseconds: milliseconds)
        stateLock.unlock()
    }

    private func installTap(generation: UInt64) {
        let eventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: Self.callback,
            userInfo: pointer
        ) else {
            stateLock.lock()
            if pendingStartGeneration == generation {
                pendingStartGeneration = nil
            }
            stateLock.unlock()
            logger.error("Unable to create event tap")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        let currentRunLoop = CFRunLoopGetCurrent()
        stateLock.lock()
        guard pendingStartGeneration == generation else {
            stateLock.unlock()
            CGEvent.tapEnable(tap: tap, enable: false)
            return
        }
        pendingStartGeneration = nil
        self.tap = tap
        runLoopSource = source
        runLoop = currentRunLoop
        stateLock.unlock()
        CFRunLoopAddSource(currentRunLoop, source, .commonModes)
        CFRunLoopRun()
        CFRunLoopRemoveSource(currentRunLoop, source, .commonModes)

        stateLock.lock()
        if runLoop === currentRunLoop {
            self.tap = nil
            runLoopSource = nil
            runLoop = nil
        }
        stateLock.unlock()
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
            stateLock.lock()
            classifier.reset()
            let tap = tap
            stateLock.unlock()
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            logger.warning("Event tap was disabled and re-enabled")
            return Unmanaged.passUnretained(event)
        }

        let timestamp = event.timestamp
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        stateLock.lock()
        defer { stateLock.unlock() }

        switch type {
        case .keyDown:
            classifier.otherKeyChanged()
        case .flagsChanged:
            if let side = ShiftSide.allCases.first(where: { $0.keyCode == keyCode }) {
                let isDown = CGEventSource.keyState(.combinedSessionState, key: side.keyCode)
                if case let .select(selectedSide) = classifier.shiftChanged(
                    side: side,
                    isDown: isDown,
                    timestamp: timestamp
                ) {
                    inputSources.select(id: inputSources.configuredSource(for: selectedSide))
                }
            } else {
                classifier.otherKeyChanged()
            }
        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }
}
