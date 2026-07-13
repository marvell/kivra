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
        XCTAssertFalse(model.isSettingsMode)
    }

    @MainActor
    func testSettingsStartsAtLayoutsWhenAccessibilityIsGranted() {
        let model = makeModel(
            sources: [source("a"), source("b")],
            leftID: "a",
            rightID: "b",
            mode: .settings,
            accessibilityGranted: true
        )

        XCTAssertEqual(model.step, .layouts)
        XCTAssertTrue(model.isSettingsMode)
    }

    @MainActor
    func testSettingsStartsAtPermissionWhenAccessibilityIsNotGranted() {
        let model = makeModel(
            sources: [source("a"), source("b")],
            leftID: "a",
            rightID: "b",
            mode: .settings,
            accessibilityGranted: false
        )

        XCTAssertEqual(model.step, .permission)
        XCTAssertTrue(model.isSettingsMode)
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

    private func source(_ id: String) -> InputSource {
        InputSource(id: id, name: id.uppercased())
    }

    @MainActor
    private func makeModel(
        sources: [InputSource],
        leftID: String?,
        rightID: String?,
        thresholdMilliseconds: Int = 250,
        mode: OnboardingModel.Mode = .firstLaunch,
        accessibilityGranted: Bool = true
    ) -> OnboardingModel {
        OnboardingModel(
            sources: sources,
            configuredLeftID: leftID,
            configuredRightID: rightID,
            thresholdMilliseconds: thresholdMilliseconds,
            mode: mode,
            onAccessibilityChange: {},
            accessibilityGranted: accessibilityGranted,
            onFinish: { _, _, _ in }
        )
    }
}
