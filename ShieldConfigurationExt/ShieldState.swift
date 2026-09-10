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
    /// Minutes a single correct answer is worth — the ONE number that is true
    /// about earning in Tofy. There is no "N questions to unlock": every correct
    /// answer banks minutes, and a window opens with whatever is in the wallet.
    var minutesPerCorrect: Int = 2
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
