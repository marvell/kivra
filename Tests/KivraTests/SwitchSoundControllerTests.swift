import AVFAudio
import XCTest

@testable import Kivra

@MainActor
final class SwitchSoundControllerTests: XCTestCase {
    func testDisabledControllerDoesNotLoadOrPlayAudio() {
        let controller = SwitchSoundController { _ in
            XCTFail("Disabled sounds must not load audio")
            return FakeSwitchSoundPlayer()
        }
        XCTAssertFalse(controller.isEnabled)
        controller.play(for: .left)
        controller.play(for: .right)
    }

    func testEnablingPreparesBothSoundsAndPlaysMatchingSideWithoutReloading() {
        let left = FakeSwitchSoundPlayer()
        let right = FakeSwitchSoundPlayer()
        var loaded: [ShiftSide] = []
        let controller = SwitchSoundController { side in
            loaded.append(side)
            return side == .left ? left : right
        }
        controller.setEnabled(true)
        controller.setEnabled(true)
        XCTAssertEqual(loaded, [.left, .right])
        XCTAssertEqual(left.prepareCount, 1)
        XCTAssertEqual(right.prepareCount, 1)

        controller.play(for: .left)
        XCTAssertEqual(left.playCount, 1)
        XCTAssertEqual(right.playCount, 0)
        left.currentTime = 0.1
        controller.play(for: .right)
        XCTAssertEqual(left.currentTime, 0)
        XCTAssertEqual(right.playCount, 1)
        XCTAssertEqual(left.pauseCount, 2)
        controller.play(for: .right)
        XCTAssertEqual(right.playCount, 2)
        XCTAssertEqual(loaded, [.left, .right])
    }

    func testDisablingStopsPlayersAndReenablingReloadsThem() {
        let player = FakeSwitchSoundPlayer()
        var loadCount = 0
        let controller = SwitchSoundController(isEnabled: true) { _ in
            loadCount += 1
            return player
        }
        controller.play(for: .left)
        controller.setEnabled(false)
        XCTAssertEqual(player.stopCount, 2)
        controller.play(for: .right)
        XCTAssertEqual(player.playCount, 1)
        controller.setEnabled(true)
        XCTAssertEqual(loadCount, 4)
    }

    func testFailedLoadingReleasesPreparedPlayersAndDoesNotPlay() {
        let player = FakeSwitchSoundPlayer()
        var loadAttemptCount = 0
        let controller = SwitchSoundController(isEnabled: true) { side in
            loadAttemptCount += 1
            if side == .right { throw CocoaError(.fileNoSuchFile) }
            return player
        }
        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(player.stopCount, 1)
        controller.play(for: .left)
        XCTAssertEqual(player.playCount, 0)

        controller.setEnabled(true)
        XCTAssertEqual(loadAttemptCount, 4)
    }

    func testFailedPreparationDoesNotPlay() {
        let player = FakeSwitchSoundPlayer()
        player.canPrepare = false
        let controller = SwitchSoundController(isEnabled: true) { _ in player }
        XCTAssertFalse(controller.isEnabled)
        controller.play(for: .left)
        XCTAssertEqual(player.playCount, 0)
    }

    func testBundledSoundsAreDistinctDecodableWAVFiles() throws {
        let leftURL = try SwitchSoundController.soundURL(for: .left)
        let rightURL = try SwitchSoundController.soundURL(for: .right)
        XCTAssertEqual(leftURL.lastPathComponent, "pluck_002.wav")
        XCTAssertEqual(rightURL.lastPathComponent, "bong_001.wav")
        XCTAssertNotEqual(try Data(contentsOf: leftURL), try Data(contentsOf: rightURL))
        for url in [leftURL, rightURL] {
            let player = try AVAudioPlayer(contentsOf: url)
            XCTAssertGreaterThan(player.duration, 0)
            XCTAssertLessThan(player.duration, 2)
        }
    }
}

@MainActor
private final class FakeSwitchSoundPlayer: SwitchSoundPlayer {
    var currentTime: TimeInterval = 0
    var canPrepare = true
    private(set) var prepareCount = 0
    private(set) var playCount = 0
    private(set) var pauseCount = 0
    private(set) var stopCount = 0

    func prepareToPlay() -> Bool {
        prepareCount += 1
        return canPrepare
    }

    func play() -> Bool {
        playCount += 1
        return true
    }

    func pause() {
        pauseCount += 1
    }

    func stop() {
        stopCount += 1
    }
}
