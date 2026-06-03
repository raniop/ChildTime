import AVFoundation

/// Reads questions & answers aloud in Hebrew — for the read-aloud button (and the
/// upcoming early-reader mode). One shared synthesizer so a new tap cancels the
/// previous utterance instead of stacking voices.
@MainActor
final class SpeechReader {
    static let shared = SpeechReader()

    private let synth = AVSpeechSynthesizer()

    private init() {}

    /// Speak a line of Hebrew. Empty/whitespace input is ignored.
    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Make sure speech actually plays — duck (not silence) game sound, and
        // play even when the ringer switch is on silent (read-aloud must be heard).
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers])
        try? session.setActive(true)
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: trimmed)
        // Hebrew voice; AVSpeech falls back to a default if he-IL isn't installed.
        u.voice = AVSpeechSynthesisVoice(language: "he-IL")
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9   // a touch slower for kids
        u.pitchMultiplier = 1.05
        u.preUtteranceDelay = 0.05
        synth.speak(u)
    }

    /// Read a question and all of its answer options, one after another.
    func readQuestion(prompt: String, options: [String]) {
        speak(([prompt] + options).joined(separator: ". "))
    }

    func stop() { synth.stopSpeaking(at: .immediate) }
}
