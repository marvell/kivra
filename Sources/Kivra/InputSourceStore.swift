import os

@MainActor
final class InputSourceStore {
    private final class PendingSelection {
        let targetID: String
        weak var gate: SelectionGate?

        init(targetID: String, gate: SelectionGate) {
            self.targetID = targetID
            self.gate = gate
        }
    }

    private var sourcesByID: [String: InputSource] = [:]
    private var pendingSelection: PendingSelection?
    private let system: InputSourceSystem
    private let logger = Logger(subsystem: "com.kivra.app", category: "input-source")
    private(set) var configuration: AppConfiguration

    init(configuration: AppConfiguration, system: InputSourceSystem) {
        self.configuration = configuration
        self.system = system
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
        pendingSelection = PendingSelection(targetID: target.id, gate: gate)

        var result = system.selectSource(id: target.id)
        if result == .selected {
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
        guard let gate = pendingSelection.gate else {
            self.pendingSelection = nil
            return
        }
        guard gate.isPending else {
            self.pendingSelection = nil
            return
        }
        guard let sourceID = system.currentSourceID() else {
            return
        }

        if sourceID == pendingSelection.targetID {
            gate.finish()
            self.pendingSelection = nil
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
