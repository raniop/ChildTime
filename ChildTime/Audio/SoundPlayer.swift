import Foundation
import AVFoundation

@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    private var players: [AppSound: AVAudioPlayer] = [:]
    var isMuted: Bool = false

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        preload()
    }

    private func preload() {
        for sound in AppSound.allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "caf")
                    ?? Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3")
                    ?? Bundle.main.url(forResource: sound.rawValue, withExtension: "wav")
            else { continue }
            if let p = try? AVAudioPlayer(contentsOf: url) {
                p.prepareToPlay()
                players[sound] = p
            }
        }
    }

    func play(_ sound: AppSound) {
        guard !isMuted else { return }
        if let player = players[sound] {
            // Prefer bundled audio asset if one exists.
            player.currentTime = 0
            player.play()
        } else {
            // No bundled file — synthesize a pleasant melody procedurally.
            ToneSynth.shared.play(sound)
        }
    }
}
