import XCTest

@testable import Kivra

@MainActor
final class InputSourceStoreTests: XCTestCase {
    func testAvailableSourcesAreSortedByDisplayName() {
        let system = FakeInputSourceSystem(
            snapshots: [
                [
                    InputSource(id: "z", name: "Zulu"),
                    InputSource(id: "a", name: "alpha"),
                ]
            ]
        )
        let store = makeStore(system: system)

        XCTAssertEqual(store.availableSources().map(\.id), ["a", "z"])
    }

    func testMissingTargetRefreshesBeforeSelecting() {
        let system = FakeInputSourceSystem(snapshots: [
            [],
            [InputSource(id: "left", name: "Left")],
        ])
        let store = makeStore(leftID: "left", system: system)
        let gate = SelectionGate()

        store.select(for: .left, gate: gate)

        XCTAssertEqual(system.refreshCallCount, 2)
        XCTAssertEqual(system.selectedIDs, ["left"])
    }

    func testAlreadySelectedCompletesWithoutSelecting() {
        let system = FakeInputSourceSystem(
            snapshots: [[InputSource(id: "left", name: "Left")]],
            currentID: "left"
        )
        let store = makeStore(leftID: "left", system: system)
        let gate = SelectionGate()

        store.select(for: .left, gate: gate)

        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .completed)
        XCTAssertTrue(system.selectedIDs.isEmpty)
    }

    func testFirstFailureRefreshesAndRetriesExactlyOnce() {
        let source = InputSource(id: "left", name: "Left")
        let system = FakeInputSourceSystem(
            snapshots: [[source], [source]],
            selectionResults: [.failed(-1), .selected, .selected]
        )
        let store = makeStore(leftID: "left", system: system)

        store.select(for: .left, gate: SelectionGate())

        XCTAssertEqual(system.refreshCallCount, 2)
        XCTAssertEqual(system.selectedIDs, ["left", "left"])
    }

    func testMatchingSelectedNotificationCompletesSelection() {
        let system = FakeInputSourceSystem(
            snapshots: [[InputSource(id: "left", name: "Left")]]
        )
        let store = makeStore(leftID: "left", system: system)
        let gate = SelectionGate()
        store.select(for: .left, gate: gate)

        system.currentID = "left"
        store.selectedSourceDidChange()

        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .completed)
    }

    func testNonmatchingSelectedNotificationDoesNotCompleteSelection() {
        let system = FakeInputSourceSystem(
            snapshots: [[InputSource(id: "left", name: "Left")]]
        )
        let store = makeStore(leftID: "left", system: system)
        let gate = SelectionGate()
        store.select(for: .left, gate: gate)

        system.currentID = "other"
        store.selectedSourceDidChange()

        XCTAssertTrue(gate.isPending)
    }

    func testFailedRetryCompletesSelection() {
        let source = InputSource(id: "left", name: "Left")
        let system = FakeInputSourceSystem(
            snapshots: [[source], [source]],
            selectionResults: [.failed(-1), .failed(-2)]
        )
        let store = makeStore(leftID: "left", system: system)
        let gate = SelectionGate()

        store.select(for: .left, gate: gate)

        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .completed)
        XCTAssertEqual(system.selectedIDs, ["left", "left"])
    }

    func testTimedOutGateDoesNotLeaveActionableStaleSelection() {
        let system = FakeInputSourceSystem(
            snapshots: [[InputSource(id: "left", name: "Left")]]
        )
        let store = makeStore(leftID: "left", system: system)
        let gate = SelectionGate()
        store.select(for: .left, gate: gate)
        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .timedOutAfterStart)
        let currentSourceCalls = system.currentSourceIDCallCount

        system.currentID = "left"
        store.selectedSourceDidChange()
        store.selectedSourceDidChange()

        XCTAssertEqual(system.currentSourceIDCallCount, currentSourceCalls)
        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .timedOutAfterStart)
    }

    private func makeStore(
        leftID: String? = nil,
        system: FakeInputSourceSystem
    ) -> InputSourceStore {
        InputSourceStore(
            configuration: AppConfiguration(leftSourceID: leftID),
            system: system
        )
    }
}

@MainActor
private final class FakeInputSourceSystem: InputSourceSystem {
    private var snapshots: [[InputSource]]
    private var selectionResults: [InputSourceSelectionResult]
    var currentID: String?
    private(set) var refreshCallCount = 0
    private(set) var currentSourceIDCallCount = 0
    private(set) var selectedIDs: [String] = []

    init(
        snapshots: [[InputSource]],
        currentID: String? = nil,
        selectionResults: [InputSourceSelectionResult] = [.selected]
    ) {
        self.snapshots = snapshots
        self.currentID = currentID
        self.selectionResults = selectionResults
    }

    func refresh() -> [String: InputSource] {
        let index = min(refreshCallCount, snapshots.count - 1)
        refreshCallCount += 1
        return Dictionary(uniqueKeysWithValues: snapshots[index].map { ($0.id, $0) })
    }

    func currentSourceID() -> String? {
        currentSourceIDCallCount += 1
        return currentID
    }

    func selectSource(id: String) -> InputSourceSelectionResult {
        selectedIDs.append(id)
        return selectionResults.isEmpty ? .selected : selectionResults.removeFirst()
    }
}
