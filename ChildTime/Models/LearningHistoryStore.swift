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
    /// Earn-to-Unlock sessions (child came to earn screen time).
    var earnSessions: Int = 0
    /// Free Learning sessions (child opened Tofy voluntarily).
    var freeSessions: Int = 0
    /// Answers given AFTER the daily minute-max was reached — i.e. the child
    /// kept learning for its own sake, not for minutes. Drives the Voluntary
    /// Learning Rate KPI.
    var voluntaryAnswers: Int = 0
    /// rawValue → per-topic tallies for the day.
    var perTopic: [String: TopicDay] = [:]

    struct TopicDay: Codable, Equatable {
        var answered: Int = 0
        var correct: Int = 0
        var responseMsTotal: Double = 0
        /// skill key → tallies, for the "what exactly to practise" breakdown.
        /// Optional so days recorded before skills existed still decode.
        var perSkill: [String: SkillDay]? = nil
    }
    struct SkillDay: Codable, Equatable {
        var answered: Int = 0
        var correct: Int = 0
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

    func recordSessionStart(purpose: SessionPurpose) {
        mutateToday { stat in
            stat.sessions += 1
            switch purpose {
            case .earnTime: stat.earnSessions += 1
            case .freePlay: stat.freeSessions += 1
            }
        }
    }

    func recordAnswer(topic: Topic, correct: Bool, responseMs: Double,
                      earnedMinutes: Int, streak: Int, voluntary: Bool = false,
                      skill: String? = nil) {
        mutateToday { stat in
            stat.questionsAnswered += 1
            if correct { stat.correct += 1 } else { stat.wrong += 1 }
            if voluntary { stat.voluntaryAnswers += 1 }
            stat.minutesEarned += max(0, earnedMinutes)
            stat.longestStreak = max(stat.longestStreak, streak)
            stat.learningSeconds += Int((responseMs / 1000).rounded())
            var t = stat.perTopic[topic.rawValue] ?? .init()
            t.answered += 1
            if correct { t.correct += 1 }
            t.responseMsTotal += responseMs
            if let skill {
                var sk = t.perSkill?[skill] ?? .init()
                sk.answered += 1
                if correct { sk.correct += 1 }
                var map = t.perSkill ?? [:]
                map[skill] = sk
                t.perSkill = map
            }
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

    // MARK: - Demo

    /// DEMO_SCREEN only: 30 days of believable history for screenshots — the
    /// exact picture on the approved parent mockup (money ≈100 %, reading 89,
    /// hebrew 86, geography 85, logic 73, english 60, math 39 with fractions
    /// the gap and multiplication / addition strong). Never runs in production.
    func seedDemo(childID: UUID) {
        var out: [String: DailyStat] = [:]
        let cal = Calendar.current
        // topic → (questions per day, accuracy now, accuracy 30 days ago)
        let plan: [(Topic, Int, Double, Double)] = [
            (.money, 12, 1.0, 0.92), (.reading, 9, 0.89, 0.80), (.hebrew, 14, 0.86, 0.78),
            (.geography, 13, 0.85, 0.75), (.logic, 11, 0.73, 0.55), (.english, 10, 0.60, 0.58),
            (.math, 18, 0.39, 0.46)]
        let mathSkills: [(String, Int, Double)] = [("fractions", 9, 0.22), ("mul", 5, 0.71), ("addSub", 4, 0.86)]
        for back in 0..<30 {
            guard let day = cal.date(byAdding: .day, value: -back, to: Date()) else { continue }
            if back % 6 == 4 { continue }                       // a quiet day now and then
            let key = Self.dayKey(day)
            var stat = DailyStat(date: key)
            let t = 1 - Double(back) / 30                        // 0 = a month ago, 1 = today
            let load = back == 0 ? 1.0 : (0.35 + 0.5 * Double((back * 7) % 10) / 10)
            for (topic, perDay, now, then) in plan {
                let n = max(1, Int((Double(perDay) * load).rounded()))
                let acc = then + (now - then) * t
                let c = Int((Double(n) * acc).rounded())
                var td = DailyStat.TopicDay(answered: n, correct: c, responseMsTotal: Double(n) * 6200)
                if topic == .math {
                    var map: [String: DailyStat.SkillDay] = [:]
                    var left = n
                    for (i, (skill, share, sacc)) in mathSkills.enumerated() {
                        let sn = i == mathSkills.count - 1 ? left : min(left, max(1, Int((Double(n) * Double(share) / 18).rounded())))
                        left -= sn
                        map[skill] = .init(answered: sn, correct: Int((Double(sn) * sacc).rounded()))
                    }
                    td.perSkill = map
                }
                stat.perTopic[topic.rawValue] = td
                stat.questionsAnswered += n; stat.correct += c; stat.wrong += n - c
                stat.learningSeconds += n * 6
            }
            stat.sessions = 2; stat.earnSessions = 1; stat.freeSessions = 1
            stat.minutesEarned = min(90, stat.correct * 2 / 3)
            stat.minutesUsed = back == 0 ? 40 : max(0, stat.minutesEarned - 8 - (back % 3) * 6)
            stat.longestStreak = 5 + back % 4
            out[key] = stat
        }
        if let data = try? JSONEncoder().encode(out) { defaults.set(data, forKey: storageKey(childID)) }
        if childID == boundChildID { days = out }
        objectWillChange.send()
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

    /// Pull a child's daily history DOWN from Firestore and cache it locally, so
    /// the parent's device (which never recorded this child's play) can show the
    /// full week/month insights. The child's own device records locally and only
    /// uploads — this is the missing read side.
    func fetchRemoteHistory(for childID: UUID) async {
        #if canImport(FirebaseFirestore)
        guard AuthManager.shared.isSignedIn else { return }
        let docs = try? await Firestore.firestore()
            .collection("children").document(childID.uuidString)
            .collection("dailyStats").getDocuments()
        guard let documents = docs?.documents, !documents.isEmpty else { return }

        var fetched: [String: DailyStat] = [:]
        for doc in documents {
            guard let data = try? JSONSerialization.data(withJSONObject: doc.data()),
                  let stat = try? JSONDecoder.firestore.decode(DailyStat.self, from: data)
            else { continue }
            fetched[stat.date] = stat
        }
        guard !fetched.isEmpty else { return }

        // Merge over any local cache and persist under this child's key so
        // `history(for:)` returns it.
        var merged = loadDays(for: childID)
        for (k, v) in fetched { merged[k] = v }
        if let encoded = try? JSONEncoder().encode(merged) {
            defaults.set(encoded, forKey: storageKey(childID))
        }
        if childID == boundChildID { days = merged }
        objectWillChange.send()
        #endif
    }

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
