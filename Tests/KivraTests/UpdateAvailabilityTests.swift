import XCTest

@testable import Kivra

final class UpdateAvailabilityTests: XCTestCase {
    func testDiscoveryShowsAvailableVersion() {
        var state = UpdateAvailabilityState()
        XCTAssertNil(state.availability)
        state.found(version: "0.6.0")
        XCTAssertEqual(state.availability, .available(version: "0.6.0"))
    }

    func testPreparedUpdateSurvivesNoNewerRelease() {
        var state = UpdateAvailabilityState()
        state.found(version: "0.6.0")
        state.prepared(version: "0.6.0")
        state.noUpdateFound()
        XCTAssertEqual(state.availability, .ready(version: "0.6.0"))
    }

    func testPreparationDoesNotRequirePriorPresentation() {
        var state = UpdateAvailabilityState()
        state.prepared(version: "0.6.0")
        XCTAssertEqual(state.availability, .ready(version: "0.6.0"))
    }

    func testOpeningPreparedUpdateDoesNotDowngradeReadiness() {
        var state = UpdateAvailabilityState()
        state.prepared(version: "0.6.0")
        state.found(version: "0.6.0")
        XCTAssertEqual(state.availability, .ready(version: "0.6.0"))
    }

    func testNoUpdateFoundClearsAvailableReminder() {
        var state = UpdateAvailabilityState()
        state.found(version: "0.6.0")
        state.noUpdateFound()
        XCTAssertNil(state.availability)
    }

    func testClearingPreparedUpdateRemovesReminder() {
        var state = UpdateAvailabilityState()
        state.prepared(version: "0.6.0")
        state.clear()
        state.noUpdateFound()
        XCTAssertNil(state.availability)
    }

    func testDifferentUpdateReplacesPreviousReadiness() {
        var state = UpdateAvailabilityState()
        state.prepared(version: "0.6.0")
        state.found(version: "0.7.0")
        XCTAssertEqual(state.availability, .available(version: "0.7.0"))
    }
}
