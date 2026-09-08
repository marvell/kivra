import Foundation
import XCTest

@testable import Kivra

final class ShiftEventMonitorTests: XCTestCase {
    private final class RunLoopReference: @unchecked Sendable {
        let runLoop: CFRunLoop

        init(_ runLoop: CFRunLoop) {
            self.runLoop = runLoop
        }
    }

    func testMainActorCanStopBackgroundRunLoop() {
        let stopped = expectation(description: "Background run loop stopped")
        let thread = Thread {
            let runLoop = CFRunLoopGetCurrent()!
            let reference = RunLoopReference(runLoop)
            let timer = Timer(timeInterval: 60, repeats: false) { _ in }
            RunLoop.current.add(timer, forMode: .default)
            defer { timer.invalidate() }

            DispatchQueue.main.async {
                ShiftEventMonitor.stopRunLoop(reference.runLoop)
            }

            XCTAssertEqual(CFRunLoopRunInMode(.defaultMode, 5, false), .stopped)
            XCTAssertFalse(Thread.isMainThread)
            stopped.fulfill()
        }
        thread.start()

        wait(for: [stopped], timeout: 10)
    }
}
