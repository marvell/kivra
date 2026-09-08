import Sparkle
import XCTest

@testable import Kivra

@MainActor
final class AppUpdateControllerTests: XCTestCase {
    private func makeUpdater() -> SPUUpdater {
        SPUUpdater(
            hostBundle: .main,
            applicationBundle: .main,
            userDriver: SPUStandardUserDriver(hostBundle: .main, delegate: nil),
            delegate: nil
        )
    }

    private func makeItem() throws -> SUAppcastItem {
        // Sparkle exposes no nondeprecated feed-item initializer for test fixtures.
        try XCTUnwrap(
            SUAppcastItem(dictionary: [
                "sparkle:version": "8",
                "sparkle:shortVersionString": "0.6.0",
                "enclosure": ["url": "https://example.com/Kivra.zip"],
            ])
        )
    }

    private func makeState(stage: SPUUserUpdateStage) throws -> SPUUserUpdateState {
        let archive = NSKeyedArchiver(requiringSecureCoding: true)
        archive.encode(stage.rawValue, forKey: "SPUUserUpdateStateStage")
        archive.encode(false, forKey: "SPUUserUpdateStateUserInitiated")
        archive.finishEncoding()
        let decoder = try NSKeyedUnarchiver(forReadingFrom: archive.encodedData)
        defer { decoder.finishDecoding() }
        return try XCTUnwrap(SPUUserUpdateState(coder: decoder))
    }

    func testSilentPreparationPublishesReadyWithoutRequestingPresentation() throws {
        var presentations = 0
        var changes: [UpdateAvailability?] = []
        let controller = AppUpdateController(
            onPresentationRequested: { _ in presentations += 1 }
        )
        controller.onAvailabilityChanged = { changes.append(controller.availability) }
        defer { controller.onAvailabilityChanged = {} }
        let updater = makeUpdater()
        let item = try makeItem()
        let delegate: SPUUpdaterDelegate = controller
        delegate.updater?(updater, didFindValidUpdate: item)
        let handlesInstallation = delegate.updater?(
            updater,
            willInstallUpdateOnQuit: item,
            immediateInstallationBlock: { XCTFail("Must leave installation to Sparkle") }
        )
        controller.updater(updater, didFinishUpdateCycleFor: .updatesInBackground, error: nil)
        controller.standardUserDriverWillFinishUpdateSession()

        XCTAssertEqual(handlesInstallation, false)
        XCTAssertEqual(presentations, 0)
        XCTAssertEqual(changes, [.available(version: "0.6.0"), .ready(version: "0.6.0")])
        XCTAssertEqual(controller.availability, .ready(version: "0.6.0"))
    }

    func testOpeningAndDismissingReadyUpdateKeepsIndicator() throws {
        let controller = AppUpdateController()
        let updater = makeUpdater()
        let item = try makeItem()
        let state = try makeState(stage: .installing)
        controller.standardUserDriverWillHandleShowingUpdate(true, forUpdate: item, state: state)
        controller.standardUserDriverDidReceiveUserAttention(forUpdate: item)
        controller.updater(updater, userDidMake: .dismiss, forUpdate: item, state: state)
        controller.standardUserDriverWillFinishUpdateSession()
        XCTAssertEqual(controller.availability, .ready(version: "0.6.0"))
    }

    func testSkippingReadyUpdateClearsIndicator() throws {
        let controller = AppUpdateController()
        let updater = makeUpdater()
        let item = try makeItem()
        let state = try makeState(stage: .installing)
        controller.standardUserDriverWillHandleShowingUpdate(true, forUpdate: item, state: state)
        controller.updater(updater, userDidMake: .skip, forUpdate: item, state: state)
        controller.standardUserDriverWillFinishUpdateSession()
        XCTAssertNil(controller.availability)
    }

    func testDismissingAvailableUpdateKeepsIndicator() throws {
        let controller = AppUpdateController()
        let updater = makeUpdater()
        let item = try makeItem()
        let state = try makeState(stage: .notDownloaded)
        controller.standardUserDriverWillHandleShowingUpdate(true, forUpdate: item, state: state)
        controller.updater(updater, userDidMake: .dismiss, forUpdate: item, state: state)
        controller.standardUserDriverWillFinishUpdateSession()
        XCTAssertEqual(controller.availability, .available(version: "0.6.0"))
    }

    func testTransientErrorDoesNotClearReadyUpdate() throws {
        let controller = AppUpdateController()
        let updater = makeUpdater()
        controller.standardUserDriverWillHandleShowingUpdate(
            true,
            forUpdate: try makeItem(),
            state: try makeState(stage: .installing)
        )
        controller.updater(
            updater,
            didFinishUpdateCycleFor: .updatesInBackground,
            error: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        )
        XCTAssertEqual(controller.availability, .ready(version: "0.6.0"))
    }

    func testUnpreparedDownloadIsNotMarkedReady() throws {
        let controller = AppUpdateController()
        controller.standardUserDriverWillHandleShowingUpdate(
            true,
            forUpdate: try makeItem(),
            state: try makeState(stage: .downloaded)
        )
        XCTAssertEqual(controller.availability, .available(version: "0.6.0"))
    }

    func testInvalidPreparedUpdateClearsIndicator() throws {
        let controller = AppUpdateController()
        let updater = makeUpdater()
        _ = controller.updater(
            updater,
            willInstallUpdateOnQuit: try makeItem(),
            immediateInstallationBlock: {}
        )
        controller.updater(
            updater,
            didFinishUpdateCycleFor: .updatesInBackground,
            error: NSError(domain: SUSparkleErrorDomain, code: Int(SUError.missingUpdateError.rawValue))
        )
        XCTAssertNil(controller.availability)
    }

    func testNoUpdateResultClearsAvailableButNotPreparedUpdate() throws {
        let controller = AppUpdateController()
        let updater = makeUpdater()
        let item = try makeItem()
        let error = NSError(domain: SUSparkleErrorDomain, code: Int(SUError.noUpdateError.rawValue))
        controller.updater(updater, didFindValidUpdate: item)
        controller.updater(updater, didFinishUpdateCycleFor: .updatesInBackground, error: error)
        XCTAssertNil(controller.availability)

        _ = controller.updater(updater, willInstallUpdateOnQuit: item, immediateInstallationBlock: {})
        controller.updater(updater, didFinishUpdateCycleFor: .updatesInBackground, error: error)
        XCTAssertEqual(controller.availability, .ready(version: "0.6.0"))
    }
}
