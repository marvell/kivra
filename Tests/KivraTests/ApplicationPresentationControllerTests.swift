import AppKit
import XCTest

@testable import Kivra

final class ApplicationPresentationControllerTests: XCTestCase {
    @MainActor
    private final class Recorder {
        var policies: [NSApplication.ActivationPolicy] = []
        var activationCount = 0
        var badges: [String?] = []
    }

    @MainActor
    func testForegroundReasonShowsApplicationAndActivatesIt() {
        let recorder = Recorder()
        let controller = makeController(recorder: recorder)

        controller.begin(.onboarding, activate: true)

        XCTAssertEqual(recorder.policies, [.regular])
        XCTAssertEqual(recorder.activationCount, 1)
    }

    @MainActor
    func testApplicationReturnsToAccessoryAfterLastReasonEnds() {
        let recorder = Recorder()
        let controller = makeController(recorder: recorder)

        controller.begin(.settings, activate: true)
        controller.begin(.update, activate: false)
        controller.end(.update)

        XCTAssertEqual(recorder.policies, [.regular])

        controller.end(.settings)

        XCTAssertEqual(recorder.policies, [.regular, .accessory])
    }

    @MainActor
    func testScheduledUpdateShowsBadgeWithoutTakingFocus() {
        let recorder = Recorder()
        let controller = makeController(recorder: recorder)

        controller.begin(.update, activate: false, showBadge: true)

        XCTAssertEqual(recorder.policies, [.regular])
        XCTAssertEqual(recorder.activationCount, 0)
        XCTAssertEqual(recorder.badges, ["1"])

        controller.clearBadge()
        controller.end(.update)

        XCTAssertEqual(recorder.badges, ["1", nil, nil])
        XCTAssertEqual(recorder.policies, [.regular, .accessory])
    }

    @MainActor
    private func makeController(recorder: Recorder) -> ApplicationPresentationController {
        ApplicationPresentationController(
            setActivationPolicy: { recorder.policies.append($0) },
            activateApplication: { recorder.activationCount += 1 },
            setDockBadge: { recorder.badges.append($0) }
        )
    }
}
