import XCTest

@testable import Kivra

final class OnboardingModelTests: XCTestCase {
    @MainActor
    func testFirstLaunchStartsAtWelcome() {
        let model = makeModel(
            sources: [source("a"), source("b")],
            leftID: "a",
            rightID: "b"
        )

        XCTAssertEqual(model.step, .welcome)
    }

    @MainActor
    func testChangingLeftSourcePreservesDistinctRightSource() {
        let model = makeModel(
            sources: [source("a"), source("b"), source("c")],
            leftID: "a",
            rightID: "b"
        )

        model.selectedLeftID = "c"

        XCTAssertEqual(model.selectedRightID, "b")
    }

    @MainActor
    func testSwapLayoutsExchangesSides() {
        let model = makeModel(
            sources: [source("a"), source("b"), source("c")],
            leftID: "a",
            rightID: "c"
        )

        model.swapLayouts()

        XCTAssertEqual(model.selectedLeftID, "c")
        XCTAssertEqual(model.selectedRightID, "a")
    }

    @MainActor
    func testSwapLayoutsRequiresTwoLayouts() {
        let model = makeModel(sources: [source("a")], leftID: "a", rightID: nil)

        model.swapLayouts()

        XCTAssertEqual(model.selectedLeftID, "a")
        XCTAssertEqual(model.selectedRightID, "a")
    }

    @MainActor
    func testChangingLeftSourceResolvesRightSourceConflict() {
        let model = makeModel(
            sources: [source("a"), source("b"), source("c")],
            leftID: "a",
            rightID: "b"
        )

        model.selectedLeftID = "b"

        XCTAssertEqual(model.selectedRightID, "a")
    }

    @MainActor
    func testRefreshingSourcesMakesNewLayoutAvailable() {
        let model = makeModel(
            sources: [source("a")],
            leftID: "a",
            rightID: nil
        )

        model.updateSources([source("a"), source("b")])

        XCTAssertEqual(model.sources.map(\.id), ["a", "b"])
        XCTAssertEqual(model.selectedLeftID, "a")
        XCTAssertEqual(model.selectedRightID, "b")
        XCTAssertTrue(model.canConfigureLayouts)
    }

    @MainActor
    func testRefreshingSourcesReplacesUnavailableSelections() {
        let model = makeModel(
            sources: [source("a"), source("b"), source("c")],
            leftID: "a",
            rightID: "b"
        )

        model.updateSources([source("b"), source("c")])

        XCTAssertEqual(model.selectedLeftID, "b")
        XCTAssertEqual(model.selectedRightID, "c")
    }

    @MainActor
    func testInitialThresholdUsesConfiguredValue() {
        let model = makeModel(
            sources: [source("a"), source("b")],
            leftID: "a",
            rightID: "b",
            thresholdMilliseconds: 300
        )

        XCTAssertEqual(model.thresholdMilliseconds, 300)
    }

    @MainActor
    func testFinishPassesSelectedLayoutsAndThreshold() {
        var completedLeftID: String?
        var completedRightID: String?
        var completedThreshold: Int?
        let model = OnboardingModel(
            sources: [source("a"), source("b")],
            configuredLeftID: "a",
            configuredRightID: "b",
            thresholdMilliseconds: 250,
            inputSourceIndicator: FakeInputSourceIndicatorController(),
            accessibility: accessibilityClient(),
            onAccessibilityChange: {},
            onFinish: { leftID, rightID, thresholdMilliseconds in
                completedLeftID = leftID
                completedRightID = rightID
                completedThreshold = thresholdMilliseconds
            }
        )

        model.thresholdMilliseconds = 350
        model.finish()

        XCTAssertEqual(completedLeftID, "a")
        XCTAssertEqual(completedRightID, "b")
        XCTAssertEqual(completedThreshold, 350)
    }

    @MainActor
    func testFirstLaunchEnablesLaunchAtLoginByDefault() {
        let launchAtLogin = FakeLaunchAtLoginController(state: .disabled)
        let model = OnboardingModel(
            sources: [source("a"), source("b")],
            configuredLeftID: "a",
            configuredRightID: "b",
            thresholdMilliseconds: 250,
            launchAtLogin: launchAtLogin,
            inputSourceIndicator: FakeInputSourceIndicatorController(),
            accessibility: accessibilityClient(),
            onAccessibilityChange: {},
            onFinish: { _, _, _ in }
        )

        XCTAssertTrue(model.isLaunchAtLoginEnabled)
        XCTAssertTrue(model.isLaunchAtLoginAvailable)
    }

    @MainActor
    func testFinishAppliesLaunchAtLoginSelectionBeforeCompleting() {
        let launchAtLogin = FakeLaunchAtLoginController(state: .disabled)
        var didFinish = false
        let model = OnboardingModel(
            sources: [source("a"), source("b")],
            configuredLeftID: "a",
            configuredRightID: "b",
            thresholdMilliseconds: 250,
            launchAtLogin: launchAtLogin,
            inputSourceIndicator: FakeInputSourceIndicatorController(),
            accessibility: accessibilityClient(),
            onAccessibilityChange: {},
            onFinish: { _, _, _ in
                didFinish = true
            }
        )

        model.finish()

        XCTAssertEqual(launchAtLogin.appliedValues, [true])
        XCTAssertTrue(didFinish)
    }

    @MainActor
    func testLaunchAtLoginFailurePreventsCompletion() {
        let launchAtLogin = FakeLaunchAtLoginController(state: .disabled)
        launchAtLogin.setEnabledError = FakeLaunchAtLoginError.failed
        var didFinish = false
        let model = OnboardingModel(
            sources: [source("a"), source("b")],
            configuredLeftID: "a",
            configuredRightID: "b",
            thresholdMilliseconds: 250,
            launchAtLogin: launchAtLogin,
            inputSourceIndicator: FakeInputSourceIndicatorController(),
            accessibility: accessibilityClient(),
            onAccessibilityChange: {},
            onFinish: { _, _, _ in
                didFinish = true
            }
        )

        model.finish()

        XCTAssertFalse(didFinish)
        XCTAssertEqual(model.launchAtLoginError, "Could not update Open at Login. Try again.")
    }

    @MainActor
    func testRequestAccessibilityUsesInjectedClient() {
        var requested = false
        let model = OnboardingModel(
            sources: [source("a"), source("b")],
            configuredLeftID: "a",
            configuredRightID: "b",
            thresholdMilliseconds: 250,
            inputSourceIndicator: FakeInputSourceIndicatorController(),
            accessibility: accessibilityClient(
                granted: false,
                request: { requested = true }
            ),
            onAccessibilityChange: {},
            onFinish: { _, _, _ in }
        )

        model.requestAccessibility()

        XCTAssertTrue(requested)
        XCTAssertFalse(model.accessibilityGranted)
    }

    private func source(_ id: String) -> InputSource {
        InputSource(id: id, name: id.uppercased())
    }

    @MainActor
    private func makeModel(
        sources: [InputSource],
        leftID: String?,
        rightID: String?,
        thresholdMilliseconds: Int = 250,
        accessibilityGranted: Bool = true
    ) -> OnboardingModel {
        OnboardingModel(
            sources: sources,
            configuredLeftID: leftID,
            configuredRightID: rightID,
            thresholdMilliseconds: thresholdMilliseconds,
            inputSourceIndicator: FakeInputSourceIndicatorController(),
            accessibility: accessibilityClient(granted: accessibilityGranted),
            onAccessibilityChange: {},
            onFinish: { _, _, _ in }
        )
    }

    @MainActor
    private func accessibilityClient(
        granted: Bool = true,
        request: @escaping () -> Void = {}
    ) -> AccessibilityClient {
        AccessibilityClient(
            isGranted: { granted },
            request: request,
            openSettings: {}
        )
    }
}

@MainActor
private final class FakeLaunchAtLoginController: LaunchAtLoginControlling {
    var state: LaunchAtLoginState
    var appliedValues: [Bool] = []
    var setEnabledError: Error?

    init(state: LaunchAtLoginState) {
        self.state = state
    }

    func refresh() {}

    func setEnabled(_ enabled: Bool) throws {
        appliedValues.append(enabled)
        if let setEnabledError {
            throw setEnabledError
        }
        state = enabled ? .enabled : .disabled
    }

    func openLoginItemsSettings() {}
}

private enum FakeLaunchAtLoginError: Error {
    case failed
}
