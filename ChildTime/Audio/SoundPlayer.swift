import Foundation
import AVFoundation
import AudioToolbox

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
            player.currentTime = 0
            player.play()
        } else {
            // No bundled file yet — emit a soft system sound as placeholder.
            placeholderSystemSound(for: sound)
        }
    }

    private func placeholderSystemSound(for sound: AppSound) {
        let systemID: SystemSoundID
        switch sound {
        case .uiTap:           systemID = 1104 // Tock
        case .correctSmall:    systemID = 1003 // Tweet
        case .correctBig:      systemID = 1025 // Fanfare
        case .wrongSoft:       systemID = 1306 // Soft click
        case .streakUp:        systemID = 1057 // Tick
        case .portalAppear:    systemID = 1117 // Glass
        case .chestOpen:       systemID = 1336 // Reward
        case .levelUp:         systemID = 1025
        case .companionCheer:  systemID = 1003
        case .worldUnlock:     systemID = 1025
        }
        AudioServicesPlaySystemSound(systemID)
    }
}
