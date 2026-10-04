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
        synth.stopSpeaking(at: .immediate)
        let language = LanguageStore.shared.current
        // 🧊 The FIRST `speechVoices()` on a cold device blocks the caller for
        // seconds while the speech service wakes up — and a גן round asks to
        // speak from a view's `onAppear`, i.e. inside the very first layout
        // pass. That froze the whole app on a black screen (the chooser at
        // grade 0 never appeared). So the voice is resolved OFF the main
        // thread the first time and cached; speaking itself stays on main.
        if let voice = Self.cachedVoice(for: language) {
            utter(trimmed, voice: voice)
            return
        }
        Self.voiceQueue.async {
            let voice = Self.bestVoice(for: language)
            Task { @MainActor in
                Self.voiceCache[language] = .some(voice)
                // Only speak if nothing newer asked to: a later `speak` already
                // has the cache and would have started its own utterance.
                self.utter(trimmed, voice: voice)
            }
        }
    }

    /// Start one utterance. Main thread, cheap, no voice lookup.
    private func utter(_ text: String, voice: AVSpeechSynthesisVoice?) {
        // Make sure speech actually plays — duck (not silence) game sound, and
        // play even when the ringer switch is on silent (read-aloud must be heard).
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers])
        try? session.setActive(true)
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = voice
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9   // a touch slower for kids
        u.pitchMultiplier = 1.05
        u.preUtteranceDelay = 0.05
        synth.speak(u)
    }

    /// The resolved voice per language — `nil` value means "resolved, and this
    /// device has none", which is still an answer worth caching.
    private static var voiceCache: [AppLanguage: AVSpeechSynthesisVoice?] = [:]
    private static let voiceQueue = DispatchQueue(label: "tofy.speech.voice", qos: .userInitiated)

    private static func cachedVoice(for language: AppLanguage) -> AVSpeechSynthesisVoice?? {
        voiceCache[language]
    }

    /// Resolve the voice list once, early and off the main thread, so the first
    /// thing that wants to be read aloud never waits for it.
    static func warmUp() {
        let language = LanguageStore.shared.current
        guard voiceCache[language] == nil else { return }
        voiceQueue.async {
            let voice = bestVoice(for: language)
            Task { @MainActor in voiceCache[language] = .some(voice) }
        }
    }

    /// Read a question, then each answer — always the NUMBER first, then the
    /// answer, with a full stop between them so the voice pauses:
    /// "מִסְפָּר 1. קָטָן. מִסְפָּר 2. קְטַנּוֹת" — the numbers match the tags on the tiles,
    /// so a non-reader can pick by number.
    ///
    /// When every answer is itself a NUMBER, "מספר 1. 4" reads as two numbers and
    /// confuses — so the tile is named by its ORDER instead: "תְּשׁוּבָה רִאשׁוֹנָה. 4.
    /// תְּשׁוּבָה שְׁנִיָּה. 2".
    func readQuestion(prompt: String, options: [String]) {
        speak(Self.spokenScript(prompt: prompt, options: options))
    }

    static var ordinals: [String] { [tr("רִאשׁוֹנָה"), tr("שְׁנִיָּה"), tr("שְׁלִישִׁית"), tr("רְבִיעִית"), tr("חֲמִישִׁית"), tr("שִׁשִּׁית")] }

    /// The full read-aloud script (question + numbered answers). Pure, for tests.
    static func spokenScript(prompt: String, options: [String]) -> String {
        let numericAnswers = !options.isEmpty && options.allSatisfy {
            Int($0.trimmingCharacters(in: .whitespaces)) != nil
        }
        var parts = [prompt]
        for (i, opt) in options.enumerated() {
            let label = numericAnswers
                ? tr("תְּשׁוּבָה \(ordinals[min(i, ordinals.count - 1)])")
                : tr("מִסְפָּר \(i + 1)")
            parts.append(label)
            parts.append(opt)
        }
        return parts.joined(separator: ". ")
    }

    func stop() { synth.stopSpeaking(at: .immediate) }

    /// The most natural Hebrew voice INSTALLED on this device: premium > enhanced
    /// > the compact default. iOS ships only the compact "Carmit"; the enhanced one
    /// is a free download (Settings → Accessibility → Spoken Content → Voices →
    /// Hebrew) and is picked up here automatically. Falls back to the system default
    /// when no he-IL voice exists at all.
    nonisolated static func bestHebrewVoice() -> AVSpeechSynthesisVoice? { bestVoice(for: .he) }

    /// The best installed voice for a language — same ranking, any language.
    /// 🧊 `nonisolated` on purpose: the first call wakes the speech service and
    /// can block for seconds, so it is resolved off the main thread (see
    /// `speak` and `warmUp`) and never during a view's first layout.
    nonisolated static func bestVoice(for language: AppLanguage) -> AVSpeechSynthesisVoice? {
        let region = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language.speechCode }
        let anyRegion = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(language.rawValue) }
        let ranked = (region.isEmpty ? anyRegion : region).sorted { $0.quality.rawValue > $1.quality.rawValue }
        return ranked.first ?? AVSpeechSynthesisVoice(language: language.speechCode)
    }

    /// Clean text for the Hebrew voice: drop emoji (it reads their names), turn
    /// math symbols into spoken words (`−`/`=`/`×`/`÷` are otherwise SILENT, so
    /// "4 − 2 = ?" came out "four two"), and remove geresh / quote marks.
    static func cleanForSpeech(_ raw: String) -> String {
        // 1) Math symbols → words. The generator uses the dedicated −/×/÷ glyphs
        //    (never a plain hyphen), so this never touches ordinary text.
        var math = raw
        math = math.replacingOccurrences(of: "= ?", with: tr(" \(tr("כַּמָּה זֶה")) "))
        math = math.replacingOccurrences(of: "=?", with: tr(" \(tr("כַּמָּה זֶה")) "))
        math = math.replacingOccurrences(of: "+", with: tr(" \(tr("וְעוֹד")) "))
        math = math.replacingOccurrences(of: "\u{2212}", with: tr(" \(tr("פָּחוֹת")) "))   // − minus sign
        math = math.replacingOccurrences(of: "\u{00D7}", with: tr(" \(tr("כָּפוּל")) "))   // × times
        math = math.replacingOccurrences(of: "\u{00F7}", with: tr(" \(tr("חֶלְקֵי")) "))   // ÷ divide
        math = math.replacingOccurrences(of: "=", with: tr(" \(tr("שָׁוֶה")) "))           // any other =

        let noEmoji = String(String.UnicodeScalarView(math.unicodeScalars.filter { s in
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
