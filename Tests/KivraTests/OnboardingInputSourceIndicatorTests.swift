import XCTest

@testable import Kivra

@MainActor
final class OnboardingInputSourceIndicatorTests: XCTestCase {
    func testFirstLaunchDoesNotOptInByDefault() {
        let indicator = FakeInputSourceIndicatorController()
        let model = makeModel(indicator: indicator)

        XCTAssertFalse(model.hideInputSourceIndicator)
        XCTAssertTrue(indicator.appliedValues.isEmpty)
    }

    func testManualSettingIsReflectedInToggleWithoutWriting() {
        let indicator = FakeInputSourceIndicatorController()
        indicator.isHidden = true
        let model = makeModel(indicator: indicator)

        XCTAssertTrue(model.hideInputSourceIndicator)
        XCTAssertTrue(indicator.appliedValues.isEmpty)
    }

    func testSettingsShowsCurrentSystemState() {
        let indicator = FakeInputSourceIndicatorController()
        indicator.isHidden = true
        let model = makeModel(indicator: indicator, mode: .settings)

        XCTAssertTrue(model.hideInputSourceIndicator)
        XCTAssertTrue(indicator.appliedValues.isEmpty)
    }

    func testChangingDraftDoesNotApplySystemSetting() {
        let indicator = FakeInputSourceIndicatorController()
        let model = makeModel(indicator: indicator)

        model.hideInputSourceIndicator = true
        model.hideInputSourceIndicator = false

        XCTAssertTrue(indicator.appliedValues.isEmpty)
    }

    func testExplicitOffAfterDraftChangeIsAppliedOnSave() {
        let indicator = FakeInputSourceIndicatorController()
        let model = makeModel(indicator: indicator)
        model.hideInputSourceIndicator = true
        model.hideInputSourceIndicator = false
        indicator.isHidden = true

        model.finish()

        XCTAssertEqual(indicator.appliedValues, [false])
        XCTAssertFalse(indicator.isHidden)
    }

    func testFinishAppliesOptInBeforeCompleting() {
        let indicator = FakeInputSourceIndicatorController()
        var didFinish = false
        let model = makeModel(indicator: indicator) {
            XCTAssertEqual(indicator.appliedValues, [true])
            didFinish = true
        }
        model.hideInputSourceIndicator = true

        model.finish()

        XCTAssertTrue(didFinish)
        XCTAssertNil(model.inputSourceIndicatorError)
    }

    func testSavingSettingsCanOptOut() {
        let indicator = FakeInputSourceIndicatorController()
        indicator.isHidden = true
        let model = makeModel(indicator: indicator, mode: .settings)
        model.hideInputSourceIndicator = false

        model.finish()

        XCTAssertEqual(indicator.appliedValues, [false])
    }

    func testSavingUnchangedManualSettingDoesNotWrite() {
        let indicator = FakeInputSourceIndicatorController()
        indicator.isHidden = true
        var didFinish = false
        let model = makeModel(indicator: indicator) { didFinish = true }

        model.finish()

        XCTAssertTrue(didFinish)
        XCTAssertTrue(model.hideInputSourceIndicator)
        XCTAssertTrue(indicator.appliedValues.isEmpty)
    }

    func testManualSettingCanBeExplicitlyTurnedOff() {
        let indicator = FakeInputSourceIndicatorController()
        indicator.isHidden = true
        let model = makeModel(indicator: indicator, mode: .settings)
        model.hideInputSourceIndicator = false

        model.finish()

        XCTAssertEqual(indicator.appliedValues, [false])
        XCTAssertFalse(indicator.isHidden)
    }

    func testSavingUnchangedVisibleSettingDoesNotWrite() {
        let indicator = FakeInputSourceIndicatorController()
        let model = makeModel(indicator: indicator)

        model.finish()

        XCTAssertTrue(indicator.appliedValues.isEmpty)
    }

    func testUnchangedDraftDoesNotOverwriteExternalChange() {
        let indicator = FakeInputSourceIndicatorController()
        let model = makeModel(indicator: indicator)
        indicator.isHidden = true

        model.finish()

        XCTAssertTrue(indicator.isHidden)
        XCTAssertTrue(indicator.appliedValues.isEmpty)
    }

    func testRepeatedSaveDoesNotReapplyChange() {
        let indicator = FakeInputSourceIndicatorController()
        let model = makeModel(indicator: indicator)
        model.hideInputSourceIndicator = true

        model.finish()
        model.finish()

        XCTAssertEqual(indicator.appliedValues, [true])
    }

    func testFailedChangeCanBeRevertedToInitialState() {
        let indicator = FakeInputSourceIndicatorController()
        indicator.shouldFailAfterWrite = true
        let model = makeModel(indicator: indicator)
        model.hideInputSourceIndicator = true
        model.finish()
        XCTAssertTrue(indicator.isHidden)
        XCTAssertNotNil(model.inputSourceIndicatorError)

        indicator.shouldFailAfterWrite = false
        model.hideInputSourceIndicator = false
        model.finish()

        XCTAssertEqual(indicator.appliedValues, [true, false])
        XCTAssertFalse(indicator.isHidden)
        XCTAssertNil(model.inputSourceIndicatorError)
    }

    func testFailureKeepsOnboardingOpenAndCanBeRetried() {
        let indicator = FakeInputSourceIndicatorController()
        indicator.shouldFail = true
        var didFinish = false
        let model = makeModel(indicator: indicator) { didFinish = true }
        model.hideInputSourceIndicator = true

        model.finish()

        XCTAssertFalse(didFinish)
        XCTAssertNotNil(model.inputSourceIndicatorError)
        XCTAssertTrue(model.hideInputSourceIndicator)
        indicator.shouldFail = false
        model.finish()
        XCTAssertTrue(didFinish)
        XCTAssertNil(model.inputSourceIndicatorError)
    }

    func testInvalidLayoutsDoNotApplyOptIn() {
        let indicator = FakeInputSourceIndicatorController()
        let model = makeModel(indicator: indicator)
        model.selectedRightID = model.selectedLeftID
        model.hideInputSourceIndicator = true

        model.finish()

        XCTAssertTrue(indicator.appliedValues.isEmpty)
    }

    func testLoginItemFailureDoesNotApplyOptIn() {
        let indicator = FakeInputSourceIndicatorController()
        let login = OnboardingLoginStub()
        login.shouldFail = true
        let model = makeModel(indicator: indicator, login: login)
        model.hideInputSourceIndicator = true

        model.finish()

        XCTAssertTrue(indicator.appliedValues.isEmpty)
        XCTAssertNotNil(model.launchAtLoginError)
    }

    func testLoginFailureDoesNotClearUnresolvedIndicatorError() {
        let indicator = FakeInputSourceIndicatorController()
        let login = OnboardingLoginStub()
        let model = makeModel(indicator: indicator, login: login)
        model.hideInputSourceIndicator = true
        indicator.shouldFail = true
        model.finish()
        let indicatorError = model.inputSourceIndicatorError
        XCTAssertNotNil(indicatorError)

        login.shouldFail = true
        model.finish()

        XCTAssertEqual(model.inputSourceIndicatorError, indicatorError)
        XCTAssertEqual(indicator.appliedValues, [true])
    }

    private func makeModel(
        indicator: FakeInputSourceIndicatorController,
        mode: OnboardingModel.Mode = .firstLaunch,
        login: OnboardingLoginStub = OnboardingLoginStub(),
        onFinish: @escaping () -> Void = {}
    ) -> OnboardingModel {
        OnboardingModel(
            sources: [InputSource(id: "a", name: "A"), InputSource(id: "b", name: "B")],
            configuredLeftID: "a",
            configuredRightID: "b",
            thresholdMilliseconds: 250,
            mode: mode,
            launchAtLogin: login,
            inputSourceIndicator: indicator,
            accessibility: AccessibilityClient(isGranted: { true }, request: {}, openSettings: {}),
            onAccessibilityChange: {},
            onFinish: { _, _, _ in onFinish() }
        )
    }
}

@MainActor
private final class OnboardingLoginStub: LaunchAtLoginControlling {
    var state: LaunchAtLoginState = .disabled
    var shouldFail = false

    func refresh() {}

    func setEnabled(_ enabled: Bool) throws {
        if shouldFail {
            throw InputSourceIndicatorError.couldNotSave
        }
        state = enabled ? .enabled : .disabled
    }

    func openLoginItemsSettings() {}
}
