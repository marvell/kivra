import Foundation

@MainActor
protocol InputSourceIndicatorControlling: AnyObject {
    var isHidden: Bool { get }

    func setHidden(_ hidden: Bool) throws
}

@MainActor
protocol InputSourceIndicatorPreferences: AnyObject {
    var isVisible: Bool { get }

    func setVisible(_ visible: Bool) throws
}

@MainActor
final class InputSourceIndicatorController: InputSourceIndicatorControlling {
    private let preferences: any InputSourceIndicatorPreferences

    var isHidden: Bool {
        !preferences.isVisible
    }

    init(
        preferences: any InputSourceIndicatorPreferences = SystemInputSourceIndicatorPreferences()
    ) {
        self.preferences = preferences
    }

    func setHidden(_ hidden: Bool) throws {
        guard hidden != isHidden else { return }
        try preferences.setVisible(!hidden)
    }
}

enum InputSourceIndicatorError: Error {
    case couldNotSave
}

@MainActor
final class SystemInputSourceIndicatorPreferences: InputSourceIndicatorPreferences {
    private let domain: CFString
    private let indicatorKey = "TSMLanguageIndicatorEnabled" as CFString

    var isVisible: Bool {
        (readValue() as? NSNumber)?.boolValue ?? true
    }

    init(domain: CFString = kCFPreferencesAnyApplication) {
        self.domain = domain
    }

    private func readValue() -> Any? {
        CFPreferencesCopyValue(indicatorKey, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    func setVisible(_ visible: Bool) throws {
        let previousValue = readValue()
        CFPreferencesSetValue(
            indicatorKey,
            visible as CFPropertyList,
            domain,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            CFPreferencesSetValue(
                indicatorKey,
                previousValue as CFPropertyList?,
                domain,
                kCFPreferencesCurrentUser,
                kCFPreferencesAnyHost
            )
            CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            throw InputSourceIndicatorError.couldNotSave
        }
    }
}
