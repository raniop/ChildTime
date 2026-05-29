import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// One day of a child's learning activity. The building block for the parent
/// analytics (daily / weekly / monthly summaries, trends, coaching).
struct DailyStat: Codable, Equatable {
    var date: String                 // "YYYY-MM-DD" (local calendar)
    var questionsAnswered: Int = 0
    var correct: Int = 0
    var wrong: Int = 0
    var minutesEarned: Int = 0
    var minutesUsed: Int = 0
    var longestStreak: Int = 0
    var learningSeconds: Int = 0     // active time spent answering
    var sessions: Int = 0
    /// rawValue → per-topic tallies for the day.
    var perTopic: [String: TopicDay] = [:]

    struct TopicDay: Codable, Equatable {
        var answered: Int = 0
        var correct: Int = 0
        var responseMsTotal: Double = 0
    }
}

/// Records per-child daily learning aggregates locally and (when signed in)
/// mirrors them to `children/{childID}/dailyStats/{date}` in Firestore. Bound to
/// the active child the same way `ProgressVault` is, switched on profile change.
@MainActor
final class LearningHistoryStore: ObservableObject {
    static let shared = LearningHistoryStore()

    private let defaults = AppGroup.defaults
    private(set) var boundChildID: UUID?
    /// Local cache of the bound child's history, keyed by date string.
    @Published private(set) var days: [String: DailyStat] = [:]

    /// Keep ~120 days locally so weekly/monthly/quarter trends work offline.
    private let retentionDays = 120

    private init() {}

    // MARK: - Binding (mirrors ProgressVault.switchTo)

    func bind(to childID: UUID) {
        boundChildID = childID
        days = loadDays(for: childID)
        pruneOldDays()
    }

    // MARK: - Recording (called during play)

    func recordSessionStart() {
        mutateToday { $0.sessions += 1 }
    }

    func recordAnswer(topic: Topic, correct: Bool, responseMs: Double,
                      earnedMinutes: Int, streak: Int) {
        mutateToday { stat in
            stat.questionsAnswered += 1
            if correct { stat.correct += 1 } else { stat.wrong += 1 }
            stat.minutesEarned += max(0, earnedMinutes)
            stat.longestStreak = max(stat.longestStreak, streak)
            stat.learningSeconds += Int((responseMs / 1000).rounded())
            var t = stat.perTopic[topic.rawValue] ?? .init()
            t.answered += 1
            if correct { t.correct += 1 }
            t.responseMsTotal += responseMs
            stat.perTopic[topic.rawValue] = t
        }
    }

    func recordMinutesUsed(_ minutes: Int) {
        guard minutes > 0 else { return }
        mutateToday { $0.minutesUsed += minutes }
    }

    // MARK: - Reads (for the dashboard / engines)

    /// History for the bound child if it matches; otherwise loads from disk.
    func history(for childID: UUID) -> [DailyStat] {
        let source = (childID == boundChildID) ? days : loadDays(for: childID)
        return source.values.sorted { $0.date < $1.date }
    }

    func today(for childID: UUID) -> DailyStat {
        let key = Self.dayKey(Date())
        let source = (childID == boundChildID) ? days : loadDays(for: childID)
        return source[key] ?? DailyStat(date: key)
    }

    // MARK: - Mutation core

    private func mutateToday(_ transform: (inout DailyStat) -> Void) {
        guard let childID = boundChildID else { return }
        let key = Self.dayKey(Date())
        var stat = days[key] ?? DailyStat(date: key)
        transform(&stat)
        days[key] = stat
        persist(for: childID)
        sync(stat, childID: childID)
    }

    // MARK: - Persistence

    private func storageKey(_ childID: UUID) -> String {
        "learningHistory.\(childID.uuidString)"
    }

    private func loadDays(for childID: UUID) -> [String: DailyStat] {
        guard let data = defaults.data(forKey: storageKey(childID)),
              let decoded = try? JSONDecoder().decode([String: DailyStat].self, from: data)
        else { return [:] }
        return decoded
    }

    private func persist(for childID: UUID) {
        if let data = try? JSONEncoder().encode(days) {
            defaults.set(data, forKey: storageKey(childID))
        }
    }

    private func pruneOldDays() {
        guard days.count > retentionDays else { return }
        let keep = days.keys.sorted().suffix(retentionDays)
        days = days.filter { keep.contains($0.key) }
        if let childID = boundChildID { persist(for: childID) }
    }

    // MARK: - Firestore sync

    private func sync(_ stat: DailyStat, childID: UUID) {
        #if canImport(FirebaseFirestore)
        guard AuthManager.shared.isSignedIn else { return }
        guard let data = try? JSONEncoder.firestore.encode(stat),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        Firestore.firestore()
            .collection("children").document(childID.uuidString)
            .collection("dailyStats").document(stat.date)
            .setData(dict, merge: true)
        #endif
    }

    // MARK: - Helpers

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
