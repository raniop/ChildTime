import Foundation
import AVFoundation

@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    private var players: [AppSound: AVAudioPlayer] = [:]
    /// Every AVAudioPlayer call after preload happens here, one at a time.
    private nonisolated static let audioQueue = DispatchQueue(label: "com.rani.tofy.sound-player", qos: .userInteractive)

    /// Programmatic override for testing/dev. Production gating lives on
    /// `ParentSettings.shared.soundsEnabled`.
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
        // Respect the parent's master sound toggle.
        guard ParentSettings.shared.soundsEnabled else { return }
        if let player = players[sound] {
            // AVAudioPlayer.play() starts an audio queue and can block for tens of
            // milliseconds (measured: 25–50ms on the simulator) — on the main
            // thread that froze every answer, cheer and balloon pop (Rani). It
            // runs on its own serial queue now; the UI never waits for it.
            Self.audioQueue.async {
                player.currentTime = 0
                player.play()
            }
        } else {
            ToneSynth.shared.play(sound)
        }
    }
}
