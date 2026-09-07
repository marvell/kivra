import Foundation
import XCTest

@testable import Kivra

@MainActor
final class InputSourceIndicatorTests: XCTestCase {
    func testReadingStateDoesNotWritePreferences() {
        let preferences = FakeIndicatorPreferences()
        let controller = InputSourceIndicatorController(preferences: preferences)

        XCTAssertFalse(controller.isHidden)
        preferences.isVisible = false
        XCTAssertTrue(controller.isHidden)
        XCTAssertTrue(preferences.appliedValues.isEmpty)
    }

    func testHideAndShowWriteActualVisibility() throws {
        let preferences = FakeIndicatorPreferences()
        let controller = InputSourceIndicatorController(preferences: preferences)

        try controller.setHidden(true)
        XCTAssertTrue(controller.isHidden)
        try controller.setHidden(false)

        XCTAssertFalse(controller.isHidden)
        XCTAssertEqual(preferences.appliedValues, [false, true])
    }

    func testManuallyHiddenIndicatorCanBeShown() throws {
        let preferences = FakeIndicatorPreferences()
        preferences.isVisible = false
        let controller = InputSourceIndicatorController(preferences: preferences)

        try controller.setHidden(false)

        XCTAssertFalse(controller.isHidden)
        XCTAssertEqual(preferences.appliedValues, [true])
    }

    func testUnchangedStateDoesNotWrite() throws {
        let preferences = FakeIndicatorPreferences()
        let controller = InputSourceIndicatorController(preferences: preferences)

        try controller.setHidden(false)
        try controller.setHidden(true)
        try controller.setHidden(true)

        XCTAssertEqual(preferences.appliedValues, [false])
    }

    func testWriteFailureCanBeRetried() throws {
        let preferences = FakeIndicatorPreferences()
        let controller = InputSourceIndicatorController(preferences: preferences)
        preferences.shouldFail = true

        XCTAssertThrowsError(try controller.setHidden(true))
        XCTAssertFalse(controller.isHidden)

        preferences.shouldFail = false
        try controller.setHidden(true)
        XCTAssertTrue(controller.isHidden)
    }

    func testSystemAdapterUsesOnlyItsIsolatedDomain() throws {
        let domain = "KivraTests.indicator.\(UUID().uuidString)" as CFString
        let key = "TSMLanguageIndicatorEnabled" as CFString
        let preferences = SystemInputSourceIndicatorPreferences(domain: domain)
        defer {
            CFPreferencesSetValue(key, nil, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        let controller = InputSourceIndicatorController(preferences: preferences)
        XCTAssertFalse(controller.isHidden)

        try controller.setHidden(true)
        let reopened = InputSourceIndicatorController(
            preferences: SystemInputSourceIndicatorPreferences(domain: domain)
        )
        XCTAssertTrue(reopened.isHidden)
        try reopened.setHidden(false)

        XCTAssertFalse(controller.isHidden)
        XCTAssertEqual(
            CFPreferencesCopyValue(key, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? Bool,
            true
        )
    }
}

@MainActor
private final class FakeIndicatorPreferences: InputSourceIndicatorPreferences {
    var isVisible = true
    var appliedValues: [Bool] = []
    var shouldFail = false

    func setVisible(_ visible: Bool) throws {
        appliedValues.append(visible)
        if shouldFail {
            throw InputSourceIndicatorError.couldNotSave
        }
        isVisible = visible
    }
}
