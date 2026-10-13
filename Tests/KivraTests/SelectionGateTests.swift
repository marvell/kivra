import Foundation
import XCTest

@testable import Kivra

final class SelectionGateTests: XCTestCase {
    func testCompletionBeforeWaitIsNotMissed() {
        let gate = SelectionGate()

        XCTAssertTrue(gate.finish())

        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .completed)
    }

    func testTimeoutBeforeStartPreventsLateStart() {
        let gate = SelectionGate()

        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .timedOutBeforeStart)
        XCTAssertFalse(gate.isPending)
        XCTAssertFalse(gate.start())
    }

    func testTimeoutAfterStartIsDistinguished() {
        let gate = SelectionGate()

        XCTAssertTrue(gate.start())

        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .timedOutAfterStart)
    }

    func testGateStartsOnlyOnce() {
        let gate = SelectionGate()

        XCTAssertTrue(gate.start())
        XCTAssertFalse(gate.start())
    }

    func testFinishAfterStartCompletesGate() {
        let gate = SelectionGate()

        XCTAssertTrue(gate.start())
        XCTAssertTrue(gate.finish())

        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .completed)
    }

    func testLateFinishCannotOverrideTimeout() {
        let gate = SelectionGate()

        XCTAssertTrue(gate.start())
        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .timedOutAfterStart)

        XCTAssertFalse(gate.finish())
        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .timedOutAfterStart)
    }

    func testWaitingThreadObservesConcurrentCompletion() {
        let gate = SelectionGate()
        let completed = expectation(description: "Wait completed")

        XCTAssertTrue(gate.start())
        DispatchQueue.global().async {
            XCTAssertEqual(gate.wait(timeout: .seconds(1)), .completed)
            completed.fulfill()
        }

        XCTAssertTrue(gate.finish())
        wait(for: [completed], timeout: 1)
    }

    func testTimeoutBeforeStartPreventsLateFinish() {
        let gate = SelectionGate()

        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .timedOutBeforeStart)

        XCTAssertFalse(gate.finish())
        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .timedOutBeforeStart)
    }
}
