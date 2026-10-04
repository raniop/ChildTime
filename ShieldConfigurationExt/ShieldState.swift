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
    /// 🧮 The real rule, and the one the rest of the app states: `batchAnswers`
    /// correct answers are worth `minutesPerCorrect` minutes. The lock screen
    /// used to promise `minutesPerCorrect` for EVERY answer, which is what the
    /// parent home calls "כל 10 נכונות = 4 דקות משחק" — a child reading the
    /// shield was told they earn ten times what they earn (Rani, build 189).
    var minutesPerCorrect: Int = 2
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
