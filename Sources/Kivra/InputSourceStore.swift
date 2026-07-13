import Carbon.HIToolbox
import Foundation
import os

struct InputSource: Identifiable, Hashable {
    let id: String
    let name: String
}

final class InputSourceStore: @unchecked Sendable {
    static let leftSourceKey = "leftInputSourceID"
    static let rightSourceKey = "rightInputSourceID"

    private let lock = NSLock()
    private var sourcesByID: [String: TISInputSource] = [:]
    private let logger = Logger(subsystem: "com.kivra.app", category: "input-source")

    init() {
        refresh()
    }

    func availableSources() -> [InputSource] {
        lock.lock()
        defer { lock.unlock() }

        return sourcesByID.map { InputSource(id: $0.key, name: Self.name(for: $0.value) ?? $0.key) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func refresh() {
        let properties: CFDictionary = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource!,
            kTISPropertyInputSourceIsEnabled: true,
            kTISPropertyInputSourceIsSelectCapable: true
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

        lock.lock()
        sourcesByID = updatedSources
        lock.unlock()
    }

    @MainActor
    func select(id: String?) {
        guard let id else {
            return
        }

        lock.lock()
        let source = sourcesByID[id]
        lock.unlock()

        guard let source else {
            logger.error("Configured input source is unavailable")
            return
        }

        let status = TISSelectInputSource(source)
        if status != noErr {
            logger.error("Input source selection failed with status \(status)")
        }
    }

    func configuredSource(for side: ShiftSide) -> String? {
        UserDefaults.standard.string(forKey: preferenceKey(for: side))
    }

    func setConfiguredSource(_ id: String, for side: ShiftSide) {
        UserDefaults.standard.set(id, forKey: preferenceKey(for: side))
    }

    func configuredSourceName(for side: ShiftSide) -> String? {
        guard let id = configuredSource(for: side) else {
            return nil
        }

        lock.lock()
        defer { lock.unlock() }
        return sourcesByID[id].flatMap(Self.name(for:))
    }

    private func preferenceKey(for side: ShiftSide) -> String {
        switch side {
        case .left: Self.leftSourceKey
        case .right: Self.rightSourceKey
        }
    }

    private static func identifier(for source: TISInputSource) -> String? {
        TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
            .map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String }
    }

    private static func name(for source: TISInputSource) -> String? {
        TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
            .map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String }
    }
}
