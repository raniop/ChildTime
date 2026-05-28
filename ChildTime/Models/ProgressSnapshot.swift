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
