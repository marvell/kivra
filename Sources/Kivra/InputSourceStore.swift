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

    private struct SelectionTarget {
        let id: String
        let source: TISInputSource
    }

    private var sourcesByID: [String: TISInputSource] = [:]
    private var leftID: String?
    private var rightID: String?
    private var leftTarget: SelectionTarget?
    private var rightTarget: SelectionTarget?
    private weak var pendingSelectionRequest: InputSourceSelectionRequest?
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
        rebuildSelectionTargets()
    }

    func select(for side: ShiftSide, request: InputSourceSelectionRequest) {
        guard request.isPending else {
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
            request.complete(with: .failed)
            return
        }

        if Self.currentSourceID() == target.id {
            request.complete(with: .alreadySelected)
            return
        }

        guard request.arm(targetID: target.id) else {
            return
        }
        pendingSelectionRequest = request

        var status = TISSelectInputSource(target.source)
        if status == noErr {
            return
        }

        guard request.isPending else {
            clearPendingRequest(ifMatching: request)
            return
        }

        // The enabled-source notification can race with a tap. Rebuild the
        // retained TISInputSource snapshot and retry once instead of dropping
        // the user's switch.
        refresh()
        if let refreshedTarget = selectionTarget(for: side) {
            status = TISSelectInputSource(refreshedTarget.source)
        }
        if status != noErr {
            logger.error("Input source selection failed with status \(status), id: \(target.id, privacy: .public)")
            request.complete(with: .failed)
            clearPendingRequest(ifMatching: request)
        }
    }

    func selectedSourceDidChange() {
        guard
            let request = pendingSelectionRequest,
            let sourceID = Self.currentSourceID()
        else {
            return
        }

        if request.confirm(sourceID: sourceID) || !request.isPending {
            clearPendingRequest(ifMatching: request)
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
        rebuildSelectionTargets()
    }

    func configuredSourceName(for side: ShiftSide) -> String? {
        guard let id = configuredSource(for: side) else {
            return nil
        }

        return sourcesByID[id].flatMap(Self.name(for:))
    }

    private func selectionTarget(for side: ShiftSide) -> SelectionTarget? {
        switch side {
        case .left: leftTarget
        case .right: rightTarget
        }
    }

    private func rebuildSelectionTargets() {
        leftTarget = leftID.flatMap { id in
            sourcesByID[id].map { SelectionTarget(id: id, source: $0) }
        }
        rightTarget = rightID.flatMap { id in
            sourcesByID[id].map { SelectionTarget(id: id, source: $0) }
        }
    }

    private func clearPendingRequest(ifMatching request: InputSourceSelectionRequest) {
        if pendingSelectionRequest === request {
            pendingSelectionRequest = nil
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
