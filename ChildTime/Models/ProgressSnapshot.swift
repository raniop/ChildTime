import Foundation

/// A serializable snapshot of everything the active profile has accumulated.
/// Used to:
///   • Partition progress per profile (each profile has its own snapshot
///     stored under `progressSnapshot.<profileID>` in UserDefaults).
///   • Sync to Firestore for remote viewing / parental reset.
///   • Reset a single profile without touching others.
struct ProgressSnapshot: Codable, Equatable {
    var pendingMinutes: Int = 0
    var totalCorrect: Int = 0
    var totalAnswered: Int = 0
    var unlockEndsAt: Date? = nil
    var stars: Int = 0
    var gems: Int = 0
    var xp: Int = 0
    var currentStreak: Int = 0
    var dayStreak: Int = 0
    var lastSessionDate: Date? = nil
    var lastDailyChestDate: Date? = nil
    var unlockedWorlds: [String] = ["numbers_kingdom"]
    var worldProgress: [String: Int] = [:]
    var topicAccuracy: [String: Double] = [:]
    var topicAnswered: [String: Int] = [:]
    var topicCorrect: [String: Int] = [:]
    var batchCounter: Int = 0
    var wrongStreak: Int = 0
    var totalScore: Int = 0
    var minutesEarnedToday: Int = 0
    var dailyEarnedDate: Date? = nil
    /// Questions answered / correct TODAY — synced so the parent's dashboard
    /// shows today's activity even though the full learning history is local.
    var answeredToday: Int = 0
    var correctToday: Int = 0
    /// Longest-ever streak of correct answers (synced so the parent can see it).
    var bestStreak: Int = 0
    /// Fractional progress (seconds) toward the next play-minutes bonus.
    var cycleSeconds: Double = 0

    // MARK: - Smart Learning Feed signals (per-topic)
    /// Rolling average response time per topic, in milliseconds.
    var topicResponseMs: [String: Double] = [:]
    /// Learned affinity per topic, 0...1 — drives the explore/exploit engine.
    var topicAffinity: [String: Double] = [:]
    /// How many questions of each topic the child has been served (novelty signal).
    var topicExposure: [String: Int] = [:]
    /// Times the child abandoned a topic (replaced a question / quit mid-topic).
    var topicAbandon: [String: Int] = [:]

    // MARK: - Time economy progression
    /// Questions answered since the last free Lucky Wheel spin.
    var wheelProgressCount: Int = 0
    /// Minutes deducted by the most recent mistake, refundable by a clean
    /// correct answer on the next question (Risk & Recovery loop).
    var recoveryPot: Int = 0
    /// Bumped each time the device writes the snapshot — Firestore listeners
    /// use this to skip echoes of their own writes.
    var revision: Int = 0
    var lastModifiedAt: Date = .now
    var deviceID: String = ProgressSnapshot.thisDeviceID

    static var blank: ProgressSnapshot {
        ProgressSnapshot()
    }

    /// Stable per-install identifier so we can tell whose write a remote
    /// snapshot represents.
    static let thisDeviceID: String = {
        let key = "progress.deviceID"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }()
}
