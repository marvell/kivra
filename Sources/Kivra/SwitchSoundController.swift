import AVFAudio
import os

@MainActor
protocol SwitchSoundPlayer: AnyObject {
    var currentTime: TimeInterval { get set }
    func prepareToPlay() -> Bool
    func play() -> Bool
    func pause()
    func stop()
}

extension AVAudioPlayer: SwitchSoundPlayer {}

@MainActor
final class SwitchSoundController {
    private let makePlayer: (ShiftSide) throws -> any SwitchSoundPlayer
    private let logger = Logger(subsystem: "com.kivra.app", category: "switch-sound")
    private var players: [ShiftSide: any SwitchSoundPlayer] = [:]
    private(set) var isEnabled = false

    init(
        isEnabled: Bool = false,
        makePlayer: @escaping (ShiftSide) throws -> any SwitchSoundPlayer = {
            try AVAudioPlayer(contentsOf: soundURL(for: $0))
        }
    ) {
        self.makePlayer = makePlayer
        setEnabled(isEnabled)
    }

    static func soundURL(for side: ShiftSide) throws -> URL {
        let name = side == .left ? "pluck_002" : "bong_001"
        // SwiftPM's generated accessor does not search Contents/Resources in a macOS app.
        let bundle =
            Bundle.main.url(forResource: "Kivra_Kivra", withExtension: "bundle")
            .flatMap { Bundle(url: $0) } ?? Bundle.module
        guard
            let url = bundle.url(
                forResource: name, withExtension: "wav", subdirectory: "Sounds"
            )
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        return url
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        if enabled {
            do {
                for side in [ShiftSide.left, .right] {
                    let player = try makePlayer(side)
                    guard player.prepareToPlay() else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    players[side] = player
                }
            } catch {
                releasePlayers()
                isEnabled = false
                logger.error("Could not prepare switching sounds: \(error.localizedDescription)")
            }
        } else {
            releasePlayers()
        }
    }

    func play(for side: ShiftSide) {
        guard isEnabled, let player = players[side] else { return }
        // Interrupt the previous cue instead of layering sounds during rapid switches.
        for previous in players.values {
            previous.pause()
            previous.currentTime = 0
        }
        _ = player.play()
    }

    private func releasePlayers() {
        for player in players.values {
            player.stop()
        }
        players.removeAll()
    }
}
