import Foundation

/// Picture-based questions for early readers (age 4 / `.preK`). The on-screen
/// content is VISUAL — objects to count, or emoji choices — and the instruction
/// is read aloud (`Question.spoken`), so a child who can't read yet plays by
/// listening + looking. Used by `QuestionRunnerView` when the active child is preK.
enum PreReaderContent {

    static func generate(topic: Topic) -> Question {
        switch topic {
        case .math:
            return counting()
        default:
            // Logic / anything else → a "find the picture" round.
            return [findAnimal, findShape, findColor].randomElement()!()
        }
    }

    // MARK: - Counting: show N objects → "how many?" → tap the number.

    private static var countables: [(emoji: String, plural: String)] { [
        ("🍎", tr("תַּפּוּחִים")), ("⭐", tr("כּוֹכָבִים")), ("🐟", tr("דָּגִים")), ("🌸", tr("פְּרָחִים")),
        ("🎈", tr("בַּלּוֹנִים")), ("🍌", tr("בָּנָנוֹת")), ("🐝", tr("דְּבוֹרִים")), ("⚽", tr("כַּדּוּרִים")),
        ("🚗", tr("מְכוֹנִיּוֹת")), ("🦋", tr("פַּרְפָּרִים")), ("🍪", tr("עוּגִיּוֹת")), ("🐱", tr("חֲתוּלִים"))
    ] }

    private static func counting() -> Question {
        let item = countables.randomElement()!
        let n = Int.random(in: 1...5)
        let prompt = Array(repeating: item.emoji, count: n).joined(separator: " ")
        var nums: Set<Int> = [n]
        while nums.count < 4 { nums.insert(Int.random(in: 1...6)) }
        let options = nums.shuffled().map(String.init)
        let correct = options.firstIndex(of: String(n)) ?? 0
        return Question(topic: .math, prompt: prompt, options: options,
                        correctIndex: correct, spoken: tr("כַּמָּה \(item.plural)?"))
    }

    // MARK: - Find the picture: hear "where's the dog?" → tap the matching emoji.

    private static var animals: [(emoji: String, name: String)] { [
        ("🐶", tr("הַכֶּלֶב")), ("🐱", tr("הֶחָתוּל")), ("🐰", tr("הָאַרְנָב")), ("🐸", tr("הַצְּפַרְדֵּעַ")),
        ("🐮", tr("הַפָּרָה")), ("🐷", tr("הַחֲזִיר")), ("🦁", tr("הָאַרְיֵה")), ("🐘", tr("הַפִּיל")),
        ("🐧", tr("הַפִּינְגְּוִין")), ("🦊", tr("הַשּׁוּעָל")), ("🐵", tr("הַקּוֹף")), ("🐯", tr("הַנָּמֵר"))
    ] }
    private static var shapes: [(emoji: String, name: String)] { [
        ("🔴", tr("הָעִגּוּל")), ("🔺", tr("הַמְּשׁוּלָּשׁ")), ("🟦", tr("הָרִבּוּעַ")),
        ("⭐", tr("הַכּוֹכָב")), ("❤️", tr("הַלֵּב"))
    ] }
    private static var colors: [(emoji: String, name: String)] { [
        ("🔴", tr("הָאָדוֹם")), ("🟢", tr("הַיָּרוֹק")), ("🔵", tr("הַכָּחוֹל")),
        ("🟡", tr("הַצָּהוֹב")), ("🟣", tr("הַסָּגוֹל")), ("🟠", tr("הַכָּתוֹם"))
    ] }

    private static func findAnimal() -> Question { findOne(in: animals) }
    private static func findShape()  -> Question { findOne(in: shapes) }
    private static func findColor()  -> Question { findOne(in: colors) }

    private static func findOne(in pool: [(emoji: String, name: String)]) -> Question {
        let picks = Array(pool.shuffled().prefix(4))
        let target = picks.randomElement()!
        let options = picks.map(\.emoji)
        let correct = options.firstIndex(of: target.emoji) ?? 0
        // The instruction is both shown and read aloud (spoken defaults to prompt).
        return Question(topic: .logic, prompt: tr("אֵיפֹה \(target.name)?"),
                        options: options, correctIndex: correct)
    }
}
