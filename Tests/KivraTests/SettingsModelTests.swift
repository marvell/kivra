import XCTest

@testable import Kivra

@MainActor
final class SettingsModelTests: XCTestCase {
    private var appliedConfigurations: [AppliedConfiguration] = []
    private var accessibilityChangeCount = 0

    func testStartsWithConfiguredValuesWithoutApplyingThem() {
        let model = makeModel(leftID: "a", rightID: "c", threshold: 320)

        XCTAssertEqual(model.selectedLeftID, "a")
        XCTAssertEqual(model.selectedRightID, "c")
        XCTAssertEqual(model.thresholdMilliseconds, 300)
        XCTAssertTrue(appliedConfigurations.isEmpty)
    }

    func testChangingLayoutAppliesImmediately() {
        let model = makeModel(leftID: "a", rightID: "b")

        model.selectedRightID = "c"

        XCTAssertEqual(appliedConfigurations.last, AppliedConfiguration("a", "c", 250))
    }

    func testChangingThresholdAppliesImmediately() {
        let model = makeModel(leftID: "a", rightID: "b")

        model.thresholdMilliseconds = 400

        XCTAssertEqual(appliedConfigurations, [AppliedConfiguration("a", "b", 400)])
    }

    func testChangingLeftToRightLayoutKeepsSidesDistinct() {
        let model = makeModel(leftID: "a", rightID: "b")

        model.selectedLeftID = "b"

        XCTAssertEqual(model.selectedRightID, "a")
        XCTAssertEqual(appliedConfigurations.last, AppliedConfiguration("b", "a", 250))
        XCTAssertFalse(appliedConfigurations.contains { $0.left == $0.right })
    }

    func testSwapLayoutsAppliesExchangedSides() {
        let model = makeModel(leftID: "a", rightID: "c")

        model.swapLayouts()

        XCTAssertEqual(model.selectedLeftID, "c")
        XCTAssertEqual(model.selectedRightID, "a")
        XCTAssertEqual(appliedConfigurations.last, AppliedConfiguration("c", "a", 250))
    }

    func testSingleLayoutIsNeverApplied() {
        let model = makeModel(sources: [source("a")], leftID: "a", rightID: nil)

        model.thresholdMilliseconds = 400
        model.swapLayouts()

        XCTAssertFalse(model.canConfigureLayouts)
        XCTAssertTrue(appliedConfigurations.isEmpty)
    }

    func testRemovedLayoutIsReplaced() {
        let model = makeModel(leftID: "a", rightID: "b")

        model.updateSources([source("a"), source("c")])

        XCTAssertEqual(model.selectedRightID, "c")
        XCTAssertEqual(appliedConfigurations.last, AppliedConfiguration("a", "c", 250))
    }

    func testLaunchAtLoginAppliesImmediately() {
        let launchAtLogin = SettingsLoginStub(state: .disabled)
        let model = makeModel(launchAtLogin: launchAtLogin)

        model.setLaunchAtLoginEnabled(true)

        XCTAssertTrue(model.isLaunchAtLoginEnabled)
        XCTAssertNil(model.launchAtLoginError)
    }

    func testLaunchAtLoginFailureKeepsActualState() {
        let launchAtLogin = SettingsLoginStub(state: .disabled)
        launchAtLogin.shouldFail = true
        let model = makeModel(launchAtLogin: launchAtLogin)

        model.setLaunchAtLoginEnabled(true)

        XCTAssertFalse(model.isLaunchAtLoginEnabled)
        XCTAssertNotNil(model.launchAtLoginError)
    }

    func testInputSourceIndicatorAppliesImmediately() {
        let indicator = FakeInputSourceIndicatorController()
        let model = makeModel(indicator: indicator)

        model.setInputSourceIndicatorHidden(true)

        XCTAssertEqual(indicator.appliedValues, [true])
        XCTAssertTrue(model.hideInputSourceIndicator)
        XCTAssertNil(model.inputSourceIndicatorError)
    }

    func testInputSourceIndicatorFailureKeepsActualState() {
        let indicator = FakeInputSourceIndicatorController()
        indicator.shouldFail = true
        let model = makeModel(indicator: indicator)

        model.setInputSourceIndicatorHidden(true)

        XCTAssertFalse(model.hideInputSourceIndicator)
        XCTAssertNotNil(model.inputSourceIndicatorError)
    }

    func testRefreshPicksUpExternalChanges() {
        var isGranted = false
        let indicator = FakeInputSourceIndicatorController()
        let launchAtLogin = SettingsLoginStub(state: .disabled)
        let model = makeModel(
            indicator: indicator,
            launchAtLogin: launchAtLogin,
            accessibility: AccessibilityClient(
                isGranted: { isGranted },
                request: {},
                openSettings: {}
            )
        )
        XCTAssertFalse(model.accessibilityGranted)

        isGranted = true
        indicator.isHidden = true
        launchAtLogin.state = .requiresApproval
        model.refresh()

        XCTAssertTrue(model.accessibilityGranted)
        XCTAssertEqual(accessibilityChangeCount, 1)
        XCTAssertTrue(model.hideInputSourceIndicator)
        XCTAssertTrue(model.launchAtLoginRequiresApproval)

        model.refresh()
        XCTAssertEqual(accessibilityChangeCount, 1)
    }

    private func makeModel(
        sources: [InputSource]? = nil,
        leftID: String? = "a",
        rightID: String? = "b",
        threshold: Int = 250,
        indicator: FakeInputSourceIndicatorController = FakeInputSourceIndicatorController(),
        launchAtLogin: SettingsLoginStub = SettingsLoginStub(state: .disabled),
        accessibility: AccessibilityClient = AccessibilityClient(
            isGranted: { true },
            request: {},
            openSettings: {}
        )
    ) -> SettingsModel {
        SettingsModel(
            sources: sources ?? [source("a"), source("b"), source("c")],
            configuration: AppConfiguration(
                leftSourceID: leftID,
                rightSourceID: rightID,
                tapThresholdMilliseconds: threshold
            ),
            launchAtLogin: launchAtLogin,
            inputSourceIndicator: indicator,
            accessibility: accessibility,
            onAccessibilityChange: { [weak self] in
                self?.accessibilityChangeCount += 1
            },
            onConfigurationChange: { [weak self] left, right, threshold in
                self?.appliedConfigurations.append(AppliedConfiguration(left, right, threshold))
            }
        )
    }

    private func source(_ id: String) -> InputSource {
        InputSource(id: id, name: id.uppercased())
    }
}

private struct AppliedConfiguration: Equatable {
    let left: String
    let right: String
    let threshold: Int

    init(_ left: String, _ right: String, _ threshold: Int) {
        self.left = left
        self.right = right
        self.threshold = threshold
    }
}

@MainActor
private final class SettingsLoginStub: LaunchAtLoginControlling {
    var state: LaunchAtLoginState
    var shouldFail = false

    init(state: LaunchAtLoginState) {
        self.state = state
    }

    func refresh() {}

    func setEnabled(_ enabled: Bool) throws {
        if shouldFail {
            throw InputSourceIndicatorError.couldNotSave
        }
        state = enabled ? .enabled : .disabled
    }

    func openLoginItemsSettings() {}
}
