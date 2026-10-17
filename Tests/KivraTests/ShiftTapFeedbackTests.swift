import XCTest

@testable import Kivra

@MainActor
final class ShiftTapFeedbackTests: XCTestCase {
    func testTapIsHighlightedBrieflyAndRemembered() async throws {
        let feedback = ShiftTapFeedback()

        feedback.record(.left)
        XCTAssertEqual(feedback.highlightedSide, .left)
        feedback.record(.right)
        XCTAssertEqual(feedback.highlightedSide, .right)

        try await Task.sleep(for: .milliseconds(900))
        XCTAssertNil(feedback.highlightedSide)
        XCTAssertEqual(feedback.triedSides, [.left, .right])
    }

    func testForgettingTriesAsksForSidesAgain() {
        let feedback = ShiftTapFeedback()
        feedback.record(.left)
        feedback.record(.right)

        feedback.forgetTries(on: [.right])
        XCTAssertEqual(feedback.triedSides, [.left])

        feedback.forgetTries()
        XCTAssertTrue(feedback.triedSides.isEmpty)
    }
}
