import ApplicationServices
import Foundation
import os

@MainActor
final class ShiftEventMonitor {
    private let inputSources: InputSourceStore
    private let logger = Logger(subsystem: "com.kivra.app", category: "event-tap")
    private var classifier: ShiftTapClassifier
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool {
        tap != nil
    }

    init(inputSources: InputSourceStore, thresholdMilliseconds: Int) {
        self.inputSources = inputSources
        classifier = ShiftTapClassifier(maximumDurationMilliseconds: thresholdMilliseconds)
    }

    func start() {
        guard tap == nil else {
            return
        }
        installTap()
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        tap = nil
        runLoopSource = nil
        classifier.reset()
    }

    func updateThreshold(milliseconds: Int) {
        classifier = ShiftTapClassifier(maximumDurationMilliseconds: milliseconds)
    }

    private func installTap() {
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
            logger.error("Unable to create event tap")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.tap = tap
        runLoopSource = source

        // Text Input Sources is main-thread-only. Running the active tap on
        // the main run loop lets us select synchronously before the Shift-up
        // event continues, without a Task or dispatch hop in the hot path.
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    nonisolated private static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }
        let monitor = Unmanaged<ShiftEventMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        let timestamp = event.timestamp
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let eventFlags = event.flags.rawValue
        MainActor.assumeIsolated {
            monitor.handle(type: type, timestamp: timestamp, keyCode: keyCode, eventFlags: eventFlags)
        }
        return Unmanaged.passUnretained(event)
    }

    private func handle(type: CGEventType, timestamp: UInt64, keyCode: UInt16, eventFlags: UInt64) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            classifier.reset()
            let tap = tap
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            logger.warning("Event tap was disabled and re-enabled")
            return
        }

        switch type {
        case .keyDown:
            classifier.otherKeyChanged()
        case .flagsChanged:
            if let side = ShiftSide(keyCode: keyCode) {
                let isDown = side.isPressed(
                    eventFlags: eventFlags,
                    previouslyPressed: classifier.isPressed(side)
                )
                if case let .select(selectedSide) = classifier.shiftChanged(
                    side: side,
                    isDown: isDown,
                    timestamp: timestamp
                ) {
                    inputSources.select(for: selectedSide)
                }
            } else {
                classifier.otherKeyChanged()
            }
        default:
            break
        }
    }
}
