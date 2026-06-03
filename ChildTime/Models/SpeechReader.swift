import AVFoundation

/// Reads questions & answers aloud in Hebrew — for the read-aloud button (and the
/// upcoming early-reader mode). One shared synthesizer so a new tap cancels the
/// previous utterance instead of stacking voices.
@MainActor
final class SpeechReader {
    static let shared = SpeechReader()

    private let synth = AVSpeechSynthesizer()

    private init() {}

    /// Speak a line of Hebrew. Empty/whitespace input is ignored. The text is
    /// cleaned first so the synthesizer doesn't blurt out emoji NAMES ("water
    /// wave") or choke on a geresh / quote mark.
    func speak(_ text: String) {
        let trimmed = Self.cleanForSpeech(text)
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

    /// Read a question and then each numbered answer ("תשובה 1: …, תשובה 2: …")
    /// so a non-reader can pick by number.
    func readQuestion(prompt: String, options: [String]) {
        var parts = [prompt]
        for (i, opt) in options.enumerated() {
            parts.append("תְּשׁוּבָה \(i + 1): \(opt)")
        }
        speak(parts.joined(separator: ". "))
    }

    func stop() { synth.stopSpeaking(at: .immediate) }

    /// Strip what the Hebrew voice mangles: emoji/pictographs (it reads their
    /// names), and geresh / quote marks (it stutters on them).
    private static func cleanForSpeech(_ raw: String) -> String {
        let noEmoji = String(String.UnicodeScalarView(raw.unicodeScalars.filter { s in
            switch s.value {
            case 0x1F000...0x1FAFF,   // emoji, supplemental symbols & pictographs
                 0x2600...0x27BF,     // misc symbols + dingbats
                 0x2B00...0x2BFF,     // misc symbols & arrows (stars, etc.)
                 0x2190...0x21FF,     // arrows
                 0x2300...0x23FF,     // technical (▶︎ etc.)
                 0xFE00...0xFE0F,     // variation selectors
                 0x1F1E6...0x1F1FF,   // regional indicators (flags)
                 0x200D:              // zero-width joiner
                return false
            default:
                return true
            }
        }))
        let junk: Set<Character> = [
            "'", "\u{2018}", "\u{2019}", "\u{05F3}",            // ' ' ' geresh
            "\"", "\u{201C}", "\u{201D}", "\u{201E}", "\u{05F4}", // " " gershayim
            "\u{00AB}", "\u{00BB}", "`", "\u{00B4}"
        ]
        let cleaned = noEmoji.filter { !junk.contains($0) }
        return cleaned
            .split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
