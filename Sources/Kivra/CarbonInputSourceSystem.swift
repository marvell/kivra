import Carbon.HIToolbox
import os

@MainActor
final class CarbonInputSourceSystem: InputSourceSystem {
    private let signposter = OSSignposter(subsystem: "com.kivra.app", category: .pointsOfInterest)
    private var sourcesByID: [String: TISInputSource] = [:]

    func refresh() -> [String: InputSource] {
        let properties: CFDictionary =
            [
                kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource!,
                kTISPropertyInputSourceIsEnabled: true,
                kTISPropertyInputSourceIsSelectCapable: true,
            ] as CFDictionary
        let rawSources =
            TISCreateInputSourceList(properties, false).takeRetainedValue()
            as? [TISInputSource] ?? []

        sourcesByID = Dictionary(
            uniqueKeysWithValues: rawSources.compactMap { source in
                identifier(for: source).map { ($0, source) }
            }
        )

        return sourcesByID.reduce(into: [:]) { result, entry in
            let (id, source) = entry
            result[id] = InputSource(
                id: id,
                name: name(for: source) ?? id,
                languageCode: languageCode(for: source)
            )
        }
    }

    func currentSourceID() -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return identifier(for: source)
    }

    func selectSource(id: String) -> InputSourceSelectionResult {
        guard let source = sourcesByID[id] else {
            return .unavailable
        }

        let status = signposter.withIntervalSignpost("TISSelectInputSource") {
            TISSelectInputSource(source)
        }
        return status == noErr ? .selected : .failed(status)
    }

    private func identifier(for source: TISInputSource) -> String? {
        TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
            .map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String }
    }

    /// macOS lists the layout's primary language first.
    private func languageCode(for source: TISInputSource) -> String? {
        TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages)
            .flatMap { Unmanaged<CFArray>.fromOpaque($0).takeUnretainedValue() as? [String] }?
            .first
    }

    private func name(for source: TISInputSource) -> String? {
        TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
            .map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String }
    }
}
