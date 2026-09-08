import os

@MainActor
final class InputSourceStore {
    private final class PendingSelection {
        let targetID: String
        let side: ShiftSide
        let gate: SelectionGate

        init(targetID: String, side: ShiftSide, gate: SelectionGate) {
            self.targetID = targetID
            self.side = side
            self.gate = gate
        }
    }

    private var sourcesByID: [String: InputSource] = [:]
    private var pendingSelection: PendingSelection?
    private let system: InputSourceSystem
    private let onSelectionConfirmed: (ShiftSide) -> Void
    private let logger = Logger(subsystem: "com.kivra.app", category: "input-source")
    private(set) var configuration: AppConfiguration

    init(
        configuration: AppConfiguration,
        system: InputSourceSystem,
        onSelectionConfirmed: @escaping (ShiftSide) -> Void = { _ in }
    ) {
        self.configuration = configuration
        self.system = system
        self.onSelectionConfirmed = onSelectionConfirmed
        refresh()
    }

    func availableSources() -> [InputSource] {
        sourcesByID.values
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func refresh() {
        sourcesByID = system.refresh()
    }

    func select(for side: ShiftSide, gate: SelectionGate) {
        guard gate.isPending else {
            return
        }

        var target = selectionTarget(for: side)
        if target == nil {
            // The source may have been enabled before its distributed
            // notification reached the main run loop.
            refresh()
            target = selectionTarget(for: side)
        }

        guard let target else {
            logger.error("Configured input source is unavailable")
            gate.finish()
            return
        }

        if system.currentSourceID() == target.id {
            gate.finish()
            return
        }

        guard gate.start() else {
            return
        }
        pendingSelection = PendingSelection(targetID: target.id, side: side, gate: gate)

        var result = system.selectSource(id: target.id)
        if result == .selected {
            // The current source can change here before another app is ready to use it.
            // Keep the event gate closed until the distributed notification arrives.
            return
        }

        guard gate.isPending else {
            clearPendingSelection(ifMatching: gate)
            return
        }

        // The enabled-source notification can race with a tap. Rebuild the
        // system snapshot and retry once instead of dropping the user's switch.
        refresh()
        guard gate.isPending else {
            clearPendingSelection(ifMatching: gate)
            return
        }
        if let refreshedTarget = selectionTarget(for: side) {
            result = system.selectSource(id: refreshedTarget.id)
        } else {
            result = .unavailable
        }
        finishFailedSelection(result, targetID: target.id, gate: gate)
    }

    func selectedSourceDidChange() {
        guard let pendingSelection else {
            return
        }
        let gate = pendingSelection.gate
        guard gate.acceptsSelectionConfirmation else {
            self.pendingSelection = nil
            return
        }
        guard let sourceID = system.currentSourceID() else {
            return
        }

        if sourceID == pendingSelection.targetID {
            let confirmed = gate.confirmSelection()
            self.pendingSelection = nil
            if confirmed {
                onSelectionConfirmed(pendingSelection.side)
            }
        }
    }

    func configuredSource(for side: ShiftSide) -> String? {
        switch side {
        case .left: configuration.leftSourceID
        case .right: configuration.rightSourceID
        }
    }

    func updateConfiguration(_ configuration: AppConfiguration) {
        self.configuration = configuration
    }

    private func selectionTarget(for side: ShiftSide) -> InputSource? {
        guard
            let id = configuredSource(for: side),
            let source = sourcesByID[id]
        else {
            return nil
        }
        return source
    }

    private func clearPendingSelection(ifMatching gate: SelectionGate) {
        if pendingSelection?.gate === gate {
            pendingSelection = nil
        }
    }

    private func finishFailedSelection(
        _ result: InputSourceSelectionResult,
        targetID: String,
        gate: SelectionGate
    ) {
        guard result != .selected else {
            return
        }
        if case .failed(let status) = result {
            logger.error(
                "Input source selection failed with status \(status), id: \(targetID, privacy: .public)"
            )
        } else {
            logger.error("Configured input source is unavailable")
        }
        gate.finish()
        clearPendingSelection(ifMatching: gate)
    }
}
