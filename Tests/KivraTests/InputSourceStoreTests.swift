import XCTest

@testable import Kivra

@MainActor
final class InputSourceStoreTests: XCTestCase {
    func testSelectionCallbackRunsOnceForEachSideAfterReleasingGate() {
        for side in [ShiftSide.left, .right] {
            let system = FakeInputSourceSystem(snapshots: [
                [
                    InputSource(id: "left", name: "Left"),
                    InputSource(id: "right", name: "Right"),
                ]
            ])
            let gate = SelectionGate()
            var confirmed: [ShiftSide] = []
            let store = makeStore(leftID: "left", rightID: "right", system: system) {
                XCTAssertEqual(gate.wait(timeout: .nanoseconds(0)), .completed)
                confirmed.append($0)
            }
            store.select(for: side, gate: gate)
            XCTAssertTrue(confirmed.isEmpty)
            system.currentID = side.rawValue
            store.selectedSourceDidChange()
            store.selectedSourceDidChange()
            XCTAssertEqual(confirmed, [side])
        }
    }

    func testSelectionCallbackIgnoresNoOpFailureAndUnrelatedChanges() {
        for scenario in ["alreadySelected", "failed", "unrelated"] {
            let system = FakeInputSourceSystem(
                snapshots: [[InputSource(id: "left", name: "Left")]],
                currentID: scenario == "alreadySelected" ? "left" : nil,
                selectionResults: scenario == "failed" ? [.failed(-1), .failed(-2)] : [.selected]
            )
            var confirmed: [ShiftSide] = []
            let store = makeStore(leftID: "left", system: system) { confirmed.append($0) }
            let gate = SelectionGate()
            store.select(for: .left, gate: gate)
            system.currentID = scenario == "unrelated" ? "other" : "left"
            store.selectedSourceDidChange()
            XCTAssertTrue(confirmed.isEmpty, scenario)
        }
    }

    func testSelectionCallbackRunsForConfirmationAfterTimeout() {
        let system = FakeInputSourceSystem(
            snapshots: [[InputSource(id: "left", name: "Left")]]
        )
        var confirmed: [ShiftSide] = []
        let store = makeStore(leftID: "left", system: system) { confirmed.append($0) }
        let gate = SelectionGate()
        store.select(for: .left, gate: gate)
        XCTAssertEqual(gate.wait(timeout: .nanoseconds(0)), .timedOutAfterStart)

        system.currentID = "left"
        store.selectedSourceDidChange()
        store.selectedSourceDidChange()

        XCTAssertEqual(confirmed, [.left])
    }

    func testCompletedSelectionGateDoesNotTriggerCallback() {
        let system = FakeInputSourceSystem(
            snapshots: [[InputSource(id: "left", name: "Left")]]
        )
        var confirmed: [ShiftSide] = []
        let store = makeStore(leftID: "left", system: system) { confirmed.append($0) }
        let gate = SelectionGate()
        store.select(for: .left, gate: gate)
        XCTAssertTrue(gate.finish())

        system.currentID = "left"
        store.selectedSourceDidChange()

        XCTAssertTrue(confirmed.isEmpty)
    }

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

    func testCurrentSourceMatchingAfterSelectionStillWaitsForNotification() {
        let system = FakeInputSourceSystem(
            snapshots: [[InputSource(id: "left", name: "Left")]],
            selectsImmediately: true
        )
        let store = makeStore(leftID: "left", system: system)
        let gate = SelectionGate()

        store.select(for: .left, gate: gate)

        XCTAssertEqual(system.currentID, "left")
        XCTAssertTrue(gate.isPending)
        XCTAssertEqual(system.currentSourceIDCallCount, 1)

        store.selectedSourceDidChange()

        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .completed)
    }

    func testCurrentSourceMatchingAfterRetryStillWaitsForNotification() {
        let source = InputSource(id: "left", name: "Left")
        let system = FakeInputSourceSystem(
            snapshots: [[source], [source]],
            selectionResults: [.failed(-1), .selected],
            selectsImmediately: true
        )
        let store = makeStore(leftID: "left", system: system)
        let gate = SelectionGate()

        store.select(for: .left, gate: gate)

        XCTAssertEqual(system.selectedIDs, ["left", "left"])
        XCTAssertEqual(system.currentID, "left")
        XCTAssertTrue(gate.isPending)

        store.selectedSourceDidChange()

        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .completed)
    }

    func testNotificationDuringSelectionIsNotMissed() {
        let system = FakeInputSourceSystem(
            snapshots: [[InputSource(id: "left", name: "Left")]],
            selectsImmediately: true
        )
        let store = makeStore(leftID: "left", system: system)
        let gate = SelectionGate()
        system.onSelect = { [weak store] in
            store?.selectedSourceDidChange()
        }

        store.select(for: .left, gate: gate)

        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .completed)
        let sourceCalls = system.currentSourceIDCallCount
        store.selectedSourceDidChange()
        XCTAssertEqual(system.currentSourceIDCallCount, sourceCalls)
    }

    func testExpiredGateDoesNotQueryOrSelectSources() {
        let system = FakeInputSourceSystem(
            snapshots: [[InputSource(id: "left", name: "Left")]]
        )
        let store = makeStore(leftID: "left", system: system)
        let gate = SelectionGate()
        XCTAssertEqual(gate.wait(timeout: .nanoseconds(0)), .timedOutBeforeStart)

        store.select(for: .left, gate: gate)

        XCTAssertEqual(system.refreshCallCount, 1)
        XCTAssertEqual(system.currentSourceIDCallCount, 0)
        XCTAssertTrue(system.selectedIDs.isEmpty)
    }

    func testSelectionTimingOutDoesNotRetryOrRefresh() {
        let source = InputSource(id: "left", name: "Left")
        let system = FakeInputSourceSystem(
            snapshots: [[source]],
            selectionResults: [.failed(-1)]
        )
        let store = makeStore(leftID: "left", system: system)
        let gate = SelectionGate()
        system.onSelect = {
            XCTAssertEqual(gate.wait(timeout: .nanoseconds(0)), .timedOutAfterStart)
        }

        store.select(for: .left, gate: gate)

        XCTAssertEqual(system.refreshCallCount, 1)
        XCTAssertEqual(system.selectedIDs, ["left"])
        let sourceCalls = system.currentSourceIDCallCount
        store.selectedSourceDidChange()
        XCTAssertEqual(system.currentSourceIDCallCount, sourceCalls)
    }

    func testNonmatchingSourceCannotCompleteSelectionAfterPreviousTimeout() {
        let system = FakeInputSourceSystem(snapshots: [
            [
                InputSource(id: "left", name: "Left"),
                InputSource(id: "right", name: "Right"),
            ]
        ])
        let store = makeStore(leftID: "left", rightID: "right", system: system)
        let oldGate = SelectionGate()
        store.select(for: .left, gate: oldGate)
        XCTAssertEqual(oldGate.wait(timeout: .nanoseconds(0)), .timedOutAfterStart)
        let newGate = SelectionGate()
        store.select(for: .right, gate: newGate)

        system.currentID = "left"
        store.selectedSourceDidChange()

        XCTAssertTrue(newGate.isPending)
        XCTAssertFalse(oldGate.finish())

        system.currentID = "right"
        store.selectedSourceDidChange()

        XCTAssertEqual(newGate.wait(timeout: .milliseconds(1)), .completed)
        let sourceCalls = system.currentSourceIDCallCount
        store.selectedSourceDidChange()
        XCTAssertEqual(system.currentSourceIDCallCount, sourceCalls)
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

    func testTimedOutGateConfirmsLateSelectionOnlyOnce() {
        let system = FakeInputSourceSystem(
            snapshots: [[InputSource(id: "left", name: "Left")]]
        )
        var confirmed: [ShiftSide] = []
        let store = makeStore(leftID: "left", system: system) { confirmed.append($0) }
        let gate = SelectionGate()
        store.select(for: .left, gate: gate)
        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .timedOutAfterStart)

        system.currentID = "left"
        store.selectedSourceDidChange()
        let currentSourceCalls = system.currentSourceIDCallCount
        store.selectedSourceDidChange()

        XCTAssertEqual(system.currentSourceIDCallCount, currentSourceCalls)
        XCTAssertEqual(confirmed, [.left])
        XCTAssertEqual(gate.wait(timeout: .milliseconds(1)), .timedOutAfterStart)
    }

    private func makeStore(
        leftID: String? = nil,
        rightID: String? = nil,
        system: FakeInputSourceSystem,
        onSelectionConfirmed: @escaping (ShiftSide) -> Void = { _ in }
    ) -> InputSourceStore {
        InputSourceStore(
            configuration: AppConfiguration(leftSourceID: leftID, rightSourceID: rightID),
            system: system,
            onSelectionConfirmed: onSelectionConfirmed
        )
    }
}

@MainActor
private final class FakeInputSourceSystem: InputSourceSystem {
    private var snapshots: [[InputSource]]
    private var selectionResults: [InputSourceSelectionResult]
    private let selectsImmediately: Bool
    var currentID: String?
    var onSelect: (() -> Void)?
    private(set) var refreshCallCount = 0
    private(set) var currentSourceIDCallCount = 0
    private(set) var selectedIDs: [String] = []

    init(
        snapshots: [[InputSource]],
        currentID: String? = nil,
        selectionResults: [InputSourceSelectionResult] = [.selected],
        selectsImmediately: Bool = false
    ) {
        self.snapshots = snapshots
        self.currentID = currentID
        self.selectionResults = selectionResults
        self.selectsImmediately = selectsImmediately
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
        let result = selectionResults.isEmpty ? .selected : selectionResults.removeFirst()
        if result == .selected, selectsImmediately {
            currentID = id
        }
        onSelect?()
        return result
    }
}
