import Foundation
import AVFoundation

/// Procedural tone synthesizer — generates pleasant melodies in code so we don't
/// need to bundle audio assets. Used as the playback engine inside `SoundPlayer`
/// for sounds that don't have a bundled file.
///
/// Each melody is a short sequence of sine notes with a small attack/release
/// envelope so they don't click. We pre-render every melody at init time and
/// schedule the buffer on demand for instant, low-latency playback.
@MainActor
final class ToneSynth {
    static let shared = ToneSynth()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let musicPlayer = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

    private var buffers: [AppSound: AVAudioPCMBuffer] = [:]
    private var musicBuffer: AVAudioPCMBuffer?
    /// If a real music track is bundled (background_music.mp3/.m4a/.caf/.wav),
    /// we play THAT instead of the procedural loop. Drop a file in to upgrade.
    private var musicFilePlayer: AVAudioPlayer?
    private var didStart = false
    private var musicOn = false

    private init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.attach(musicPlayer)
        engine.connect(musicPlayer, to: engine.mainMixerNode, format: format)
        preloadAll()
        musicFilePlayer = Self.loadBundledMusic()
        if musicFilePlayer == nil { musicBuffer = renderMusicLoop() }
    }

    /// Looks for a bundled background-music track (any common format).
    private static func loadBundledMusic() -> AVAudioPlayer? {
        let name = "background_music"
        let url = ["mp3", "m4a", "caf", "wav"].lazy
            .compactMap { Bundle.main.url(forResource: name, withExtension: $0) }
            .first
        guard let url, let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
        p.numberOfLoops = -1     // seamless infinite loop
        p.volume = 0.5           // soft bed under the effects
        p.prepareToPlay()
        return p
    }

    /// Lazy-start the engine on first play (avoids audio session conflicts at launch).
    private func ensureRunning() {
        guard !didStart else { return }
        do {
            try engine.start()
            player.play()
            didStart = true
        } catch {
            // Silent fallback — we'll just no-op the playback if the engine fails.
        }
    }

    func play(_ sound: AppSound) {
        ensureRunning()
        guard let buf = buffers[sound] else { return }
        player.scheduleBuffer(buf, at: nil, options: .interrupts, completionHandler: nil)
    }

    // MARK: - Background music

    /// Whether the music bed *should* be playing (the child is in the main app).
    /// Distinct from `musicOn` so we can pause for backgrounding and resume
    /// without ever starting music on the login / parent screens.
    private var wantsMusic = false

    /// Start the gentle looping music bed (idempotent). No-op when sounds are
    /// disabled in Parent Settings.
    func startMusic() {
        wantsMusic = true
        guard ParentSettings.shared.soundsEnabled else { stopMusic(keepIntent: true); return }
        // Prefer a bundled professional track if one exists.
        if let fp = musicFilePlayer {
            if !fp.isPlaying { fp.play() }
            musicOn = true
            return
        }
        ensureRunning()
        guard !musicOn, let buf = musicBuffer else { return }
        musicOn = true
        musicPlayer.scheduleBuffer(buf, at: nil, options: .loops, completionHandler: nil)
        musicPlayer.play()
    }

    /// Stop the music. By default clears the intent (e.g. the sound toggle was
    /// turned off); pass `keepIntent` to merely silence it for now.
    func stopMusic(keepIntent: Bool = false) {
        if !keepIntent { wantsMusic = false }
        guard musicOn else { return }
        musicOn = false
        if let fp = musicFilePlayer { fp.stop(); fp.currentTime = 0 }
        else { musicPlayer.stop() }
    }

    /// Pause for app backgrounding without losing the intent to play.
    func pauseMusic() {
        guard musicOn else { return }
        if let fp = musicFilePlayer { fp.pause() } else { musicPlayer.pause() }
    }

    /// Resume after returning to the foreground, only if music was wanted.
    func resumeMusicIfWanted() {
        guard wantsMusic, ParentSettings.shared.soundsEnabled else { return }
        if let fp = musicFilePlayer {
            if !fp.isPlaying { fp.play() }
            return
        }
        ensureRunning()
        if musicOn { musicPlayer.play() } else { startMusic() }
    }

    /// Re-evaluate against the current sound setting (call when the toggle flips).
    func refreshMusic() {
        if ParentSettings.shared.soundsEnabled { startMusic() } else { stopMusic() }
    }

    // MARK: - Pre-rendering

    private func preloadAll() {
        // Volume design notes:
        //   • Master volume default = 0.16 (was 0.32). Kids hold the iPad
        //     close to their face — old volume was harsh, especially on the
        //     wrong-answer chime.
        //   • Notes are shorter so they don't linger.
        //   • Wrong-answer is now a single soft thud, not a melody — most
        //     parents felt the descending interval sounded "judging."

        // Bright, ascending major arpeggio. "Correct!"
        buffers[.correctSmall] = render(melody: [
            (.c5, 0.07),
            (.e5, 0.07),
            (.g5, 0.14),
        ])

        // Bigger ascending arpeggio for super questions.
        buffers[.correctBig] = render(melody: [
            (.c5, 0.06),
            (.e5, 0.06),
            (.g5, 0.06),
            (.c6, 0.08),
            (.e6, 0.20),
        ])

        // Single, soft mid-low chime. Neutral — not punishing.
        buffers[.wrongSoft] = render(melody: [
            (.f4, 0.18),
        ], volume: 0.08)

        // Quick ding for streak +1.
        buffers[.streakUp] = render(melody: [
            (.e6, 0.05),
            (.g6, 0.10),
        ])

        // Magical shimmer when a portal opens.
        buffers[.portalAppear] = render(melody: [
            (.g5, 0.05),
            (.b5, 0.05),
            (.d6, 0.05),
            (.g6, 0.14),
        ])

        // Festival fanfare — level up. Kept lively but not loud.
        buffers[.levelUp] = render(melody: [
            (.c5, 0.08),
            (.e5, 0.08),
            (.g5, 0.08),
            (.c6, 0.08),
            (.g5, 0.08),
            (.c6, 0.22),
        ])

        // Chest opens — golden cascade.
        buffers[.chestOpen] = render(melody: [
            (.g5, 0.05),
            (.c6, 0.05),
            (.e6, 0.05),
            (.g6, 0.05),
            (.c7, 0.18),
        ])

        // Companion cheers — joyful jump up.
        buffers[.companionCheer] = render(melody: [
            (.g5, 0.06),
            (.c6, 0.12),
        ])

        // World unlock — long, magical, ascending.
        buffers[.worldUnlock] = render(melody: [
            (.c5, 0.08),
            (.g5, 0.08),
            (.c6, 0.08),
            (.e6, 0.08),
            (.g6, 0.26),
        ])

        // Soft UI tap — barely-there click.
        buffers[.uiTap] = render(melody: [
            (.c6, 0.03),
        ], volume: 0.09)
    }

    // MARK: - Synthesis

    /// Render a sequence of (frequency, duration) notes into a single buffer.
    private func render(melody: [(freq: Double, dur: Double)], volume: Double = 0.16) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        var samples: [Float] = []
        for (freq, dur) in melody {
            samples.append(contentsOf: synthesizeNote(freq: freq, duration: dur, sampleRate: sampleRate, volume: volume))
        }
        return buffer(from: samples)
    }

    /// Synthesize a single note with a warm music-box / glockenspiel timbre:
    /// a few harmonics that fade quickly, a gentle exponential "bell" decay so
    /// notes ring and soften, plus a touch of vibrato for life. Much friendlier
    /// to a child's ear than a flat sine.
    private func synthesizeNote(freq: Double, duration: Double, sampleRate: Double, volume: Double) -> [Float] {
        let count = Int(duration * sampleRate)
        guard count > 0 else { return [] }
        var out = [Float](repeating: 0, count: count)

        // Short click-free attack, then exponential decay across the whole note.
        let attack = max(1, Int(sampleRate * 0.006))
        let decayTau = max(0.04, duration * 0.45)

        let twoPiF = 2.0 * .pi * freq
        // Harmonic recipe — bright but rounded; upper partials are quiet.
        let harmonics: [(mult: Double, amp: Double)] = [
            (1.0, 1.0), (2.0, 0.5), (3.0, 0.22), (4.0, 0.10)
        ]
        let norm = 1.82   // sum of amps, to keep peak ≈ 1
        let vibratoHz = 5.0
        let vibratoDepth = 0.004

        for i in 0..<count {
            let t = Double(i) / sampleRate
            var env = exp(-t / decayTau)
            if i < attack { env *= Double(i) / Double(attack) }
            let vib = 1.0 + vibratoDepth * sin(2.0 * .pi * vibratoHz * t)
            var s = 0.0
            for h in harmonics { s += h.amp * sin(twoPiF * h.mult * t * vib) }
            out[i] = Float(env * volume * (s / norm))
        }
        return out
    }

    private func buffer(from samples: [Float]) -> AVAudioPCMBuffer {
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buf.frameLength = AVAudioFrameCount(samples.count)
        let channel = buf.floatChannelData![0]
        for i in 0..<samples.count {
            channel[i] = samples[i]
        }
        return buf
    }

    // MARK: - Music loop

    /// Build a soft, cheerful, seamlessly-looping melody bed using the same
    /// bell timbre. C-major pentatonic (C D E G A) so nothing ever clashes —
    /// a calm, inviting backdrop, kept very quiet under the sound effects.
    private func renderMusicLoop() -> AVAudioPCMBuffer {
        let sr = format.sampleRate
        let beat = 0.5                      // 120 BPM feel
        let totalBeats = 16                 // ~8s loop
        let totalSamples = Int(Double(totalBeats) * beat * sr)
        var mix = [Float](repeating: 0, count: totalSamples)

        func place(_ freq: Double, beatIndex: Double, dur: Double, vol: Double) {
            let start = Int(beatIndex * beat * sr)
            let note = synthesizeNote(freq: freq, duration: dur, sampleRate: sr, volume: vol)
            for j in 0..<note.count {
                let idx = start + j
                if idx >= 0 && idx < totalSamples { mix[idx] += note[j] }
            }
        }

        // Flowing pentatonic melody (rest on the final beat → seamless loop).
        let melody: [(Double, Double)] = [
            (.c5, 0), (.e5, 1), (.g5, 2), (.e5, 3),
            (.d5, 4), (.g5, 5), (.a5, 6), (.g5, 7),
            (.e5, 8), (.g5, 9), (.c6, 10), (.a5, 11),
            (.g5, 12), (.e5, 13), (.d5, 14),
        ]
        for (f, b) in melody { place(f, beatIndex: b, dur: 0.7, vol: 0.05) }

        // Soft low root, one per bar, for a gentle harmonic floor.
        place(.c4, beatIndex: 0,  dur: 1.8, vol: 0.045)
        place(.a3, beatIndex: 4,  dur: 1.8, vol: 0.045)
        place(.c4, beatIndex: 8,  dur: 1.8, vol: 0.045)
        place(.g3, beatIndex: 12, dur: 1.8, vol: 0.045)

        // Soft clamp so summed notes never clip.
        for i in 0..<totalSamples { mix[i] = max(-0.85, min(0.85, mix[i])) }
        return buffer(from: mix)
    }
}

// MARK: - Note frequencies (Hz)

private extension Double {
    // Octave 3
    static let g3:  Double = 196.00
    static let a3:  Double = 220.00
    static let b3:  Double = 246.94
    // Octave 4
    static let c4:  Double = 261.63
    static let d4:  Double = 293.66
    static let e4:  Double = 329.63
    static let f4:  Double = 349.23
    static let g4:  Double = 392.00
    static let a4:  Double = 440.00
    static let b4:  Double = 493.88
    // Octave 5
    static let c5:  Double = 523.25
    static let d5:  Double = 587.33
    static let e5:  Double = 659.25
    static let f5:  Double = 698.46
    static let g5:  Double = 783.99
    static let a5:  Double = 880.00
    static let b5:  Double = 987.77
    // Octave 6
    static let c6:  Double = 1046.50
    static let d6:  Double = 1174.66
    static let e6:  Double = 1318.51
    static let f6:  Double = 1396.91
    static let g6:  Double = 1567.98
    // Octave 7
    static let c7:  Double = 2093.00
}
