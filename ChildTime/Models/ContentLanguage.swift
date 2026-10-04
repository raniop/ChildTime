import Foundation

/// 🧊 What a topic's content IS, in one language — worked out once.
///
/// Assembling a bank is not cheap: the built-in files are concatenated into a
/// fresh array, the cloud items are validated one by one and de-duplicated
/// against it. That is fine once; it is not fine inside a view's body, which is
/// where `ContentAvailability.hasContent` is asked from (the kid's home calls it
/// for every pack, for every tile, on every render).
///
/// Keyed by "topic|language", so switching language is simply a different key —
/// nothing to invalidate. The one thing that DOES change under us is the cloud
/// bank, and `RemoteQuestionBank` clears this after a sync that brought
/// something new, so new questions still reach a child without a relaunch.
///
/// `build` deliberately runs OUTSIDE the lock: assembling a bank asks for
/// availability and vice versa, and a lock held across that would deadlock.
/// The cost of two threads racing to build the same key is one wasted build.
enum ContentCache {
    private static let lock = NSLock()
    private static var banks: [String: [BankQuestion]?] = [:]
    private static var availability: [String: Bool] = [:]

    static func bank(_ key: String, _ build: () -> [BankQuestion]?) -> [BankQuestion]? {
        lock.lock()
        if let hit = banks[key] { lock.unlock(); return hit }
        lock.unlock()
        let value = build()
        lock.lock(); banks[key] = value; lock.unlock()
        return value
    }

    static func available(_ key: String, _ build: () -> Bool) -> Bool {
        lock.lock()
        if let hit = availability[key] { lock.unlock(); return hit }
        lock.unlock()
        let value = build()
        lock.lock(); availability[key] = value; lock.unlock()
        return value
    }

    /// New cloud questions landed — forget everything and work it out again.
    static func invalidate() {
        lock.lock(); banks.removeAll(); availability.removeAll(); lock.unlock()
    }
}

/// 🌍 Questions follow the app language.
///
/// A translated screen is not enough (Rani: "לא סתם תרגום") — a child who picks
/// English gets English questions, and a world only appears in a language it
/// actually has questions in. Hebrew is the complete, original catalog, so for
/// Hebrew every rule here is a no-op.
///
/// Where the content lives:
///   • Hebrew — the built-in `QuestionBanks*` files, `ReadingContent.passages`,
///     and cloud items with no `lang` (everything written before languages).
///   • English — `EnglishContent` (built-in, US-adapted) and cloud items with
///     `lang: "en"`.
///   • Math is generated in every language (CurriculumMath goes through `tr`).
enum ContentAvailability {
    /// Below this a world would repeat itself within a session or two — better
    /// hidden until its content arrives.
    static let minimumBank = 20

    /// 🧊 Answered once per (topic, language), then remembered.
    ///
    /// Hebrew short-circuits to `true` on line one; every OTHER language has to
    /// ASSEMBLE the topic's whole bank to count it. The kid's home asks this for
    /// every pack, inside a filter, inside the grid's `ForEach` — so one render
    /// rebuilt hundreds of banks (built-ins concatenated, cloud items merged and
    /// validated one by one). In Hebrew that cost nothing and the home drew
    /// instantly; in English/Russian/Arabic it was seconds of main-thread work
    /// before the FIRST frame, and on a device with a full cloud bank the child
    /// just sat in front of a black screen. Measured on an iPhone 18 Pro,
    /// 2026-10-04: Hebrew drew in ~2s, English never drew at all.
    static func hasContent(_ topic: Topic, in language: AppLanguage = LanguageStore.shared.current) -> Bool {
        ContentCache.available("\(topic.rawValue)|\(language.rawValue)") { resolve(topic, in: language) }
    }

    private static func resolve(_ topic: Topic, in language: AppLanguage) -> Bool {
        switch topic {
        // 🎊 الأعياد exists only in Arabic — it is that audience's own holidays,
        // not a translation of anything. Hidden everywhere else, including in
        // Hebrew, which otherwise short-circuits to "yes" above.
        case .holidays: return language == .ar
        case _ where language == .he: return true      // Hebrew is the complete catalog
        case .math:    return true
        // 🇺🇸 The Hebrew world teaches Hebrew spelling to children who already
        // speak it. An American family has no use for it (Rani: "לא צריך להציג
        // להם שם עולם עברית"), so it stays hidden in English even if questions
        // ever land in its bank.
        // 🇷🇺 …but a Russian-speaking child in Israel goes to an Israeli school
        // and learns exactly this. The world stays, and stays in Hebrew.
        case .hebrew:  return language == .ru || language == .ar
        case .reading: return !ReadingContent.passages(in: language).isEmpty
        default:       return (QuestionBanks.bank(for: topic, in: language)?.count ?? 0) >= minimumBank
        }
    }
}

/// 🇺🇸 English content that ships in the app. Each topic's list is written for
/// US children (dollars, US grades, no Israel-only facts) and checked the same
/// way as the Hebrew banks: fact-checked, one correct answer, grade-tagged.
enum EnglishContent {
    static func bank(for topic: Topic) -> [BankQuestion] {
        switch topic {
        case .math, .reading: return []
        default: return banks[topic] ?? []
        }
    }

    /// Filled topic by topic as each set is written and verified.
    static let banks: [Topic: [BankQuestion]] = [
        .space: space, .body: body, .vehicles: vehicles,
        .flags: flags, .food: food, .music: music,
        .animals: animals, .sea: sea, .dinosaurs: dinosaurs,
        .gifted: gifted, .soccer: soccer, .logic: logic,
        .science: science, .english: english, .history: history,
        .money: money, .geography: geography,
    ]

    static var passages: [ReadingPassage] { readingPassages + readingPassages2 }
}
