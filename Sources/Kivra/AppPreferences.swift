import Foundation

@MainActor
final class AppPreferences {
    private enum Key {
        static let leftSourceID = "leftInputSourceID"
        static let rightSourceID = "rightInputSourceID"
        static let tapThresholdMilliseconds = "tapThresholdMilliseconds"
        static let onboardingCompleted = "onboardingCompleted"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var configuration: AppConfiguration {
        get {
            let storedThreshold = defaults.integer(forKey: Key.tapThresholdMilliseconds)
            return AppConfiguration(
                leftSourceID: defaults.string(forKey: Key.leftSourceID),
                rightSourceID: defaults.string(forKey: Key.rightSourceID),
                tapThresholdMilliseconds: storedThreshold == 0
                    ? AppConfiguration.defaultTapThresholdMilliseconds
                    : storedThreshold
            )
        }
        set {
            defaults.set(newValue.leftSourceID, forKey: Key.leftSourceID)
            defaults.set(newValue.rightSourceID, forKey: Key.rightSourceID)
            defaults.set(
                newValue.tapThresholdMilliseconds,
                forKey: Key.tapThresholdMilliseconds
            )
        }
    }

    var onboardingCompleted: Bool? {
        get {
            guard defaults.object(forKey: Key.onboardingCompleted) != nil else {
                return nil
            }
            return defaults.bool(forKey: Key.onboardingCompleted)
        }
        set {
            defaults.set(newValue, forKey: Key.onboardingCompleted)
        }
    }

    func migrateOnboardingCompletionIfNeeded() {
        if onboardingCompleted == nil, configuration.hasConfiguredSources {
            onboardingCompleted = true
        }
    }
}
