import Foundation

/// 🇵🇸🇮🇱 Arabic content that ships in the app.
///
/// For **Arabic-speaking families in Israel**: shekels, Israeli school grades,
/// the curriculum their children actually learn. Like the Russian catalog and
/// unlike the English one, the country does not change — only the language.
///
/// Two worlds are theirs specifically:
///   • 🎊 الأعياد — Ramadan and the two Eids, Christmas and Easter. Free, not a
///     paid pack: a family should meet its own holidays on the first screen.
///   • ✍️ עברית — kept and served in Hebrew, exactly as it is for Russian
///     speakers: these children learn Hebrew at school, and it is the world
///     that helps them most.
enum ArabicContent {
    static func bank(for topic: Topic) -> [BankQuestion] {
        switch topic {
        // Math is generated; the Hebrew world is taught in Hebrew.
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
        .holidays: holidays,
        .israel: israel,
        .logic: logic,
        .money: money,
        .music: music,
        .science: science,
        .sea: sea,
        .soccer: soccer,
        .space: space,
        .vehicles: vehicles,
    ]

    static var passages: [ReadingPassage] { readingPassages }
}
