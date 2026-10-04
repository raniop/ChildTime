import Foundation

/// What the shield screen needs to know, written by the app and read by the
/// extension. A shield extension gets a few seconds and no network — so nothing
/// here may be fetched; the app keeps this fresh in the App Group.
struct ShieldState: Codable {
    enum Mode: String, Codable {
        case needsQuestions   // hasn't earned enough yet
        case hasMinutes       // earned minutes sitting unused
        case dailyCapReached  // nothing more today
    }
    var mode: Mode = .needsQuestions
    var childName: String = ""
    var girl: Bool = false
    /// Minutes already earned and not yet opened (`hasMinutes`).
    var availableMinutes: Int = 0
    /// 🧮 Tofy's one reward rule, written exactly as the parent's own settings
    /// screen writes it: `batchAnswers` correct answers are worth
    /// `batchMinutes` minutes. Default 10 → 4.
    ///
    /// 🐛 Twice wrong on a real device. Build 189 promised `minutesPerCorrect`
    /// for EVERY answer (ten times the truth). Build 190 fixed the sentence but
    /// kept feeding it `minutesPerCorrectAnswer` — a different, legacy knob
    /// whose value is 2 — so the shield read "כל 10 תשובות נכונות = 2 דקות",
    /// half of what the child really earns (Rani: "גם זה לא סודר"). The number
    /// now comes from `batchMinutes`, the same field the parent edits, so the
    /// two screens cannot say different things again.
    var batchMinutes: Int = 4
    var batchAnswers: Int = 10
    var updatedAt: Double = 0

    static let key = "shield.state"
    static let suite = "group.com.childtime.shared"

    static func load() -> ShieldState {
        guard let d = UserDefaults(suiteName: suite)?.data(forKey: key),
              let s = try? JSONDecoder().decode(ShieldState.self, from: d) else { return ShieldState() }
        return s
    }

    func save() {
        guard let d = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.suite)?.set(d, forKey: Self.key)
    }
}
