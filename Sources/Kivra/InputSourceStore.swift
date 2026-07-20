import Carbon.HIToolbox
import Foundation
import os

struct InputSource: Identifiable, Hashable {
    let id: String
    let name: String
}

@MainActor
final class InputSourceStore {
    static let leftSourceKey = "leftInputSourceID"
    static let rightSourceKey = "rightInputSourceID"

    private final class PendingSelection {
        let targetID: String
        weak var gate: SelectionGate?

        init(targetID: String, gate: SelectionGate) {
            self.targetID = targetID
            self.gate = gate
        }
    }

    private var sourcesByID: [String: TISInputSource] = [:]
    private var leftID: String?
    private var rightID: String?
    private var pendingSelection: PendingSelection?
    private let logger = Logger(subsystem: "com.kivra.app", category: "input-source")

    init() {
        leftID = UserDefaults.standard.string(forKey: Self.leftSourceKey)
        rightID = UserDefaults.standard.string(forKey: Self.rightSourceKey)
        refresh()
    }

    func availableSources() -> [InputSource] {
        return sourcesByID.map { InputSource(id: $0.key, name: Self.name(for: $0.value) ?? $0.key) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func refresh() {
        let properties: CFDictionary =
            [
                kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource!,
                kTISPropertyInputSourceIsEnabled: true,
                kTISPropertyInputSourceIsSelectCapable: true,
            ] as CFDictionary
        let inputSources = TISCreateInputSourceList(properties, false).takeRetainedValue() as? [TISInputSource] ?? []
        let updatedSources = Dictionary(
            uniqueKeysWithValues: inputSources.compactMap { source -> (String, TISInputSource)? in
                guard let id = Self.identifier(for: source) else {
                    return nil
                }
                return (id, source)
            }
        )

        sourcesByID = updatedSources
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

        if Self.currentSourceID() == target.id {
            gate.finish()
            return
        }

        guard gate.start() else {
            return
        }
        pendingSelection = PendingSelection(targetID: target.id, gate: gate)

        var status = TISSelectInputSource(target.source)
        if status == noErr {
            return
        }

        guard gate.isPending else {
            clearPendingSelection(ifMatching: gate)
            return
        }

        // The enabled-source notification can race with a tap. Rebuild the
        // retained TISInputSource snapshot and retry once instead of dropping
        // the user's switch.
        refresh()
        guard gate.isPending else {
            clearPendingSelection(ifMatching: gate)
            return
        }
        if let refreshedTarget = selectionTarget(for: side) {
            status = TISSelectInputSource(refreshedTarget.source)
        }
        if status != noErr {
            logger.error("Input source selection failed with status \(status), id: \(target.id, privacy: .public)")
            gate.finish()
            clearPendingSelection(ifMatching: gate)
        }
    }

    func selectedSourceDidChange() {
        guard let pendingSelection else {
            return
        }
        guard let gate = pendingSelection.gate else {
            self.pendingSelection = nil
            return
        }
        guard let sourceID = Self.currentSourceID() else {
            return
        }

        if sourceID == pendingSelection.targetID {
            gate.finish()
            self.pendingSelection = nil
        } else if !gate.isPending {
            self.pendingSelection = nil
        }
    }

    func configuredSource(for side: ShiftSide) -> String? {
        switch side {
        case .left: leftID
        case .right: rightID
        }
    }

    func setConfiguredSource(_ id: String, for side: ShiftSide) {
        switch side {
        case .left: leftID = id
        case .right: rightID = id
        }
        UserDefaults.standard.set(id, forKey: Self.preferenceKey(for: side))
    }

    func configuredSourceName(for side: ShiftSide) -> String? {
        guard let id = configuredSource(for: side) else {
            return nil
        }

        return sourcesByID[id].flatMap(Self.name(for:))
    }

    private func selectionTarget(for side: ShiftSide) -> (id: String, source: TISInputSource)? {
        guard
            let id = configuredSource(for: side),
            let source = sourcesByID[id]
        else {
            return nil
        }
        return (id, source)
    }

    private func clearPendingSelection(ifMatching gate: SelectionGate) {
        if pendingSelection?.gate === gate {
            pendingSelection = nil
        }
    }

    private static func preferenceKey(for side: ShiftSide) -> String {
        switch side {
        case .left: Self.leftSourceKey
        case .right: Self.rightSourceKey
        }
    }

    private static func identifier(for source: TISInputSource) -> String? {
        TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
            .map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String }
    }

    private static func currentSourceID() -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return identifier(for: source)
    }

    private static func name(for source: TISInputSource) -> String? {
        TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
            .map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String }
    }
}
