import Foundation

struct Question: Identifiable, Equatable {
    let id = UUID()
    let topic: Topic
    let prompt: String
    let options: [String]
    let correctIndex: Int
    /// What to read aloud. For visual (early-reader) questions the on-screen
    /// `prompt` is pictures, so the spoken instruction lives here. nil → speak
    /// the prompt itself.
    var spoken: String? = nil
    /// 📖 Reading-comprehension: the passage this question is about, rendered as
    /// a scrollable card above the prompt. Attached to EVERY question of the
    /// passage so the text is always available, even after interleaving/re-asks.
    var passage: String? = nil
    /// Fine-grained skill inside the topic ("fractions", "mul", …) — see
    /// `SkillCatalog`. Lets the parent report say "strong in multiplication,
    /// struggling with fractions" instead of just "math 61%". nil = untagged.
    var skill: String? = nil

    var correctAnswer: String { options[correctIndex] }
    /// The line the read-aloud / auto-read should speak.
    var readAloudText: String { spoken ?? prompt }

    /// True when the prompt can be judged on its own — i.e. it does NOT depend on
    /// seeing the full option set. Odd-one-out prompts ("מי לא שיך?", "מי לא שיך
    /// לקבוצה?") carry their group only in the options, so they're meaningless in
    /// modes that show one option at a time (True/False race) or match a lone
    /// prompt to an answer (Match Pairs). Niqqud-stripped so vowelized prompts
    /// still match. Note: "...שיכת לקבוצה: תפוח, בננה, אגס?" lists the group inline
    /// and stays self-contained — only the group-less "לא שיך" family is excluded.
    var isSelfContainedPrompt: Bool {
        // A passage question is meaningless without its passage — keep it out of
        // the single-prompt game modes (True/False race, Match Pairs).
        if passage != nil { return false }
        let p = Question.stripNiqqud(prompt)
        if p.contains("לא שיך") || p.contains("לא שייך") { return false }
        return true
    }

    static func stripNiqqud(_ s: String) -> String {
        String(s.unicodeScalars.filter { !(0x0591...0x05C7).contains(Int($0.value)) })
    }
}
