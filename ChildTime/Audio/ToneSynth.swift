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
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

    private var buffers: [AppSound: AVAudioPCMBuffer] = [:]
    private var didStart = false

    private init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        preloadAll()
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

    // MARK: - Pre-rendering

    private func preloadAll() {
        // Bright, ascending major arpeggio. "Correct!"
        buffers[.correctSmall] = render(melody: [
            (.c5, 0.09),
            (.e5, 0.09),
            (.g5, 0.20),
        ])

        // Bigger, longer ascending arpeggio ending an octave up. "Correct + bonus!"
        buffers[.correctBig] = render(melody: [
            (.c5, 0.08),
            (.e5, 0.08),
            (.g5, 0.08),
            (.c6, 0.10),
            (.e6, 0.28),
        ])

        // Gentle descending minor third. "Hmm — try again."
        // Soft, never harsh — important for kids' confidence.
        buffers[.wrongSoft] = render(melody: [
            (.a4, 0.12),
            (.f4, 0.28),
        ])

        // Short brilliant ding. "Streak +1"
        buffers[.streakUp] = render(melody: [
            (.e6, 0.06),
            (.g6, 0.16),
        ])

        // Magical shimmer when a portal opens.
        buffers[.portalAppear] = render(melody: [
            (.g5, 0.07),
            (.b5, 0.07),
            (.d6, 0.07),
            (.g6, 0.20),
        ])

        // Festival fanfare — level up!
        buffers[.levelUp] = render(melody: [
            (.c5, 0.10),
            (.e5, 0.10),
            (.g5, 0.10),
            (.c6, 0.10),
            (.g5, 0.10),
            (.c6, 0.32),
        ])

        // Chest opens — golden cascade.
        buffers[.chestOpen] = render(melody: [
            (.g5, 0.07),
            (.c6, 0.07),
            (.e6, 0.07),
            (.g6, 0.07),
            (.c7, 0.26),
        ])

        // Companion cheers — joyful jump up.
        buffers[.companionCheer] = render(melody: [
            (.g5, 0.08),
            (.c6, 0.18),
        ])

        // World unlock — long, magical, ascending.
        buffers[.worldUnlock] = render(melody: [
            (.c5, 0.10),
            (.g5, 0.10),
            (.c6, 0.10),
            (.e6, 0.10),
            (.g6, 0.36),
        ])

        // Soft UI tap — barely-there click.
        buffers[.uiTap] = render(melody: [
            (.c6, 0.04),
        ], volume: 0.18)
    }

    // MARK: - Synthesis

    /// Render a sequence of (frequency, duration) notes into a single buffer.
    private func render(melody: [(freq: Double, dur: Double)], volume: Double = 0.32) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        var samples: [Float] = []
        for (freq, dur) in melody {
            samples.append(contentsOf: synthesizeNote(freq: freq, duration: dur, sampleRate: sampleRate, volume: volume))
        }
        return buffer(from: samples)
    }

    /// Synthesize a single note: sine wave + soft 2nd harmonic + attack/release envelope.
    private func synthesizeNote(freq: Double, duration: Double, sampleRate: Double, volume: Double) -> [Float] {
        let count = Int(duration * sampleRate)
        guard count > 0 else { return [] }
        var out = [Float](repeating: 0, count: count)

        // Envelope: ~10ms attack, decay over the second half. Prevents clicks.
        let attack = min(count / 20, Int(sampleRate * 0.012))
        let release = max(count / 3, 1)

        let twoPiF = 2.0 * .pi * freq

        for i in 0..<count {
            let t = Double(i) / sampleRate
            // Envelope value 0…1
            var env: Double = 1.0
            if i < attack {
                env = Double(i) / Double(max(attack, 1))
            } else if i > count - release {
                let remaining = Double(count - i) / Double(release)
                // smoothstep release for a softer tail
                env = remaining * remaining * (3.0 - 2.0 * remaining)
            }
            // Soft tone: fundamental + a hint of 2nd harmonic for warmth.
            let primary = sin(twoPiF * t)
            let harmonic = 0.16 * sin(twoPiF * 2.0 * t)
            out[i] = Float(env * volume * (primary + harmonic))
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
}

// MARK: - Note frequencies (Hz)

private extension Double {
    // Octave 3
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
