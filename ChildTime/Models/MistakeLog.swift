import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// ❌ Which questions the child got wrong — not only how many (Sasha,
/// 2026-10-24: "יש רק כמות פעמים שהיא טועה, אבל אנחנו לא יודעים מה צריך
/// לתרגל איתה"). The child's device keeps the last `perTopic` misses of each
/// world and shares them with the parents through
/// `children/{id}/memory/mistakes`:
///
///     m: { <topic>: [ { q, a, c, at }, … ] }   — newest last
///
/// q = the question as the child heard/saw it, a = what they chose, c = the
/// right answer. Family-only, like every other progress record.
struct Mistake: Codable, Hashable, Identifiable {
    let q: String
    let a: String
    let c: String
    let at: Double
    var id: String { "\(at)|\(q)" }
}

enum MistakeLog {
    static let perTopic = 30

    // MARK: Child device

    /// One wrong pick. The first try of a question only — a second wrong try
    /// at the same question says nothing new.
    @MainActor
    static func record(_ q: Question, chosen: String) {
        guard let cid = ProfileStore.shared.activeID?.uuidString else { return }
        let text = [q.spoken, q.prompt].compactMap { $0 }.filter { !$0.isEmpty }
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            .joined(separator: " · ")
        let m = Mistake(q: Question.stripNiqqud(text), a: Question.stripNiqqud(chosen),
                        c: Question.stripNiqqud(q.correctAnswer), at: Date().timeIntervalSince1970)
        var all = load(cid)
        var list = all[q.topic.rawValue] ?? []
        list.append(m)
        if list.count > perTopic { list.removeFirst(list.count - perTopic) }
        all[q.topic.rawValue] = list
        save(all, cid)
        push(topic: q.topic.rawValue, list: list, child: cid)
    }

    private static func key(_ cid: String) -> String { "mistakes.\(cid)" }
    private static func load(_ cid: String) -> [String: [Mistake]] {
        guard let d = UserDefaults.standard.data(forKey: key(cid)),
              let v = try? JSONDecoder().decode([String: [Mistake]].self, from: d) else { return [:] }
        return v
    }
    private static func save(_ v: [String: [Mistake]], _ cid: String) {
        if let d = try? JSONEncoder().encode(v) { UserDefaults.standard.set(d, forKey: key(cid)) }
    }

    /// The whole topic list each time — field-by-field merge keeps the other
    /// topics; a second device of the same child overwrites with its own list
    /// for that topic, which is fine for "the latest misses".
    private static func push(topic: String, list: [Mistake], child: String) {
        #if canImport(FirebaseFirestore)
        guard !HouseholdManager.skipsCloudSync, AuthManager.shared.isSignedIn else { return }
        let rows = list.map { ["q": $0.q, "a": $0.a, "c": $0.c, "at": $0.at] as [String: Any] }
        Firestore.firestore().collection("children").document(child)
            .collection("memory").document("mistakes")
            .setData(["m": [topic: rows]], merge: true)
        #endif
    }

    // MARK: Parent device

    /// The child's recent misses per topic (newest first): the cloud copy
    /// plus whatever this device recorded itself (a child who plays on the
    /// parent's phone, or no network).
    static func fetch(childID: UUID) async -> [String: [Mistake]] {
        var out = load(childID.uuidString)
        #if canImport(FirebaseFirestore)
        if !HouseholdManager.skipsCloudSync,
           let snap = try? await Firestore.firestore().collection("children").document(childID.uuidString)
                .collection("memory").document("mistakes").getDocument(),
           let m = snap.data()?["m"] as? [String: Any] {
            for (topic, value) in m {
                guard let rows = value as? [[String: Any]] else { continue }
                let cloud: [Mistake] = rows.compactMap { r in
                    guard let q = r["q"] as? String, let a = r["a"] as? String, let c = r["c"] as? String else { return nil }
                    let at = (r["at"] as? Double) ?? (r["at"] as? NSNumber)?.doubleValue ?? 0
                    return Mistake(q: q, a: a, c: c, at: at)
                }
                out[topic] = Array(Set((out[topic] ?? []) + cloud))
            }
        }
        #endif
        return out.mapValues { Array($0.sorted { $0.at > $1.at }.prefix(perTopic)) }
    }
}
