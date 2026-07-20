import Foundation
import XCTest

@testable import Kivra

final class InputSourceSelectionRequestTests: XCTestCase {
    func testMatchingSourceCompletesRequest() {
        let request = InputSourceSelectionRequest()

        XCTAssertTrue(request.arm(targetID: "target"))
        XCTAssertTrue(request.confirm(sourceID: "target"))
        XCTAssertEqual(request.wait(timeout: .milliseconds(1)), .selected)
    }

    func testUnrelatedSourceDoesNotCompleteRequest() {
        let request = InputSourceSelectionRequest()

        XCTAssertTrue(request.arm(targetID: "target"))
        XCTAssertFalse(request.confirm(sourceID: "other"))
        request.complete(with: .failed)

        XCTAssertEqual(request.wait(timeout: .milliseconds(1)), .failed)
    }

    func testCompletionBeforeWaitIsNotMissed() {
        let request = InputSourceSelectionRequest()

        request.complete(with: .alreadySelected)

        XCTAssertEqual(request.wait(timeout: .milliseconds(1)), .alreadySelected)
    }

    func testTimeoutBeforeSelectionCancelsRequest() {
        let request = InputSourceSelectionRequest()

        XCTAssertEqual(request.wait(timeout: .milliseconds(1)), .timedOutBeforeSelection)
        XCTAssertFalse(request.isPending)
        XCTAssertFalse(request.arm(targetID: "target"))
    }

    func testTimeoutAfterSelectionStartsIsDistinguished() {
        let request = InputSourceSelectionRequest()

        XCTAssertTrue(request.arm(targetID: "target"))

        XCTAssertEqual(request.wait(timeout: .milliseconds(1)), .timedOutAfterSelection)
    }

    func testLateNotificationCannotOverrideCompletion() {
        let request = InputSourceSelectionRequest()

        XCTAssertTrue(request.arm(targetID: "target"))
        request.complete(with: .failed)

        XCTAssertFalse(request.confirm(sourceID: "target"))
        XCTAssertEqual(request.wait(timeout: .milliseconds(1)), .failed)
    }
}
