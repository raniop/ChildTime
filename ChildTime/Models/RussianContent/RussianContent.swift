import Foundation

/// 🇷🇺 Russian content that ships in the app.
///
/// Russian here is Israel's second home language, not a second country: these
/// are families in Israel, so the money is shekels, the grades are א׳–ח׳, and
/// the facts are the Israeli ones the Hebrew catalog teaches — only the words
/// are Russian. That is the opposite of the English catalog, which was re-aimed
/// at an American child.
///
/// Each topic's list is checked the same way as the Hebrew and English banks:
/// fact-checked, exactly one correct answer, no distractor that is also true,
/// and grade-tagged.
enum RussianContent {
    static func bank(for topic: Topic) -> [BankQuestion] {
        switch topic {
        // Math is generated, and the Hebrew world is taught in Hebrew.
        case .math, .reading, .hebrew: return []
        default: return banks[topic] ?? []
        }
    }

    /// Filled topic by topic as each set is written and verified.
    static let banks: [Topic: [BankQuestion]] = [
        .animals: animals,
        .body: body,
        .dinosaurs: dinosaurs,
        .english: english,
        .flags: flags,
        .food: food,
        .geography: geography,
        .gifted: gifted,
        .history: history,
        .israel: israel,
        .logic: logic,
        .money: money,
        .music: music,
        .science: science,
        .sea: sea,
        .soccer: soccer,
        .space: space,
        .tishrei: tishrei,
        .vehicles: vehicles,
    ]

    static var passages: [ReadingPassage] { readingPassages }
}
