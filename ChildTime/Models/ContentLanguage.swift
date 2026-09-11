import Foundation

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

    static func hasContent(_ topic: Topic, in language: AppLanguage = LanguageStore.shared.current) -> Bool {
        guard language != .he else { return true }
        switch topic {
        case .math:    return true
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
    ]

    static let passages: [ReadingPassage] = []
}
