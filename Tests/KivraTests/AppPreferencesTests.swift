import Foundation
import XCTest

@testable import Kivra

final class AppPreferencesTests: XCTestCase {
    private let suiteName = "AppPreferencesTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    @MainActor
    func testMissingThresholdUsesDefault() {
        let preferences = AppPreferences(defaults: defaults)

        XCTAssertEqual(
            preferences.configuration.tapThresholdMilliseconds,
            AppConfiguration.defaultTapThresholdMilliseconds
        )
    }

    @MainActor
    func testConfigurationRoundTripPreservesExistingKeys() {
        let preferences = AppPreferences(defaults: defaults)
        preferences.configuration = AppConfiguration(
            leftSourceID: "left",
            rightSourceID: "right",
            tapThresholdMilliseconds: 350
        )

        XCTAssertEqual(defaults.string(forKey: "leftInputSourceID"), "left")
        XCTAssertEqual(defaults.string(forKey: "rightInputSourceID"), "right")
        XCTAssertEqual(defaults.integer(forKey: "tapThresholdMilliseconds"), 350)
        XCTAssertEqual(
            preferences.configuration,
            AppConfiguration(
                leftSourceID: "left",
                rightSourceID: "right",
                tapThresholdMilliseconds: 350
            )
        )
    }

    @MainActor
    func testMissingOnboardingValueRemainsDistinctFromFalse() {
        let preferences = AppPreferences(defaults: defaults)

        XCTAssertNil(preferences.onboardingCompleted)

        preferences.onboardingCompleted = false

        XCTAssertEqual(preferences.onboardingCompleted, false)
    }

    @MainActor
    func testMigrationCompletesOnboardingForExistingConfiguration() {
        let preferences = AppPreferences(defaults: defaults)
        preferences.configuration = AppConfiguration(
            leftSourceID: "left",
            rightSourceID: "right"
        )

        preferences.migrateOnboardingCompletionIfNeeded()

        XCTAssertEqual(preferences.onboardingCompleted, true)
    }

    @MainActor
    func testMigrationLeavesIncompleteConfigurationUnchanged() {
        let preferences = AppPreferences(defaults: defaults)
        preferences.configuration = AppConfiguration(leftSourceID: "left")

        preferences.migrateOnboardingCompletionIfNeeded()

        XCTAssertNil(preferences.onboardingCompleted)
    }
}
